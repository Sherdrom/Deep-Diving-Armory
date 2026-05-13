-- ============================================
-- SoundAdjustment.lua
-- 声音调节模组 v4.0
-- 功能：装备耳机后，自己不变，他人脚步声放大+范围扩展（支持多耳机独立配置）
-- ============================================

local DEBUG = false
local LOG_INFO = false
local SILENT = true

local function log(...)
    if not SILENT and LOG_INFO then
        print("[SoundAdjustment]", ...)
    end
end

local function logError(...)
    if not SILENT then
        print("[SoundAdjustment][ERROR]", ...)
    end
end

local function logDebug(...)
    if not SILENT and DEBUG then
        print("[SoundAdjustment][DEBUG]", ...)
    end
end

-- ==================== 配置 ====================
local Config = {
    Enabled = true,
    CheckInterval = 0.5,
    
    Headsets = {

        ["gssh01_headset"] = {
            name = "GSSH-01 战术耳机",
            otherVolumeMultiplier = 2.0,
            selfVolumeMultiplier = 2.0,
            selfDistanceThreshold = 150,
            rangeMultiplier = 1.5,
        },

        ["m32_headset"] = {
            name = "M32 战术耳机",
            otherVolumeMultiplier = 1.5,
            selfVolumeMultiplier = 1.0,
            selfDistanceThreshold = 150,
            rangeMultiplier = 1.8,
        },

        ["walker_headset"] = {
            name = "漫步者 战术耳机",
            otherVolumeMultiplier = 2.0,
            selfVolumeMultiplier = 0.5,
            selfDistanceThreshold = 150,
            rangeMultiplier = 1.8,
        },
    },
    
    FootstepKeywords = {
        "footstep", "Footstep", "FOOTSTEP",
        "fst_", "FST_",
        "walk", "Walk", "WALK",
        "step", "Step", "STEP",
        "脚步", "走路"
    },
    
    LogAllSounds = true,
    MaxDebugLogs = 50
}

-- ==================== 调试统计 ====================
local DebugStats = {
    totalPlaySoundCalls = 0,
    footstepSoundCount = 0,
    selfFootstepCount = 0,
    otherFootstepCount = 0,
    volumeModifiedCount = 0,
    headsetCheckCount = 0,
    headsetDetectedCount = 0,
    lastSoundTags = {},
    maxStoredTags = 15,
    hook1Calls = 0,
    hook1_5Calls = 0,
    hook2Calls = 0,
    hook3Calls = 0
}

-- ==================== 模块状态 ====================
local SoundAdjustment = {
    isInitialized = false,
    lastCheckTime = 0,
    activeHeadsetId = nil,
    activeHeadsetConfig = nil,
    currentVolumeMultiplier = 1.0,
    footstepSoundCount = 0,
    _pendingMods = {}
}

function SoundAdjustment.IsHeadsetActive()
    return SoundAdjustment.activeHeadsetConfig ~= nil
end

function SoundAdjustment.GetActiveConfig(key)
    if SoundAdjustment.activeHeadsetConfig == nil then return nil end
    return SoundAdjustment.activeHeadsetConfig[key]
end

-- ==================== 工具函数 ====================

function SoundAdjustment.IsFootstepSound(soundIdentifier)
    if soundIdentifier == nil then return false, nil end
    
    local soundStr = tostring(soundIdentifier):lower()
    
    for _, keyword in ipairs(Config.FootstepKeywords) do
        if string.find(soundStr, keyword) ~= nil then
            return true, keyword
        end
    end
    
    return false, nil
end

function SoundAdjustment.RecordSoundTag(tag)
    if tag == nil then return end
    
    table.insert(DebugStats.lastSoundTags, 1, tostring(tag))
    
    if #DebugStats.lastSoundTags > DebugStats.maxStoredTags then
        table.remove(DebugStats.lastSoundTags)
    end
end

function SoundAdjustment.IsSelfSound(channel, shouldLog)
    if channel == nil then return false end
    
    local controlledChar = Character.Controlled
    if controlledChar == nil or controlledChar.Removed then return false end
    
    local soundPos = nil
    local posSuccess, posErr = pcall(function()
        soundPos = channel.Position
    end)
    
    if shouldLog then
        logDebug(string.format("   🔍 [诊] channel.Position: %s, 值=%s, 类型=%s",
            posSuccess and "✅" or "❌",
            soundPos == nil and "nil" or tostring(soundPos),
            SoundAdjustment.DebugType(soundPos)))
        if not posSuccess then
            logDebug(string.format("   🔍 [诊] channel.Position 错误: %s", tostring(posErr)))
        end
    end
    
    if not posSuccess or soundPos == nil then return false end
    
    local charPos = nil
    local charSuccess, charErr = pcall(function()
        charPos = controlledChar.WorldPosition
    end)
    
    if shouldLog then
        logDebug(string.format("   🔍 [诊] WorldPosition: %s, 值=%s, 类型=%s",
            charSuccess and "✅" or "❌",
            charPos == nil and "nil" or tostring(charPos),
            SoundAdjustment.DebugType(charPos)))
        if not charSuccess then
            logDebug(string.format("   🔍 [诊] WorldPosition 错误: %s", tostring(charErr)))
        end
    end
    
    if not charSuccess or charPos == nil then return false end
    
    local sx, sy, cx, cy = nil, nil, nil, nil
    
    pcall(function()
        sx = soundPos.X
        sy = soundPos.Y
    end)
    
    pcall(function()
        cx = charPos.X
        cy = charPos.Y
    end)
    
    if shouldLog then
        logDebug(string.format("   🔍 [诊] soundPos=(%s,%s) charPos=(%s,%s)",
            sx == nil and "?" or string.format("%.2f", sx),
            sy == nil and "?" or string.format("%.2f", sy),
            cx == nil and "?" or string.format("%.2f", cx),
            cy == nil and "?" or string.format("%.2f", cy)))
    end
    
    if sx == nil or sy == nil or cx == nil or cy == nil then return false end
    
    local dx = sx - cx
    local dy = sy - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    
    local threshold = SoundAdjustment.GetActiveConfig("selfDistanceThreshold") or 150
    if shouldLog then
        logDebug(string.format("   🔍 [诊] dx=%.2f dy=%.2f dist=%.2f threshold=%.2f → %s",
            dx, dy, dist, threshold,
            dist < threshold and "🚶自己" or "👥他人"))
    end
    
    return dist < threshold
end

