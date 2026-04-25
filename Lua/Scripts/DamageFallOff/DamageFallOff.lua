--伤害衰减脚本(26.4.2;4:22 By peach) - 多套衰减配置版本
local DistanceCalculator = {}

-- 全局配置
DistanceCalculator.Config = {
    enabled = true,                -- 是否启用
    showInConsole = false,          -- 是否在控制台显示
    debugMode = false,
    damageFalloffEnabled = true,    -- 是否启用距离伤害衰减
}

-- 衰减配置档案表 - 支持多套不同的衰减参数
-- 每个 profile 包含：affliction名称、起始距离、结束距离、最小倍率
DistanceCalculator.FalloffProfiles = {
    -- 默认配置：600-1200厘米
    ["deep_damage_fall_off_600_1200_detect"] = {
        falloffStartDistance = 600,
        falloffEndDistance = 1200,
        minDamageMultiplier = 0.05
    },
    -- 新增配置：1600-2300厘米
    ["deep_damage_fall_off_1500_2300_detect"] = {
        falloffStartDistance = 1500,
        falloffEndDistance = 2300,
        minDamageMultiplier = 0.05
    },
    -- 可以继续添加更多配置...
    -- 示例：
    -- ["deep_damage_fall_off_custom_detect"] = {
    --     falloffStartDistance = 800,
    --     falloffEndDistance = 1500,
    --     minDamageMultiplier = 0.1
    -- },
}

-- 存储需要应用衰减的信息
DistanceCalculator.PendingFalloff = {}

-- 计算两点之间的距离（返回厘米，世界坐标本身就是厘米单位）
function DistanceCalculator.CalculateDistanceInCentimeters(pos1, pos2)
    if pos1 == nil or pos2 == nil then
        return 0
    end
    
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    -- 世界坐标已经是厘米单位，直接返回距离
    return math.sqrt(dx * dx + dy * dy)
end

-- 计算距离伤害倍率 - 支持传入自定义配置
function DistanceCalculator.CalculateFalloffMultiplier(distance, profile)
    local config = profile or DistanceCalculator.Config
    
    if not DistanceCalculator.Config.damageFalloffEnabled then
        return 1.0
    end
    
    if distance <= config.falloffStartDistance then
        return 1.0
    end
    
    if distance >= config.falloffEndDistance then
        return config.minDamageMultiplier
    end
    
    -- 线性插值计算衰减
    local falloffRange = config.falloffEndDistance - config.falloffStartDistance
    local currentFalloff = distance - config.falloffStartDistance
    local falloffRatio = currentFalloff / falloffRange
    
    return 1.0 - (falloffRatio * (1.0 - config.minDamageMultiplier))
end

-- 检测攻击者是否有匹配的衰减配置
-- 返回：匹配的配置名称（affliction名称）和对应的配置数据，如果没有匹配则返回 nil
function DistanceCalculator.DetectFalloffProfile(attacker)
    if attacker == nil then
        DistanceCalculator.Debug("DetectFalloffProfile: attacker 为空")
        return nil, nil
    end
    
    if attacker.CharacterHealth == nil then
        DistanceCalculator.Debug("DetectFalloffProfile: attacker.CharacterHealth 为空")
        return nil, nil
    end
    
    local matchedName = nil
    local matchedProfile = nil
    
    local success, err = pcall(function()
        local debugInfo = "正在检查 Afflictions: "
        
        for afflictionName, profile in pairs(DistanceCalculator.FalloffProfiles) do
            debugInfo = debugInfo .. tostring(afflictionName) .. ", "
            
            local affliction = nil
            local getSuccess, getErr = pcall(function()
                affliction = attacker.CharacterHealth.GetAffliction(afflictionName)
            end)
            
            if not getSuccess then
                DistanceCalculator.Debug(string.format("获取 Affliction '%s' 失败: %s", tostring(afflictionName), tostring(getErr)))
            elseif affliction ~= nil then
                local strength = affliction.Strength
                DistanceCalculator.Debug(string.format("✅ 找到 Affliction '%s', Strength = %.3f (阈值: > 0)", 
                    tostring(afflictionName), strength))
                
                -- 只要 Strength > 0.5 就认为有效
                if strength > 0.5 then
                    matchedName = afflictionName
                    matchedProfile = profile
                    return  -- 找到匹配，提前退出循环
                else
                    DistanceCalculator.Debug(string.format("Affliction '%s' 的 Strength (%.3f) <= 0，跳过", 
                        tostring(afflictionName), strength))
                end
            else
                DistanceCalculator.Debug(string.format("❌ 未找到 Affliction '%s'", tostring(afflictionName)))
            end
        end
        
        DistanceCalculator.Debug(debugInfo .. " → 无匹配")
    end)
    
    if not success then
        DistanceCalculator.Debug(string.format("⚠️ 检测衰减配置异常: %s", tostring(err)))
    end
    
    if matchedName ~= nil then
        DistanceCalculator.Debug(string.format("🎯 匹配成功: %s", tostring(matchedName)))
    end
    
    return matchedName, matchedProfile
end

-- 获取攻击者所有 Affliction 信息（用于调试）- 简化版本避免 API 错误
function DistanceCalculator.GetAllAfflictionsDebug(attacker)
    if attacker == nil or attacker.CharacterHealth == nil then
        return "无法获取角色信息"
    end
    
    local info = ""
    
    -- 只检测我们关心的几个 Affliction，避免访问不存在的字段
    for afflictionName, _ in pairs(DistanceCalculator.FalloffProfiles) do
        local success, result = pcall(function()
            local aff = attacker.CharacterHealth.GetAffliction(afflictionName)
            if aff ~= nil then
                return string.format("%s=%.2f", tostring(afflictionName), aff.Strength or 0)
            else
                return string.format("%s=不存在", tostring(afflictionName))
            end
        end)
        
        if success then
            info = info .. result .. " | "
        else
            info = info .. string.format("%s=错误(%s) | ", tostring(afflictionName), tostring(result):sub(1, 30))
        end
    end
    
    return info or "无数据"
end

-- 调试输出
function DistanceCalculator.Debug(message)
    if DistanceCalculator.Config.debugMode then
        print("[DistanceCalculator] " .. message)
    end
end

-- 监听伤害事件 - 在这里计算距离并存储
Hook.Add("character.damageLimb", "DistanceCalculator.OnDamageLimb", function(character, worldPosition, hitLimb, afflictions, stun, playSound, attackImpulse, attacker, damageMultiplier, allowStacking, penetration, shouldImplode)
    
    if not DistanceCalculator.Config.enabled then
        return nil
    end
    
    -- 获取攻击者
    if attacker == nil then
        DistanceCalculator.Debug("无攻击者")
        return nil
    end
    
    local attackerPos = attacker.WorldPosition
    if attackerPos == nil then
        DistanceCalculator.Debug("无法获取攻击者位置")
        return nil
    end
    
    -- 获取被攻击者
    local targetPos = nil
    if character ~= nil then
        targetPos = character.WorldPosition
    elseif hitLimb ~= nil and hitLimb.character ~= nil then
        targetPos = hitLimb.character.WorldPosition
    end
    
    if targetPos == nil then
        DistanceCalculator.Debug("无法获取被攻击者位置")
        return nil
    end
    
    -- 计算距离（厘米）
    local distanceCm = DistanceCalculator.CalculateDistanceInCentimeters(attackerPos, targetPos)
    
    -- 获取名称
    local attackerName = tostring(attacker.Name or "Unknown")
    local targetName = character and tostring(character.Name or "Unknown") or "Unknown"
    
    -- 简化版本：使用距离来判断是否是远程攻击
    -- 假设远距离攻击（> 100厘米）是远程武器
    local isRangedWeapon = distanceCm > 150
    local weaponItem = nil
    
    -- 检查攻击者是否有匹配的衰减 Affliction
    local matchedAfflictionName, matchedProfile = DistanceCalculator.DetectFalloffProfile(attacker)
    local hasBurnAffliction = (matchedProfile ~= nil)
    
    -- 如果没有检测到，输出详细的 Affliction 调试信息
    if not hasBurnAffliction and DistanceCalculator.Config.showInConsole then
        local allAffs = DistanceCalculator.GetAllAfflictionsDebug(attacker)
        print(string.format("[DistanceCalculator] ⚠️ 未检测到匹配的衰减 Affliction | 攻击者所有 Afflictions: %s", allAffs))
    end
    
    -- 计算衰减倍率 - 使用匹配到的配置
    local falloffMultiplier = 1.0
    if isRangedWeapon and hasBurnAffliction then
        falloffMultiplier = DistanceCalculator.CalculateFalloffMultiplier(distanceCm, matchedProfile)
    end
    local shouldApplyFalloff = isRangedWeapon and hasBurnAffliction and (falloffMultiplier < 1.0)
    
    -- 构建消息
    local message = string.format("[距离] 攻击者: %s(%.1f, %.1f) → 被攻击者: %s(%.1f, %.1f) | 距离: %.1f 厘米", 
        attackerName, attackerPos.X, attackerPos.Y, targetName, targetPos.X, targetPos.Y, distanceCm)
    
    -- 添加攻击类型信息
    if isRangedWeapon then
        message = message .. " | 攻击类型: 远程"
    else
        message = message .. " | 攻击类型: 近战"
    end
    
    -- 添加衰减配置信息
    if hasBurnAffliction then
        message = message .. string.format(" | 配置: %s (激活伤害衰减)", tostring(matchedAfflictionName))
        if matchedProfile then
            message = message .. string.format(" [%.0f-%.0fcm, 最小%.0f%%]", 
                matchedProfile.falloffStartDistance, 
                matchedProfile.falloffEndDistance, 
                matchedProfile.minDamageMultiplier * 100)
        end
    else
        message = message .. " | 状态: 未启用伤害衰减"
    end
    
    if shouldApplyFalloff then
        local damageReduction = (1.0 - falloffMultiplier) * 100
        message = message .. string.format(" | 伤害衰减: %.0f%% (剩余 %.0f%%)", damageReduction, falloffMultiplier * 100)
        
        -- 存储衰减信息，供后面的 ApplyDamage 使用
        if character ~= nil then
            local characterId = tostring(character.ID or "unknown")
            DistanceCalculator.PendingFalloff[characterId] = {
                multiplier = falloffMultiplier,
                time = os.time()
            }
            DistanceCalculator.Debug("已存储衰减信息: " .. characterId .. ", 倍率: " .. falloffMultiplier)
        end
    end
    
    -- 输出到控制台
    if DistanceCalculator.Config.showInConsole then
        print(message)
    end
    
    DistanceCalculator.Debug(message)
    
    return nil
end)