function SoundAdjustment.CheckHeadset()
    DebugStats.headsetCheckCount = DebugStats.headsetCheckCount + 1
    
    local controlledChar = Character.Controlled
    if controlledChar == nil or controlledChar.Removed then return nil end
    
    local inventory = controlledChar.Inventory
    if inventory == nil then return nil end
    
    local headsetItem = nil
    local success, err = pcall(function()
        headsetItem = inventory.GetItemInLimbSlot(64)
    end)
    
    if not success or headsetItem == nil then return nil end
    
    local itemIdentifier = nil
    pcall(function()
        if headsetItem.Prefab ~= nil and headsetItem.Prefab.Identifier ~= nil then
            itemIdentifier = headsetItem.Prefab.Identifier.Value
        elseif headsetItem.identifier ~= nil then
            itemIdentifier = headsetItem.identifier
        end
    end)
    
    if itemIdentifier == nil then return nil end
    
    local headsetConfig = Config.Headsets[itemIdentifier]
    if headsetConfig ~= nil then
        DebugStats.headsetDetectedCount = DebugStats.headsetDetectedCount + 1
        return headsetConfig, itemIdentifier
    end
    
    return nil
end

-- 安全地获取ptable中的参数
function SoundAdjustment.SafeGet(ptable, key)
    if ptable == nil then return nil, "ptable is nil" end
    
    local success, value = pcall(function()
        return ptable[key]
    end)
    
    if success then
        return value, nil
    else
        return nil, tostring(value)
    end
end

-- 安全地设置ptable中的参数
function SoundAdjustment.SafeSet(ptable, key, value)
    if ptable == nil then return false, "ptable is nil" end
    
    local success, err = pcall(function()
        ptable[key] = value
    end)
    
    return success, err
end

-- 使用LuaUserData检查对象类型
function SoundAdjustment.DebugType(obj)
    if obj == nil then return "nil" end
    
    local success, typeName = pcall(function()
        return LuaUserData.TypeOf(obj)
    end)
    
    if success and typeName ~= nil then
        return typeName
    end
    
    return type(obj)
end

-- ==================== 核心声音处理函数 ====================

function SoundAdjustment.ProcessSoundPlay(ptable, hookName)
    -- 更新统计
    DebugStats.totalPlaySoundCalls = DebugStats.totalPlaySoundCalls + 1
    
    if hookName == "Hook1" then
        DebugStats.hook1Calls = DebugStats.hook1Calls + 1
    elseif hookName == "Hook2" then
        DebugStats.hook2Calls = DebugStats.hook2Calls + 1
    elseif hookName == "Hook3" then
        DebugStats.hook3Calls = DebugStats.hook3Calls + 1
    end
    
    -- 日志限制
    local shouldLog = DebugStats.totalPlaySoundCalls <= Config.MaxDebugLogs
    
    if shouldLog then
        logDebug(string.format("\n📞 [%s] PlaySound被调用 (第%d次)", hookName, DebugStats.totalPlaySoundCalls))
        
        -- 使用LuaUserData检查ptable类型
        local ptableType = SoundAdjustment.DebugType(ptable)
        logDebug(string.format("   ptable类型: %s", ptableType))
        
        -- 尝试获取所有已知参数
        local keysToLog = {"soundTag", "position", "volume", "range", "hullGuess"}
        
        for _, key in ipairs(keysToLog) do
            local value, err = SoundAdjustment.SafeGet(ptable, key)
            if err ~= nil then
                logDebug(string.format("   [%s] ⚠️ %s", key, err))
            elseif value == nil then
                logDebug(string.format("   [%s] = nil", key))
            else
                logDebug(string.format("   [%s] (%s) = %s", key, type(value), tostring(value)))
            end
        end
    end
    
    -- 检查是否启用
    if not Config.Enabled then
        if shouldLog then logDebug("   ⛔ 模组已禁用") end
        return
    end
    
    -- 获取soundTag
    local soundTag, tagErr = SoundAdjustment.SafeGet(ptable, "soundTag")
    
    if shouldLog then
        if tagErr ~= nil then
            logDebug(string.format("   ❌ 获取soundTag失败: %s", tagErr))
            
            -- 尝试其他可能的键名
            local altKeys = {"sound", "tag", "name"}
            for _, altKey in ipairs(altKeys) do
                local altVal, altErr = SoundAdjustment.SafeGet(ptable, altKey)
                if altErr == nil and altVal ~= nil then
                    logDebug(string.format("   发现 [%s] = %s", altKey, tostring(altVal)))
                    if soundTag == nil then soundTag = altVal end
                end
            end
        elseif soundTag == nil then
            logDebug("   ❌ soundTag 为空")
        else
            logDebug(string.format("   🏷️  soundTag = \"%s\"", tostring(soundTag)))
        end
    end
    
    if soundTag == nil then return end
    
    -- 记录标签
    SoundAdjustment.RecordSoundTag(soundTag)
    
    -- 检查是否是脚步声
    local isFootstep, matchedKeyword = SoundAdjustment.IsFootstepSound(soundTag)
    
    if shouldLog then
        if isFootstep then
            DebugStats.footstepSoundCount = DebugStats.footstepSoundCount + 1
            logDebug(string.format("   👣 ✅ 检测到脚步声! 关键词: [%s]", matchedKeyword))
        elseif Config.LogAllSounds then
            logDebug(string.format("   🔊 普通声音: \"%s\"", tostring(soundTag)))
        end
    end
    
    if not isFootstep then return end
    
    if shouldLog then
        logDebug(string.format("   🎧 hasHeadset: %s", 
            SoundAdjustment.IsHeadsetActive() and "✅ 已装备" or "❌ 未装备"))
        logDebug("   ℹ️ 音量修改由 Hook3 (After-Gain) 负责")
    end
end

-- ==================== Hook 注册 ====================

logDebug("")
logDebug("=====================================")
logDebug("正在注册声音拦截 Hooks...")
logDebug("=====================================")

-- ========== Hook 1: PlaySound(string, Vector2, float?, float?, Hull) ==========
-- 用于环境音等简单声音
logDebug(">>> 注册 Hook 1: PlaySound(5参数-string)...")

local hook1Success, hook1Err = pcall(function()
    Hook.Patch(
        "Barotrauma.SoundPlayer",
        "PlaySound",
        {
            "System.String",
            "Microsoft.Xna.Framework.Vector2",
            "System.Nullable`1[System.Single]",
            "System.Nullable`1[System.Single]",
            "Barotrauma.Hull"
        },
        function(instance, ptable)
            SoundAdjustment.ProcessSoundPlay(ptable, "Hook1-String")
        end,
        Hook.HookMethodType.Before
    )
end)

if hook1Success then
    logDebug("✅ Hook 1 (String) 注册成功!")
else
    logDebug(string.format("❌ Hook 1 (String) 注册失败: %s", tostring(hook1Err)))
end

-- ========== Hook 1-GetSound: SoundPlayer.GetSound After ==========
-- ⭐ 关键！在 GetSound 返回 Sound 对象后立即修改 BaseFar
-- 这样 string 重载的 range ?? sound.BaseFar 就会使用扩大后的值
logDebug(">>> 注册 Hook 1-GetSound: GetSound After...")

local hookGetSoundSuccess, hookGetSoundErr = pcall(function()
    Hook.Patch(
        "Barotrauma.SoundPlayer",
        "GetSound",
        { "System.String" },
        function(instance, ptable)
            if not SoundAdjustment.IsHeadsetActive() then return end
            local rangeMult = SoundAdjustment.GetActiveConfig("rangeMultiplier")
            if rangeMult == nil or rangeMult <= 1.0 then return end

            local soundTag = nil
            pcall(function() soundTag = ptable["soundTag"] end)
            if soundTag == nil then return end

            local isFootstep, _ = SoundAdjustment.IsFootstepSound(tostring(soundTag))
            if not isFootstep then return end

            local soundObj = nil
            pcall(function() soundObj = ptable.ReturnValue end)
            if soundObj == nil then return end

            local savedNear, savedFar = nil, nil
            pcall(function() savedNear = soundObj.BaseNear end)
            pcall(function() savedFar = soundObj.BaseFar end)

            if savedNear ~= nil and savedFar ~= nil and savedNear > 0 and savedFar > 0 then
                SoundAdjustment._pendingMods[soundObj] = {near = savedNear, far = savedFar}
                pcall(function() soundObj.BaseNear = savedNear * rangeMult end)
                pcall(function() soundObj.BaseFar = savedFar * rangeMult end)
            end
        end,
        Hook.HookMethodType.After
    )
end)

if hookGetSoundSuccess then
    logDebug("✅ Hook 1-GetSound (GetSound After) 注册成功! ⭐")
else
    logDebug(string.format("❌ Hook 1-GetSound 注册失败: %s", tostring(hookGetSoundErr)))
end

-- ========== Hook 1.5: PlaySound(Sound, Vector2, float?, float?, float?, Hull, bool, bool) ==========
-- ⚠️ 这是最重要的！生物脚步声通过这个路径播放！（Character.cs:1409）
logDebug(">>> 注册 Hook 1.5: PlaySound(8参数-Sound对象)...")