-- Patch ApplyDamage 方法来应用衰减
Hook.Patch("Barotrauma.CharacterHealth", "ApplyDamage", function(instance, ptable)
    
    if not DistanceCalculator.Config.enabled or not DistanceCalculator.Config.damageFalloffEnabled then
        return
    end
    
    local attackResult = ptable["attackResult"]
    local character = instance.Character
    
    if attackResult == nil or attackResult.Afflictions == nil or character == nil then
        return
    end
    
    -- 检查是否有待处理的衰减
    local characterId = tostring(character.ID or "unknown")
    local falloffData = DistanceCalculator.PendingFalloff[characterId]
    
    if falloffData == nil then
        return
    end
    
    -- 检查是否过期（5秒内）
    if os.time() - falloffData.time > 5 then
        DistanceCalculator.PendingFalloff[characterId] = nil
        return
    end
    
    local multiplier = falloffData.multiplier
    
    -- 修改 afflictions
    local success, err = pcall(function()
        for i, affliction in ipairs(attackResult.Afflictions) do
            if affliction ~= nil then
                local originalStrength = affliction.Strength
                affliction.Strength = originalStrength * multiplier
                
                DistanceCalculator.Debug(string.format("ApplyDamage 衰减伤害: %s, 原始: %.1f, 衰减后: %.1f", 
                    tostring(affliction.Prefab.Identifier), originalStrength, affliction.Strength))
            end
        end
    end)
    
    if not success then
        DistanceCalculator.Debug("ApplyDamage 修改失败: " .. tostring(err))
    else
        DistanceCalculator.Debug(string.format("ApplyDamage 已应用伤害衰减: 倍率 %.2f", multiplier))
    end
    
    -- 清除待处理的衰减
    DistanceCalculator.PendingFalloff[characterId] = nil
    
end, Hook.HookMethodType.Before)

-- 清理过期的衰减数据
Hook.Add("think", "DistanceCalculator.Cleanup", function()
    local currentTime = os.time()
    local toRemove = {}
    
    for characterId, data in pairs(DistanceCalculator.PendingFalloff) do
        if currentTime - data.time > 10 then
            table.insert(toRemove, characterId)
        end
    end
    
    for _, characterId in ipairs(toRemove) do
        DistanceCalculator.PendingFalloff[characterId] = nil
    end
end)