local hook1_5Success, hook1_5Err = pcall(function()
    Hook.Patch(
        "Barotrauma.SoundPlayer",
        "PlaySound",
        {
            "Barotrauma.Sounds.Sound",              -- Sound对象（不是string！）
            "Microsoft.Xna.Framework.Vector2",      -- position
            "System.Nullable`1[System.Single]",      -- volume
            "System.Nullable`1[System.Single]",      -- range
            "System.Nullable`1[System.Single]",      -- freqMult
            "Barotrauma.Hull",                       -- hullGuess
            "System.Boolean",                        -- ignoreMuffling
            "System.Boolean"                         -- muteBackgroundMusic
        },
        function(instance, ptable)
            DebugStats.totalPlaySoundCalls = DebugStats.totalPlaySoundCalls + 1
            DebugStats.hook1_5Calls = DebugStats.hook1_5Calls + 1  -- ⭐ 计数Sound对象调用
            DebugStats.hook1Calls = DebugStats.hook1Calls + 1      -- 总Hook1计数（包含子Hook）

            local shouldLog = DebugStats.totalPlaySoundCalls <= Config.MaxDebugLogs

            if shouldLog then
                logDebug(string.format("\n📞 [Hook1.5-SoundObj] 被调用 (第%d次)", DebugStats.totalPlaySoundCalls))
                logDebug(string.format("   instance类型: %s", SoundAdjustment.DebugType(instance)))
            end

            -- 🔑 关键修复：使用参数名从ptable获取Sound对象（静态方法instance为空）
            -- 根据C#源码，参数名为: sound, position, volume, range, freqMult, hullGuess, ignoreMuffling, muteBackgroundMusic
            local soundObj = nil

            -- 方法1：直接通过参数名 "sound" 获取（最可能的方式）
            local possibleParamNames = {"sound", "Sound", "0", "arg0", "param0"}

            for _, paramName in ipairs(possibleParamNames) do
                local val, err = SoundAdjustment.SafeGet(ptable, paramName)

                if err == nil and val ~= nil then
                    local valType = SoundAdjustment.DebugType(val)

                    if shouldLog then
                        logDebug(string.format("   ptable[\"%s\"] 类型: %s", paramName, valType))
                    end

                    -- 检查是否是Sound对象
                    local isSound = false
                    pcall(function()
                        isSound = LuaUserData.IsTargetType(val, "Barotrauma.Sounds.Sound")
                    end)

                    if isSound then
                        soundObj = val
                        if shouldLog then
                            logDebug(string.format("   ✅ 通过参数名\"%s\"找到Sound对象!", paramName))
                        end
                        break
                    end

                    -- 备选：检查是否有Tag属性（Sound对象特有）
                    local hasTag = false
                    pcall(function()
                        hasTag = (val.Tag ~= nil)
                    end)

                    if hasTag then
                        soundObj = val
                        if shouldLog then
                            logDebug(string.format("   ✅ 通过参数名\"%s\"找到有Tag属性的对象!", paramName))
                        end
                        break
                    end
                elseif shouldLog and err == nil then
                    logDebug(string.format("   ptable[\"%s\"] = nil", paramName))
                end
            end

            -- 方法2：如果参数名方式没找到，尝试数字索引（备用）
            if soundObj == nil and shouldLog then
                logDebug("   尝试数字索引...")
                
                for idx = 0, 7 do
                    local val, err = SoundAdjustment.SafeGet(ptable, idx)
                    
                    if err == nil and val ~= nil then
                        local valType = SoundAdjustment.DebugType(val)
                        logDebug(string.format("     [%d] %s", idx, valType))
                        
                        -- 检查类型
                        local isSound = false
                        pcall(function()
                            isSound = LuaUserData.IsTargetType(val, "Barotrauma.Sounds.Sound")
                        end)
                        
                        if isSound then
                            soundObj = val
                            logDebug(string.format("     ✅ 找到Sound对象! (索引%d)", idx))
                            break
                        end
                    end
                end
            end

            -- 方法3：列出所有已知的参数用于调试
            if soundObj == nil and shouldLog then
                logDebug("   列出已知参数:")
                
                local knownParams = {
                    "sound", "position", "volume", "range", 
                    "freqMult", "hullGuess", "ignoreMuffling", 
                    "muteBackgroundMusic"
                }
                
                for _, param in ipairs(knownParams) do
                    local val, _ = SoundAdjustment.SafeGet(ptable, param)
                    
                    if val ~= nil then
                        local valType = type(val)
                        local valStr = ""
                        
                        if valType == "number" then
                            valStr = string.format("%.4f", tonumber(val) or 0)
                        elseif valType == "string" then
                            valStr = tostring(val)
                        elseif valType == "boolean" then
                            valStr = tostring(val)
                        else
                            valStr = string.format("<%s>", valType)
                            -- 尝试获取更多信息
                            pcall(function()
                                if val.Tag ~= nil then
                                    valStr = string.format("<%s Tag=%s>", valType, tostring(val.Tag))
                                end
                            end)
                        end
                        
                        logDebug(string.format("   • %s (%s) = %s", param, valType, valStr))
                    else
                        logDebug(string.format("   • %s = <nil/不存在>", param))
                    end
                end
                
                -- 使用LuaUserData.HasMember检查ptable有哪些成员
                pcall(function()
                    local members = {}
                    -- 尝试一些常见的成员名
                    local testMembers = {"sound", "Sound", "position", "Position", "volume", "Volume"}
                    
                    for _, member in ipairs(testMembers) do
                        local hasMember = LuaUserData.HasMember(ptable, member)
                        if hasMember then
                            table.insert(members, member)
                        end
                    end
                    
                    if #members > 0 then
                        logDebug(string.format("   ptable包含成员: %s", table.concat(members, ", ")))
                    end
                end)
            end

            -- 处理找到的Sound对象
            if soundObj ~= nil then
                if shouldLog then
                    logDebug("   🎯 开始处理Sound对象...")
                end
                
                -- 🔍 安全诊断OggSound对象的属性（每个属性独立pcall，避免一个失败导致全部失败）
                local soundProperties = {}
                
                if shouldLog then
                    logDebug("   ┌─ Sound对象属性诊断 ──────────────")
                    
                    -- 尝试获取各种可能的属性
                    local propertiesToCheck = {
                        "Tag", "Identifier", "Name", "Filename", 
                        "BaseGain", "BaseFar", "Type",
                        "IsMusic", "IsLooped", "Stream"
                    }
                    
                    for _, propName in ipairs(propertiesToCheck) do
                        local propSuccess, propValue = pcall(function()
                            return soundObj[propName]
                        end)
                        
                        if propSuccess and propValue ~= nil then
                            local propType = type(propValue)
                            local propStr = ""
                            
                            if propType == "string" then
                                propStr = tostring(propValue)
                            elseif propType == "number" then
                                propStr = string.format("%.4f", tonumber(propValue) or 0)
                            elseif propType == "boolean" then
                                propStr = tostring(propValue)
                            elseif propType == "userdata" then
                                -- 可能是Identifier类型
                                local idStr = pcall(function()
                                    return propValue.Value
                                end) or "<无法读取>"
                                propStr = string.format("<%s: %s>", propType, tostring(idStr))
                            else
                                propStr = string.format("<%s>", propType)
                            end
                            
                            soundProperties[propName] = propStr  -- 保存到表中
                            logDebug(string.format("   │ • %s (%s) = %s", propName, propType, propStr))
                        else
                            -- 静默跳过不存在的或不可访问的属性
                            if not propSuccess and shouldLog then
                                logDebug(string.format("   │ • %s = <不可访问>", propName))
                            end
                        end
                    end
                    
                    logDebug("   └───────────────────────────────────")
                end
                
                -- 🎯 获取声音标识符（修改优先级：Filename > Identifier > Tag）
                -- 原因：Tag属性在OggSound上不可访问！
                local soundTag = nil
                local tagSource = "无"
                
                -- ⭐ 方法1（首选）：尝试Filename - 这个一定可以访问！
                local fnSuccess, fnVal = pcall(function()
                    return soundObj.Filename
                end)
                
                if fnSuccess and fnVal ~= nil then
                    soundTag = tostring(fnVal)
                    tagSource = "Filename"
                    
                    if shouldLog then
                        logDebug(string.format("   🏷️  使用标签 [Filename]: \"%s\"", soundTag))
                    end
                
                -- 方法2：尝试Identifier.Value
                else
                    local idSuccess, idObj = pcall(function()
                        return soundObj.Identifier
                    end)
                    
                    if idSuccess and idObj ~= nil then
                        local idValSuccess, idVal = pcall(function()
                            return idObj.Value
                        end)
                        
                        if idValSuccess and idVal ~= nil then
                            soundTag = tostring(idVal)
                            tagSource = "Identifier.Value"
                            
                            if shouldLog then
                                logDebug(string.format("   🏷️  使用标签 [Identifier.Value]: \"%s\"", soundTag))
                            end
                        end
                    end
                    
                    -- 方法3：尝试Tag（可能不可访问，但试试看）
                    if soundTag == nil then
                        local tagSuccess, tagVal = pcall(function()
                            return soundObj.Tag
                        end)
                        
                        if tagSuccess and tagVal ~= nil then
                            soundTag = tostring(tagVal)
                            tagSource = "Tag"
                            
                            if shouldLog then
                                logDebug(string.format("   🏷️  使用标签 [Tag]: \"%s\"", soundTag))
                            end
                        else
                            if shouldLog then
                                logDebug("   ⚠️  所有标识符来源都失败!")
                            end
                        end
                    end
                end
                
                -- 如果有标签，进行脚步声检测
                if soundTag ~= nil then
                    SoundAdjustment.RecordSoundTag(soundTag)
                    
                    local isFootstep, kw = SoundAdjustment.IsFootstepSound(soundTag)
                    
                    if isFootstep then
                        DebugStats.footstepSoundCount = DebugStats.footstepSoundCount + 1

                        if shouldLog then
                            logDebug(string.format("   👣 ✅ [Hook1.5] 检测到脚步声! 关键词: [%s] (来源: %s)", kw, tagSource))
                        end

                        if shouldLog then
                            logDebug(string.format("   🎧 hasHeadset: %s",
                                SoundAdjustment.IsHeadsetActive() and "✅ 已装备" or "❌ 未装备"))
                        end

                        local rangeMult = SoundAdjustment.GetActiveConfig("rangeMultiplier")
                        if SoundAdjustment.IsHeadsetActive() and rangeMult ~= nil and rangeMult > 1.0 then
                            local savedNear = nil
                            local savedFar = nil
                            pcall(function() savedNear = soundObj.BaseNear end)
                            pcall(function() savedFar = soundObj.BaseFar end)

                            if savedNear ~= nil and savedFar ~= nil and savedNear > 0 and savedFar > 0 then
                                if SoundAdjustment._pendingMods[soundObj] ~= nil then
                                    if shouldLog then
                                        logDebug("   ⏭️ [BaseFar] 已被GetSound修改，跳过")
                                    end
                                else
                                    SoundAdjustment._pendingMods[soundObj] = {near = savedNear, far = savedFar}
                                    pcall(function() soundObj.BaseNear = savedNear * rangeMult end)
                                    pcall(function() soundObj.BaseFar = savedFar * rangeMult end)

                                    if shouldLog then
                                        logDebug(string.format("   🚀 [BaseFar] %d->%d (直接调用路径)",
                                            math.floor(savedFar), math.floor(savedFar * rangeMult)))
                                    end
                                end
                            end
                        end
                    elseif shouldLog and Config.LogAllSounds then
                        logDebug(string.format("   🔊 普通声音: \"%s\" (来源: %s)", soundTag, tagSource))
                    end
                else
                    if shouldLog then
                        logDebug("   ⚠️ 无可用标签，跳过脚步声检测")
                    end
                end
            else
                if shouldLog then
                    logDebug("   ❌ 无法从ptable中获取Sound对象!")
                    
                    -- 显示ptable的所有可访问信息
                    logDebug("   尝试列出ptable内容:")
                    
                    for i = 0, 7 do
                        local val, err = SoundAdjustment.SafeGet(ptable, i)
                        if err == nil then
                            local typeStr = SoundAdjustment.DebugType(val)
                            local valStr = "..."
                            
                            if type(val) == "number" then
                                valStr = string.format("%.4f", val)
                            elseif type(val) == "string" then
                                valStr = string.format("\"%s\"", val)
                            elseif type(val) == "boolean" then
                                valStr = tostring(val)
                            elseif val == nil then
                                valStr = "nil"
                            end
                            
                            logDebug(string.format("     [%d] %s = %s", i, typeStr, valStr))
                        end
                    end
                end
            end

            -- 始终显示volume参数（用于调试）
            if shouldLog then
                local volumeParam, _ = SoundAdjustment.SafeGet(ptable, "volume")
                if volumeParam ~= nil then
                    logDebug(string.format("   📊 volume=%.4f", tonumber(volumeParam) or 0))
                end
            end

        end,
        Hook.HookMethodType.Before
    )
end)

if hook1_5Success then
    logDebug("✅ Hook 1.5 (Sound对象-Before) 注册成功! ⭐ 关键Hook!")
else
    logDebug(string.format("❌ Hook 1.5 (Sound对象-Before) 注册失败: %s", tostring(hook1_5Err)))
end

-- ========== Hook 1.5-After: 恢复 Sound.BaseNear/BaseFar ==========
logDebug(">>> 注册 Hook 1.5-After: 恢复BaseFar...")

local hook1_5AfterSuccess, hook1_5AfterErr = pcall(function()
    Hook.Patch(
        "Barotrauma.SoundPlayer",
        "PlaySound",
        {
            "Barotrauma.Sounds.Sound",
            "Microsoft.Xna.Framework.Vector2",
            "System.Nullable`1[System.Single]",
            "System.Nullable`1[System.Single]",
            "System.Nullable`1[System.Single]",
            "Barotrauma.Hull",
            "System.Boolean",
            "System.Boolean"
        },
        function(instance, ptable)
            local mods = SoundAdjustment._pendingMods
            if next(mods) ~= nil then
                for soundObj, saved in pairs(mods) do
                    pcall(function() soundObj.BaseNear = saved.near end)
                    pcall(function() soundObj.BaseFar = saved.far end)
                end
                SoundAdjustment._pendingMods = {}
            end
        end,
        Hook.HookMethodType.After
    )
end)

if hook1_5AfterSuccess then
    logDebug("✅ Hook 1.5-After (恢复BaseFar) 注册成功!")
else
    logDebug(string.format("❌ Hook 1.5-After 注册失败: %s", tostring(hook1_5AfterErr)))
end

-- ========== Hook 2: PlaySound(string, float) ==========
logDebug(">>> 注册 Hook 2: PlaySound(2参数)...")

local hook2Success, hook2Err = pcall(function()
    Hook.Patch(
        "Barotrauma.SoundPlayer",
        "PlaySound",
        {
            "System.String",
            "System.Single"
        },
        function(instance, ptable)
            SoundAdjustment.ProcessSoundPlay(ptable, "Hook2")
        end,
        Hook.HookMethodType.Before
    )
end)

if hook2Success then
    logDebug("✅ Hook 2 注册成功!")
else
    logDebug(string.format("❌ Hook 2 注册失败: %s", tostring(hook2Err)))
end

-- ========== Hook 3: Sound.Play(float, float, float, Vector2, bool) [After] ==========
-- ⭐⭐⭐ 最重要！SoundPlayer.PlaySound 最终调用此方法。
-- 策略：After Hook 获取 SoundChannel 返回值，直接修改 channel.Gain（可写属性）
-- 完全绕过 ptable 参数修改，不触发 Double→Single 类型转换问题！
logDebug(">>> 注册 Hook 3: Sound.Play(5参数) [After-修改Gain]...")