-- 控制台命令
Hook.Add("chatMessage", "DistanceCalculator.Commands", function(message, client)
    if not message:startsWith("/distance") then
        return
    end
    
    local args = {}
    for arg in message:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args < 2 then
        return true, "用法: /distance [on|off|status|console|falloff|falloffon|falloffoff|setstart <距离>|setend <距离>|setmin <倍率>]"
    end
    
    local command = args[2]:lower()
    
    if command == "on" then
        DistanceCalculator.Config.enabled = true
        return true, "距离计算器已启用"
    elseif command == "off" then
        DistanceCalculator.Config.enabled = false
        return true, "距离计算器已禁用"
    elseif command == "debug" then
        DistanceCalculator.Config.debugMode = not DistanceCalculator.Config.debugMode
        DistanceCalculator.Config.showInConsole = DistanceCalculator.Config.debugMode  -- 同时切换控制台输出
        return true, string.format("调试模式: %s (控制台显示: %s)", 
            DistanceCalculator.Config.debugMode and "启用" or "禁用",
            DistanceCalculator.Config.showInConsole and "启用" or "禁用")
    elseif command == "status" then
        local status = string.format("状态: %s\n控制台显示: %s\n伤害衰减: %s\n配置数量: %d",
            DistanceCalculator.Config.enabled and "启用" or "禁用",
            DistanceCalculator.Config.showInConsole and "是" or "否",
            DistanceCalculator.Config.damageFalloffEnabled and "启用" or "禁用",
            DistanceCalculator.CountProfiles())
        
        -- 显示所有配置详情
        local profileList = "\n\n已配置的衰减档案:"
        for afflictionName, profile in pairs(DistanceCalculator.FalloffProfiles) do
            profileList = profileList .. string.format("\n  - %s [%.0f-%.0fcm, 最小%.0f%%伤害]",
                tostring(afflictionName),
                profile.falloffStartDistance,
                profile.falloffEndDistance,
                profile.minDamageMultiplier * 100)
        end
        
        return true, status .. profileList
    elseif command == "console" then
        DistanceCalculator.Config.showInConsole = not DistanceCalculator.Config.showInConsole
        return true, "控制台显示: " .. (DistanceCalculator.Config.showInConsole and "启用" or "禁用")
    elseif command == "falloffon" then
        DistanceCalculator.Config.damageFalloffEnabled = true
        return true, "伤害衰减已启用"
    elseif command == "falloffoff" then
        DistanceCalculator.Config.damageFalloffEnabled = false
        return true, "伤害衰减已禁用"
    elseif command == "falloff" then
        DistanceCalculator.Config.damageFalloffEnabled = not DistanceCalculator.Config.damageFalloffEnabled
        return true, "伤害衰减: " .. (DistanceCalculator.Config.damageFalloffEnabled and "启用" or "禁用")
    elseif command == "profiles" then
        -- 显示所有可用的配置档案
        local count = DistanceCalculator.CountProfiles()
        local msg = string.format("共有 %d 个衰减配置档案:", count)
        
        for afflictionName, profile in pairs(DistanceCalculator.FalloffProfiles) do
            msg = msg .. string.format("\n  [%s] 起始: %.0fcm | 结束: %.0fcm | 最小倍率: %.2f (%.0f%%伤害)",
                tostring(afflictionName),
                profile.falloffStartDistance,
                profile.falloffEndDistance,
                profile.minDamageMultiplier,
                profile.minDamageMultiplier * 100)
        end
        
        return true, msg
    elseif command == "setstart" and #args >= 3 then
        local value = tonumber(args[3])
        if value == nil then
            return true, "错误：距离必须是数字"
        end
        -- 注意：现在需要指定要修改的配置名称，或者修改所有配置
        -- 这里暂时保留向后兼容性，修改第一个配置（如果需要可以后续改进）
        local firstProfile = next(DistanceCalculator.FalloffProfiles)
        if firstProfile then
            DistanceCalculator.FalloffProfiles[firstProfile].falloffStartDistance = value
            return true, string.format("配置 '%s' 的起始距离已设置为 %.0f 厘米", firstProfile, value)
        else
            return true, "错误：没有可用的配置"
        end
    elseif command == "setend" and #args >= 3 then
        local value = tonumber(args[3])
        if value == nil then
            return true, "错误：距离必须是数字"
        end
        local firstProfile = next(DistanceCalculator.FalloffProfiles)
        if firstProfile then
            DistanceCalculator.FalloffProfiles[firstProfile].falloffEndDistance = value
            return true, string.format("配置 '%s' 的结束距离已设置为 %.0f 厘米", firstProfile, value)
        else
            return true, "错误：没有可用的配置"
        end
    elseif command == "setmin" and #args >= 3 then
        local value = tonumber(args[3])
        if value == nil then
            return true, "错误：倍率必须是数字"
        end
        local firstProfile = next(DistanceCalculator.FalloffProfiles)
        if firstProfile then
            DistanceCalculator.FalloffProfiles[firstProfile].minDamageMultiplier = math.clamp(value, 0, 1)
            return true, string.format("配置 '%s' 的最小倍率已设置为 %.2f (%.0f%%伤害)", 
                firstProfile,
                DistanceCalculator.FalloffProfiles[firstProfile].minDamageMultiplier, 
                DistanceCalculator.FalloffProfiles[firstProfile].minDamageMultiplier * 100)
        else
            return true, "错误：没有可用的配置"
        end
    end
    
    return true, "未知命令: " .. command .. "\n可用命令: on|off|status|console|falloff|falloffon|falloffoff|profiles|setstart|setend|setmin"
end)

-- 统计配置数量
function DistanceCalculator.CountProfiles()
    local count = 0
    for _ in pairs(DistanceCalculator.FalloffProfiles) do
        count = count + 1
    end
    return count
end

return DistanceCalculator