local hook3Success, hook3Err = pcall(function()
    Hook.Patch(
        "Barotrauma.Sounds.Sound",
        "Play",
        {
            "System.Single",
            "System.Single",
            "System.Single",
            "Microsoft.Xna.Framework.Vector2",
            "System.Boolean"
        },
        function(instance, ptable)
            DebugStats.totalPlaySoundCalls = DebugStats.totalPlaySoundCalls + 1
            DebugStats.hook3Calls = DebugStats.hook3Calls + 1

            local shouldLog = DebugStats.totalPlaySoundCalls <= Config.MaxDebugLogs

            if shouldLog then
                logDebug(string.format("\n📞 [Hook3-After] Sound.Play(5参数) 被调用 (第%d次)", DebugStats.totalPlaySoundCalls))
                logDebug(string.format("   instance类型: %s", SoundAdjustment.DebugType(instance)))
            end

            if not Config.Enabled then return end
            if instance == nil then return end

            -- 获取 SoundChannel 返回值（After Hook 中 ptable.ReturnValue 可用）
            local channel = nil
            pcall(function()
                channel = ptable.ReturnValue
            end)

            if channel == nil then
                if shouldLog then logDebug("   ⚠️ SoundChannel 为 nil，跳过") end
                return
            end

            -- 获取 Sound 对象的 Filename
            local filename = nil
            pcall(function()
                filename = instance.Filename
            end)

            if shouldLog then
                if filename ~= nil then
                    logDebug(string.format("   🏷️  Filename: \"%s\"", tostring(filename)))
                else
                    logDebug("   ⚠️ Filename为空")
                end
            end

            if filename == nil then return end

            local filenameStr = tostring(filename)
            SoundAdjustment.RecordSoundTag(filenameStr)

            -- 检查是否是脚步声
            local isFootstep, kw = SoundAdjustment.IsFootstepSound(filenameStr)

            if shouldLog then
                if isFootstep then
                    DebugStats.footstepSoundCount = DebugStats.footstepSoundCount + 1
                    logDebug(string.format("   👣 ✅ [Hook3] 检测到脚步声! 关键词: [%s]", kw))
                elseif Config.LogAllSounds then
                    logDebug(string.format("   🔊 普通声音: \"%s\"", filenameStr))
                end
            end

            if not isFootstep then return end

            -- 检查耳机状态
            if shouldLog then
                logDebug(string.format("   🎧 hasHeadset: %s",
                    SoundAdjustment.IsHeadsetActive() and "✅ 已装备" or "❌ 未装备"))
            end

            if not SoundAdjustment.IsHeadsetActive() then return end

            -- 🎯 判断脚步声来源：自己 or 他人
            local isSelf = SoundAdjustment.IsSelfSound(channel, shouldLog)

            if isSelf then
                DebugStats.selfFootstepCount = DebugStats.selfFootstepCount + 1
                if shouldLog then
                    logDebug("   � 自己的脚步声（不修改）")
                end

                local selfMult = SoundAdjustment.GetActiveConfig("selfVolumeMultiplier") or 1.0
                if selfMult ~= 1.0 then
                    local currentGain = 1.0
                    pcall(function()
                        currentGain = channel.Gain
                    end)
                    local newGain = math.min(currentGain * selfMult, 5.0)
                    if newGain ~= currentGain then
                        pcall(function() channel.Gain = newGain end)
                    end
                end
                return
            end

            DebugStats.otherFootstepCount = DebugStats.otherFootstepCount + 1
            if shouldLog then
                logDebug("   👥 他人的脚步声（放大！）")
            end

            -- 🔥 放大他人脚步声：音量（范围扩展由 Hook1.5 Before 负责）
            local currentGain = 1.0
            local gainSuccess = pcall(function()
                currentGain = channel.Gain
            end)

            if shouldLog then
                if gainSuccess then
                    logDebug(string.format("   🔈 原始Gain=%.4f", currentGain))
                else
                    logDebug("   ⚠️ 无法读取 channel.Gain")
                end
            end

            local otherMult = SoundAdjustment.GetActiveConfig("otherVolumeMultiplier") or 3.0
            local newGain = math.min(currentGain * otherMult, 5.0)

            if newGain > currentGain then
                local setSuccess, setErr = pcall(function()
                    channel.Gain = newGain
                end)

                if setSuccess then
                    SoundAdjustment.footstepSoundCount = SoundAdjustment.footstepSoundCount + 1
                    DebugStats.volumeModifiedCount = DebugStats.volumeModifiedCount + 1

                    -- 🔥 扩展可听范围：Near 和 Far
                    if false then -- disabled: now handled by Hook1.5 BaseFar
                        -- 诊：检查 ALSourceIndex
                        local alIdx = -2
                        local alSuccess, alErr = pcall(function()
                            alIdx = channel.ALSourceIndex
                        end)
                        if shouldLog then
                            logDebug(string.format("   🔍 [诊·Range] ALSourceIndex=%d (pcall:%s)",
                                alIdx, alSuccess and "✅" or "❌"))
                            if not alSuccess then
                                logDebug(string.format("   🔍 [诊·Range] ALSourceIndex 错误: %s", tostring(alErr)))
                            end
                        end

                        local currentNear, currentFar = nil, nil
                        local nearSuccess, nearErr = pcall(function()
                            currentNear = channel.Near
                        end)
                        local farSuccess, farErr = pcall(function()
                            currentFar = channel.Far
                        end)

                        if shouldLog then
                            logDebug(string.format("   🔍 [诊·Range] Near读取: %s err=%s val=%s",
                                nearSuccess and "✅" or "❌",
                                nearSuccess and "-" or tostring(nearErr),
                                currentNear == nil and "nil" or string.format("%.2f", currentNear)))
                            logDebug(string.format("   🔍 [诊·Range] Far读取:  %s err=%s val=%s",
                                farSuccess and "✅" or "❌",
                                farSuccess and "-" or tostring(farErr),
                                currentFar == nil and "nil" or string.format("%.2f", currentFar)))
                        end

                        if not nearSuccess then
                            if shouldLog then
                                logDebug("   ⚠️ [诊·Range] channel.Near 读取失败，跳过范围扩展")
                            end
                        elseif currentNear == nil then
                            if shouldLog then
                                logDebug("   ⚠️ [诊·Range] channel.Near 为 nil，跳过范围扩展")
                            end
                        elseif currentNear == 0 then
                            if shouldLog then
                                logDebug("   ⚠️ [诊·Range] channel.Near==0 (AL源可能未初始化)，跳过")
                            end
                        else
                            local newNear = currentNear * Config.RangeMultiplier
                            local newFar = nil
                            if currentFar ~= nil and currentFar > 0 then
                                newFar = currentFar * Config.RangeMultiplier
                            else
                                newFar = currentNear * Config.RangeMultiplier * 2.5
                            end

                            local setNearOk, setNearErr = pcall(function()
                                channel.Near = newNear
                            end)
                            local setFarOk, setFarErr = pcall(function()
                                channel.Far = newFar
                            end)

                            -- 🔑 先 nil 再恢复 Position，切换 SourceRelative 强制 OpenAL 完全重初始化距离衰减
                            local savedPos = nil
                            pcall(function() savedPos = channel.Position end)
                            if savedPos ~= nil then
                                pcall(function() channel.Position = nil end)
                                pcall(function() channel.Position = savedPos end)
                            end

                            -- 诊：验证是否真的写入了
                            local verifyNear, verifyFar = nil, nil
                            pcall(function() verifyNear = channel.Near end)
                            pcall(function() verifyFar = channel.Far end)

                            if shouldLog then
                                logDebug(string.format("   � [诊·Range] 写入Near: %s err=%s", setNearOk and "✅" or "❌",
                                    setNearOk and "-" or tostring(setNearErr)))
                                logDebug(string.format("   🔍 [诊·Range] 写入Far:  %s err=%s", setFarOk and "✅" or "❌",
                                    setFarOk and "-" or tostring(setFarErr)))
                                logDebug(string.format("   🔍 [诊·Range] 验证Near: %.1f -> %.1f (期望%.1f)",
                                    currentNear, verifyNear or -1, newNear))
                                logDebug(string.format("   🔍 [诊·Range] 验证Far:  %.1f -> %.1f (期望%.1f)",
                                    currentFar or -1, verifyFar or -1, newFar))
                                logDebug(string.format("   📡 Near:%.1f->%.1f Far:%.1f->%.1f x%.1f PosReset:%s",
                                    currentNear, verifyNear or 0, currentFar or 0, verifyFar or 0,
                                    Config.RangeMultiplier, savedPos ~= nil and "Y" or "N"))
                                logDebug(string.format("   🗺️  范围对比: 修改前Far=%.0f 修改后Far=%.0f | 离声源>%.0f才能感知变化",
                                    currentFar or 0, verifyFar or 0, currentFar or 0))
                            end
                        end
                    end

                    if shouldLog then
                        logDebug(string.format("   🎯✨ [Hook3-After] Gain已修改!: %.4f -> %.4f (x%.1f)",
                            currentGain, newGain, otherMult))
                        logDebug(string.format("   📊 统计: 总=%d 脚步=%d 自己=%d 他人=%d 修改=%d H3=%d",
                            DebugStats.totalPlaySoundCalls,
                            DebugStats.footstepSoundCount,
                            DebugStats.selfFootstepCount,
                            DebugStats.otherFootstepCount,
                            DebugStats.volumeModifiedCount,
                            DebugStats.hook3Calls))
                    end
                else
                    if shouldLog then
                        logDebug(string.format("   ❌ [Hook3-After] 设置Gain失败: %s", tostring(setErr)))
                    end
                end
            else
                if shouldLog then
                    logDebug(string.format("   ⚠️ [Hook3-After] Gain未改变 (%.4f -> %.4f)", currentGain, newGain))
                end
            end

        end,
        Hook.HookMethodType.After
    )
end)

if hook3Success then
    logDebug("✅ Hook 3 (Sound.Play-5参数-After) 注册成功! ⭐⭐⭐")
else
    logDebug(string.format("❌ Hook 3 (Sound.Play-5参数-After) 注册失败: %s", tostring(hook3Err)))
end

logDebug("")
logDebug("=====================================")
logDebug("✅ 所有Hooks注册完成!")
logDebug("=====================================")
logDebug("")

-- ==================== 定期检测耳机状态 ====================

Hook.Add("think", "SoundAdjustment.Update", function()
    if not Config.Enabled then return end
    
    local currentTime = Timer.GetTime()
    
    if currentTime - SoundAdjustment.lastCheckTime < Config.CheckInterval then
        return
    end
    
    SoundAdjustment.lastCheckTime = currentTime
    
    local headsetConfig, headsetId = SoundAdjustment.CheckHeadset()
    
    local wasActive = SoundAdjustment.activeHeadsetConfig ~= nil
    local nowActive = headsetConfig ~= nil
    local changed = (headsetId ~= SoundAdjustment.activeHeadsetId)
    
    SoundAdjustment.activeHeadsetConfig = headsetConfig
    SoundAdjustment.activeHeadsetId = headsetId
    
    if changed then
        if headsetConfig ~= nil then
            log(string.format("✅ 检测到 %s (%s)，听声辩位已启用 (音量%.1fx, 范围%.1fx)",
                headsetId, headsetConfig.name or headsetId,
                headsetConfig.otherVolumeMultiplier, headsetConfig.rangeMultiplier))
                
            Timer.Wait(function()
                if not SILENT then
                print("")
                print("╔══════════════════════════════════════╗")
                print("║     🎧 SoundAdjustment 声音增强      ║")
                print("╠══════════════════════════════════════╣")
                print("║  状态: ✅ 已激活                     ║")
                print(string.format("║  装备: %-29s ║", headsetConfig.name or headsetId))
                print("║  听声辩位: ✅ 自己不变，他人放大+扩展  ║")
                print(string.format("║  他人音量: %-26.0f%% ║", headsetConfig.otherVolumeMultiplier * 100))
                print(string.format("║  范围扩展: %-26.0f%% ║", headsetConfig.rangeMultiplier * 100))
                print("╚══════════════════════════════════════╝")
                print("")
                end
                SoundAdjustment.PrintDebugStats()
            end, 100)
        else
            log("❌ 目标耳机已移除，恢复原始音量")
            
            Timer.Wait(function()
                if not SILENT then
                print("")
                print("╔══════════════════════════════════════╗")
                print("║     🔇 SoundAdjustment 声音增强      ║")
                print("╠══════════════════════════════════════╣")
                print("║  状态: ❌ 已禁用                     ║")
                print("║  原因: 目标耳机已移除               ║")
                print("╚══════════════════════════════════════╝")
                print("")
                end
            end, 100)
        end
    end
end)

-- ==================== 调试统计输出 ====================

function SoundAdjustment.PrintDebugStats()
    if SILENT then return end
    print("")
    print("┌──────────────────────────────────────────────────┐")
    print("│       📊 SoundAdjustment 调试统计 (v4.0)        │")
    print("├──────────────────────────────────────────────────┤")
    print(string.format("│ 模组启用: %-38s │", Config.Enabled and "✅ 是" or "❌ 否"))
    print(string.format("│ 耳机状态: %-38s │",
        SoundAdjustment.IsHeadsetActive() and "🎧 已装备" or "🔇 未装备"))
    print("├──────────────────────────────────────────────────┤")
    print(string.format("│ PlaySound总调用: %-30d │", DebugStats.totalPlaySoundCalls))
    print(string.format("│ ├─ Hook1 (String,5参数): %-23d │", DebugStats.hook1Calls))
    print(string.format("│ │  └─ Hook1.5Before (Sound): %-18d │", DebugStats.hook1_5Calls or 0))
    print(string.format("│ ├─ Hook2 (String,2参数): %-23d │", DebugStats.hook2Calls))
    print(string.format("│ └─ Hook3 (After-Gain): %-21d │", DebugStats.hook3Calls))
    print(string.format("│ 脚步声检测: %-32d │", DebugStats.footstepSoundCount))
    print(string.format("│ ├─ 自己脚步: %-33d │", DebugStats.selfFootstepCount))
    print(string.format("│ └─ 他人脚步: %-33d │", DebugStats.otherFootstepCount))
    local activeVol = SoundAdjustment.GetActiveConfig("otherVolumeMultiplier") or 0
    local activeRange = SoundAdjustment.GetActiveConfig("rangeMultiplier") or 0
    print(string.format("│ 他人音量: %-30.1fx │", activeVol))
    print(string.format("│ 范围扩展: %-30.1fx │", activeRange))
    print(string.format("│ 音量修改成功: %-30d │", DebugStats.volumeModifiedCount))
    print(string.format("│ 耳机检测次数: %-30d │", DebugStats.headsetCheckCount))
    print(string.format("│ 耳机检测成功: %-30d │", DebugStats.headsetDetectedCount))
    print("├──────────────────────────────────────────────────┤")
    
    if #DebugStats.lastSoundTags > 0 then
        print("│ 最近的声音标签:                          │")
        local showCount = math.min(5, #DebugStats.lastSoundTags)
        for i = 1, showCount do
            local tag = DebugStats.lastSoundTags[i]
            local isFootstep, _ = SoundAdjustment.IsFootstepSound(tag)
            local marker = isFootstep and "👣" or "🔊"
            print(string.format("   %d. %s %-36s", i, marker, tag))
        end
    end
    
    print("└────────────────────────────────────────────┘")
    print("")
end

-- ==================== 控制台命令 ====================

Hook.Add("chatMessage", "SoundAdjustment.Commands", function(message, client)
    if not message:startsWith("/sound") then return end
    
    local args = {}
    for arg in message:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args < 2 then
        return true, "用法: /sound [on|off|status|volume|debug|info|stats|test]"
    end
    
    local command = args[2]:lower()
    
    if command == "on" then
        Config.Enabled = true
        return true, "[SoundAdjustment] ✅ 已启用"
    elseif command == "off" then
        Config.Enabled = false
        SoundAdjustment.activeHeadsetConfig = nil
        SoundAdjustment.activeHeadsetId = nil
        return true, "[SoundAdjustment] ❌ 已禁用"
    elseif command == "status" then
        local headsetInfo = "无"
        local vol = "N/A"
        local range = "N/A"
        if SoundAdjustment.activeHeadsetConfig ~= nil then
            headsetInfo = string.format("%s (%s)", SoundAdjustment.activeHeadsetId, SoundAdjustment.activeHeadsetConfig.name or "")
            vol = string.format("%.1fx", SoundAdjustment.activeHeadsetConfig.otherVolumeMultiplier)
            range = string.format("%.1fx", SoundAdjustment.activeHeadsetConfig.rangeMultiplier)
        end
        return true, string.format(
            "[SoundAdjustment]\n" ..
            "  启用: %s\n" ..
            "  耳机: %s\n" ..
            "  他人倍率: %s\n" ..
            "  范围倍率: %s\n" ..
            "  状态: %s\n" ..
            "  自己脚步: %d\n" ..
            "  他人脚步: %d\n" ..
            "  修改: %d次\n" ..
            "  统计: H1=%d H2=%d H3=%d",
            Config.Enabled and "✅" or "❌",
            headsetInfo,
            vol,
            range,
            SoundAdjustment.IsHeadsetActive() and "🎧" or "🔇",
            DebugStats.selfFootstepCount,
            DebugStats.otherFootstepCount,
            DebugStats.volumeModifiedCount,
            DebugStats.hook1Calls,
            DebugStats.hook2Calls,
            DebugStats.hook3Calls
        )
    elseif command == "volume" and #args >= 3 then
        local newVol = tonumber(args[3])
        if newVol == nil or newVol < 1.0 or newVol > 10.0 then
            return true, "错误：倍率必须在 1.0-10.0 之间"
        end
        if SoundAdjustment.activeHeadsetConfig ~= nil then
            SoundAdjustment.activeHeadsetConfig.otherVolumeMultiplier = newVol
        end
        return true, string.format("[SoundAdjustment] 当前耳机他人倍率设置为 %.1fx", newVol)
    elseif command == "debug" then
        DEBUG = not DEBUG
        Config.LogAllSounds = DEBUG
        return true, string.format("[SoundAdjustment] 调试: %s", DEBUG and "✅ 开启" or "❌ 关闭")
    elseif command == "info" then
        LOG_INFO = not LOG_INFO
        return true, string.format("[SoundAdjustment] 提示信息: %s", LOG_INFO and "✅ 开启" or "❌ 关闭")
    elseif command == "silent" then
        SILENT = not SILENT
        return true, string.format("[SoundAdjustment] 静音模式: %s", SILENT and "🔇 开启" or "🔊 关闭")
    elseif command == "stats" then
        SoundAdjustment.PrintDebugStats()
        return true, "✅ 统计已输出"
    elseif command == "test" then
        Timer.Wait(function()
            log("--- 手动测试 ---")
            log(string.format("Enabled=%s", tostring(Config.Enabled)))
            log(string.format("activeHeadset=%s", tostring(SoundAdjustment.activeHeadsetId or "nil")))
            log(string.format("Character.Controlled=%s", 
                Character.Controlled ~= nil and "存在" or "nil"))
            
            if Character.Controlled ~= nil then
                log(string.format("Removed=%s", tostring(Character.Controlled.Removed)))
                log(string.format("Inventory=%s", 
                    Character.Controlled.Inventory ~= nil and "存在" or "nil"))
                
                if Character.Controlled.Inventory ~= nil then
                    local item = nil
                    pcall(function() 
                        item = Character.Controlled.Inventory.GetItemInLimbSlot(64) 
                    end)
                    log(string.format("GetItemInLimbSlot(64)=%s", 
                        item ~= nil and "有物品" or "nil"))
                    
                    if item ~= nil then
                        pcall(function()
                            if item.Prefab ~= nil and item.Prefab.Identifier ~= nil then
                                log(string.format("ID=%s", item.Prefab.Identifier.Value))
                            end
                            if item.Name ~= nil then
                                log(string.format("Name=%s", tostring(item.Name)))
                            end
                            
                            -- 使用LuaUserData检查类型
                            local itemType = SoundAdjustment.DebugType(item)
                            log(string.format("LuaType=%s", itemType))
                        end)
                    end
                end
            end
            
            local result = SoundAdjustment.CheckHeadset()
            log(string.format("CheckHeadset()=%s", tostring(result)))
            log("--- 测试结束 ---")
        end, 100)
        return true, "✅ 测试完成"
    end
    
    return true, "未知命令: " .. command
end)

-- ==================== 初始化 ====================

Timer.Wait(function()
    SoundAdjustment.isInitialized = true
    
    if not SILENT then
    print("")
    print("╔════════════════════════════════════════════════╗")
    print("║   SoundAdjustment 声音调节模组 (v4.0)         ║")
    print("╠════════════════════════════════════════════════╣")
    print(string.format("║  版本: 4.0                                     ║"))
    print(string.format("║  状态: ✅ 已加载                               ║"))
    print(string.format("║  Hook1 (String,5参数): %-25s ║", hook1Success and "✅ 成功" or "❌ 失败"))
    print(string.format("║  Hook1-GetSound (After): %-22s ⭐ ║", hookGetSoundSuccess and "✅ 成功" or "❌ 失败"))
    print(string.format("║  Hook1.5Before (Sound): %-23s ║", hook1_5Success and "✅ 成功" or "❌ 失败"))
    print(string.format("║  Hook1.5After (恢复BaseFar): %-21s ║", hook1_5AfterSuccess and "✅ 成功" or "❌ 失败"))
    print(string.format("║  Hook2 (String,2参数): %-25s ║", hook2Success and "✅ 成功" or "❌ 失败"))
    print(string.format("║  Hook3 (After-Gain): %-24s ║", hook3Success and "✅ 成功" or "❌ 失败"))
    print(string.format("║  调试模式: %-33s ║", DEBUG and "✅ 开启" or "❌ 关闭"))
    print(string.format("║  提示信息: %-33s ║", LOG_INFO and "✅ 开启" or "❌ 关闭"))
    print("╠════════════════════════════════════════════════╣")
    print("║  已配置耳机:                                     ║")
    for headsetId, hc in pairs(Config.Headsets) do
        print(string.format("║  • %s: 音量x%.1f 范围x%.1f          ║",
            hc.name or headsetId, hc.otherVolumeMultiplier, hc.rangeMultiplier))
    end
    print("╠════════════════════════════════════════════════╣")
    print("║  策略:                                           ║")
    print("║  • 戴耳机后，自己的脚步声不变                     ║")
    print("║  • 他人脚步声：Gain xN（Hook3 After）            ║")
    print("║  • 范围扩展：Hook GetSound After 修改 BaseFar    ║")
    print("╠════════════════════════════════════════════════╣")
    print("║  命令: /sound [stats|test|debug|info|status|volume] ║")
    print("╚════════════════════════════════════════════════╝")
    print("")
    end
    
    -- 初始检测
    Timer.Wait(function()
        log("--- 初始化检测 ---")
        local headsetConfig, headsetId = SoundAdjustment.CheckHeadset()
        SoundAdjustment.activeHeadsetConfig = headsetConfig
        SoundAdjustment.activeHeadsetId = headsetId
        
        if headsetConfig ~= nil then
            log(string.format("✅ 发现 %s (%s)，听声辩位激活!", headsetId, headsetConfig.name or headsetId))
        else
            log("ℹ️ 未发现任何已配置的耳机，等待装备...")
        end
        
        SoundAdjustment.PrintDebugStats()
    end, 1000)
    
end, 500)

return SoundAdjustment
