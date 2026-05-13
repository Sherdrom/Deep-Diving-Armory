-- ============================================================
-- AdjustStatvalue.lua
-- 当玩家装备(Holdable)指定物品时，直接修改玩家的 StatValue 和 AbilityFlag
-- 取消装备时自动撤销
--
-- 与 WeaponAfflictionBind 不同：
--   WeaponAfflictionBind 通过 Affliction 间接实现效果
--   AdjustStatvalue 直接调用 Character:ChangeStat() / AbilityFlag API
--
-- 支持主从物品系统：
--   主体（IsMain）：拿在手上时生效
--   子体（IsSub）：只有在主体的物品栏中才生效
-- ============================================================

-- ============================================================
-- 配置区域：在此处配置你的物品和对应的 StatValue / AbilityFlag
-- ============================================================
local CONFIG = {
    -- 检查间隔（秒）
    checkInterval = 0.3,

    -- 调试模式：false=关闭, true=详细, "errors"=仅错误
    debug = false,

    -- 物品到效果的映射
    -- 支持两种类型：
    --   1️⃣ 主体（IsMain=true）：拿在手上生效
    --   2️⃣ 子体（IsSub=true）：放入任意主体的物品栏中即生效
    --
    -- stats: statType 可选值参考游戏 StatTypes 枚举：
    --   WalkingSpeed, SwimmingSpeed, MovementSpeed, PropulsionSpeed,
    --   MaximumHealthMultiplier, AttackMultiplier, DamageMultiplier,
    --   ElectricalSkillBonus, HelmSkillBonus, MechanicalSkillBonus,
    --   MedicalSkillBonus, WeaponsSkillBonus, 等等...
    --
    -- flags: 可选值参考游戏 AbilityFlags 枚举：
    --   MustWalk, ImmuneToPressure, IgnoredByEnemyAI,
    --   MoveNormallyWhileDragging, CanTinker, 等等...
    items = {
        -- ========== 主体示例 ==========
        ["deep_AK12"] = {
            IsMain = true,
            stats = {
                { statType = "WalkingSpeed", value = 1 },
            },
            flags = {
                "ImmuneToPressure",
            },
        },

        -- ========== 子体示例（通用，可放入任意主体） ==========
        ["vertical_grip"] = {
            IsSub = true,
            stats = {
                { statType = "WalkingSpeed", value = -1.5 },
            },
            flags = {
                "MoveNormallyWhileDragging",
            },
        },

        -- ========== 更多示例 ==========
        -- ["rifle_heavyduty"] = {
        --     IsMain = true,
        --     stats = {
        --         { statType = "WalkingSpeed", value = 0.5 },
        --         { statType = "AttackMultiplier", value = 0.2 },
        --     },
        --     flags = {
        --         "ImmuneToPressure",
        --         "IgnoredByEnemyAI",
        --     },
        -- },
        -- ["tactical_light"] = {
        --     IsSub = true,
        --     stats = {
        --         { statType = "SwimmingSpeed", value = 0.3 },
        --     },
        --     flags = {
        --         "IgnoredByEnemyAI",
        --     },
        -- },
    },
}

-- ============================================================
-- 内部状态
-- ============================================================

-- charState[characterID] = {
--     itemId = "deep_AK12",           -- 当前手持的主体物品ID
--     mainStats = {                    -- 主体已施加的 stat 记录
--         "WalkingSpeed" = 1, ...
--     },
--     mainFlags = {                    -- 主体已施加的 flag 记录
--         "ImmuneToPressure" = true, ...
--     },
--     subStats = {                     -- 子体已施加的 stat 记录
--         ["vertical_grip"] = { "WalkingSpeed" = 0.5, ... },
--         ...
--     },
--     subFlags = {                     -- 子体已施加的 flag 记录
--         ["vertical_grip"] = { "MoveNormallyWhileDragging" = true, ... },
--         ...
--     },
--     lastSubItems = {                 -- 上次检测到的子体列表
--         "vertical_grip" = true, ...
--     },
-- }
local charState = {}

local frameCounter = 0
local framesPerCheck = 1

-- ============================================================
-- 日志
-- ============================================================

local function dbgLog(...)
    if not CONFIG.debug then return end
    if CONFIG.debug == true then
        print("[AdjustStatvalue]", ...)
    elseif CONFIG.debug == "errors" then
        local msg = table.concat({...}, " ")
        if msg:match("ERROR") or msg:match("equip") or msg:match("unequip") or msg:match("FAIL") then
            print("[AdjustStatvalue]", ...)
        end
    end
end

-- ============================================================
-- 辅助函数
-- ============================================================

---获取角色当前手持物品的identifier列表
local function getHeldItemIds(character)
    local result = {}
    if not character then return result end

    local inv = character.Inventory
    if inv then
        local handSlots = { InvSlotType.RightHand, InvSlotType.LeftHand }
        for _, slotType in ipairs(handSlots) do
            if slotType then
                local item = inv:GetItemInLimbSlot(slotType)
                if item and item.Prefab then
                    table.insert(result, tostring(item.Prefab.Identifier))
                end
            end
        end
    end

    if #result == 0 then
        local selItem = character.SelectedItem
        if selItem and selItem.Prefab then
            table.insert(result, tostring(selItem.Prefab.Identifier))
        end
    end

    return result
end

---在手持物品列表中查找匹配配置的主体物品
local function findMainItem(heldIds)
    for _, id in ipairs(heldIds) do
        local cfg = CONFIG.items[id]
        if cfg and cfg.IsMain then
            return id
        end
    end
    return nil
end

---获取手持的主体物品对象（Item）
local function getMainItemObject(character, mainItemId)
    local inv = character.Inventory
    if not inv then return nil end

    local handSlots = { InvSlotType.RightHand, InvSlotType.LeftHand }
    for _, slotType in ipairs(handSlots) do
        if slotType then
            local item = inv:GetItemInLimbSlot(slotType)
            if item and item.Prefab and tostring(item.Prefab.Identifier) == mainItemId then
                return item
            end
        end
    end

    return nil
end

---获取所有在主体物品栏中的已配置子体列表
local function getActiveSubItems(mainItem)
    local result = {}
    if not mainItem then return result end

    local subConfigs = {}
    for itemId, cfg in pairs(CONFIG.items) do
        if cfg.IsSub then
            subConfigs[itemId] = true
        end
    end

    if not next(subConfigs) then return result end

    local ownInv = mainItem.OwnInventory
    if ownInv then
        for item in ownInv.AllItemsMod do
            if item and item.Prefab then
                local itemId = tostring(item.Prefab.Identifier)
                if subConfigs[itemId] and CONFIG.items[itemId] then
                    result[itemId] = CONFIG.items[itemId]
                end
            end
        end
    end

    if not next(result) then
        for item in mainItem.ContainedItems do
            if item and item.Prefab then
                local itemId = tostring(item.Prefab.Identifier)
                if subConfigs[itemId] and CONFIG.items[itemId] then
                    result[itemId] = CONFIG.items[itemId]
                end
            end
        end
    end

    return result
end

---对角色施加一组 StatValue，返回已施加的记录表
local function applyStats(character, stats)
    local applied = {}
    if not stats then return applied end
    for _, stat in ipairs(stats) do
        local statTypeValue = StatTypes[stat.statType]
        if statTypeValue then
            character:ChangeStat(statTypeValue, stat.value)
            applied[stat.statType] = stat.value
        end
    end
    return applied
end

---撤销角色的一组 StatValue
local function removeStats(character, statsRecord)
    if not statsRecord then return end
    for statType, value in pairs(statsRecord) do
        local statTypeValue = StatTypes[statType]
        if statTypeValue then
            character:ChangeStat(statTypeValue, -value)
        end
    end
end

---对角色施加一组 AbilityFlag，返回已施加的记录表
local function applyFlags(character, flags)
    local applied = {}
    if not flags then return applied end
    for _, flagName in ipairs(flags) do
        local flagValue = AbilityFlags[flagName]
        if flagValue then
            character:AddAbilityFlag(flagValue)
            applied[flagName] = true
        end
    end
    return applied
end

---撤销角色的一组 AbilityFlag
local function removeFlags(character, flagsRecord)
    if not flagsRecord then return end
    for flagName, _ in pairs(flagsRecord) do
        local flagValue = AbilityFlags[flagName]
        if flagValue then
            character:RemoveAbilityFlag(flagValue)
        end
    end
end

---清理角色的所有效果（stats + flags）
local function removeAllEffects(character, state)
    removeStats(character, state.mainStats)
    removeFlags(character, state.mainFlags)
    for _, subStatRecord in pairs(state.subStats or {}) do
        removeStats(character, subStatRecord)
    end
    for _, subFlagRecord in pairs(state.subFlags or {}) do
        removeFlags(character, subFlagRecord)
    end
end

---处理单个角色：检测装备变化并同步 StatValue 和 AbilityFlag（支持主从系统）
local function processCharacter(character)
    local charId = character.ID

    if character.Removed or character.IsDead then
        if charState[charId] then
            removeAllEffects(character, charState[charId])
            charState[charId] = nil
            dbgLog("cleanup removed/dead:", character.Name or charId)
        end
        return
    end

    local heldIds = getHeldItemIds(character)
    local mainItemId = findMainItem(heldIds)
    local lastState = charState[charId]

    if mainItemId then
        -- ========== 角色手持了主体物品 ==========
        local mainCfg = CONFIG.items[mainItemId]

        -- 获取主体物品的对象（用于检查子体）
        local mainItem = getMainItemObject(character, mainItemId)

        -- ========== 1️⃣ 处理主体自身的效果（一次性模式） ==========
        if not lastState or lastState.itemId ~= mainItemId then
            -- 状态改变：新装备或切换主体 → 先撤销旧的
            if lastState then
                removeAllEffects(character, lastState)
            end

            -- 施加新主体的效果
            local mainStatApplied = applyStats(character, mainCfg.stats)
            local mainFlagApplied = applyFlags(character, mainCfg.flags)

            -- 初始化状态
            charState[charId] = {
                itemId = mainItemId,
                mainStats = mainStatApplied,
                mainFlags = mainFlagApplied,
                subStats = {},
                subFlags = {},
                lastSubItems = {},
            }

            local parts = {}
            if next(mainStatApplied) then
                local s = {}
                for _, stat in ipairs(mainCfg.stats or {}) do
                    table.insert(s, stat.statType .. "=" .. stat.value)
                end
                table.insert(parts, "stats:[" .. table.concat(s, ", ") .. "]")
            end
            if next(mainFlagApplied) then
                table.insert(parts, "flags:[" .. table.concat(mainCfg.flags, ", ") .. "]")
            end
            if #parts > 0 then
                dbgLog("equip [MAIN]", character.Name or "?", "->", mainItemId, table.concat(parts, " "))
            end
        end

        -- 确保状态存在
        if not charState[charId] then
            charState[charId] = {
                itemId = mainItemId,
                mainStats = {},
                mainFlags = {},
                subStats = {},
                subFlags = {},
                lastSubItems = {},
            }
        end

        local state = charState[charId]

        -- ========== 2️⃣ 处理子体的效果（动态检测） ==========
        local currentSubItems = getActiveSubItems(mainItem)
        local lastSubItems = state.lastSubItems or {}

        -- 2.1 施加新的子体效果
        for subId, subCfg in pairs(currentSubItems) do
            if not state.subStats[subId] then
                state.subStats[subId] = applyStats(character, subCfg.stats)
                state.subFlags[subId] = applyFlags(character, subCfg.flags)

                local parts = {}
                if next(state.subStats[subId]) then
                    local s = {}
                    for _, stat in ipairs(subCfg.stats or {}) do
                        table.insert(s, stat.statType .. "=" .. stat.value)
                    end
                    table.insert(parts, "stats:[" .. table.concat(s, ", ") .. "]")
                end
                if next(state.subFlags[subId]) then
                    table.insert(parts, "flags:[" .. table.concat(subCfg.flags or {}, ", ") .. "]")
                end
                if #parts > 0 then
                    dbgLog("equip [SUB]", character.Name or "?", "->", subId, "(in", mainItemId, ")", table.concat(parts, " "))
                end
            end
        end

        -- 2.2 移除消失的子体效果
        for subId, _ in pairs(lastSubItems) do
            if not currentSubItems[subId] then
                removeStats(character, state.subStats[subId])
                removeFlags(character, state.subFlags[subId])
                state.subStats[subId] = nil
                state.subFlags[subId] = nil
                dbgLog("unequip [SUB]", character.Name or "?", "<-", subId)
            end
        end

        -- 更新上次子体列表
        state.lastSubItems = {}
        for subId, _ in pairs(currentSubItems) do
            state.lastSubItems[subId] = true
        end

    else
        -- ========== 角色没有手持任何主体物品 ==========
        if lastState then
            local removedList = {}
            if lastState.mainStats and next(lastState.mainStats) then
                for k, _ in pairs(lastState.mainStats) do
                    table.insert(removedList, "[M-s]" .. k)
                end
            end
            if lastState.mainFlags and next(lastState.mainFlags) then
                for k, _ in pairs(lastState.mainFlags) do
                    table.insert(removedList, "[M-f]" .. k)
                end
            end
            for subId, _ in pairs(lastState.subStats or {}) do
                table.insert(removedList, "[S]" .. subId)
            end

            removeAllEffects(character, lastState)
            dbgLog("unequip [ALL]", character.Name or "?", "removed:", table.concat(removedList, ", "))
            charState[charId] = nil
        end
    end
end

-- ============================================================
-- 主循环 Hook
-- ============================================================

Hook.Add("think", "AdjustStatvalue.Think", function()
    frameCounter = frameCounter + 1
    if frameCounter < framesPerCheck then return end
    frameCounter = 0

    local activeIds = {}
    for _, char in pairs(Character.CharacterList) do
        if char.ID then
            activeIds[char.ID] = true
            processCharacter(char)
        end
    end

    for id, _ in pairs(charState) do
        if not activeIds[id] then
            charState[id] = nil
        end
    end
end)

-- ============================================================
-- 角色死亡时即时清理
-- ============================================================

Hook.Add("character.death", "AdjustStatvalue.Death", function(character)
    if not character or not character.ID then return end
    local state = charState[character.ID]
    if not state then return end

    dbgLog("death cleanup:", character.Name)
    removeAllEffects(character, state)
    charState[character.ID] = nil
end)

-- ============================================================
-- 启动信息
-- ============================================================

framesPerCheck = math.max(1, math.floor(CONFIG.checkInterval * 60))

-- 环境检测
dbgLog("Character exists:", Character ~= nil)
dbgLog("StatTypes exists:", StatTypes ~= nil)
dbgLog("AbilityFlags exists:", AbilityFlags ~= nil)
dbgLog("Hook.Add exists:", Hook.Add ~= nil)

-- 统计并验证配置
local mainCount = 0
local subCount = 0
local validStatCount = 0
local invalidStatCount = 0
local validFlagCount = 0
local invalidFlagCount = 0

for itemId, cfg in pairs(CONFIG.items) do
    local parts = {}
    local allValid = true
    local itemType = ""

    if cfg.IsMain then
        itemType = "[MAIN]"
        mainCount = mainCount + 1
    elseif cfg.IsSub then
        itemType = "[SUB] (universal)"
        subCount = subCount + 1
    else
        itemType = "[?]"
    end

    -- 验证 stats
    if cfg.stats then
        local statParts = {}
        for _, stat in ipairs(cfg.stats) do
            if StatTypes and StatTypes[stat.statType] then
                table.insert(statParts, string.format("%s=%s%.2f",
                    stat.statType, stat.value >= 0 and "+" or "", stat.value))
                validStatCount = validStatCount + 1
            else
                table.insert(statParts, string.format("[FAIL]%s=%s%.2f",
                    stat.statType, stat.value >= 0 and "+" or "", stat.value))
                allValid = false
                invalidStatCount = invalidStatCount + 1
            end
        end
        if #statParts > 0 then
            table.insert(parts, "stats:[" .. table.concat(statParts, ", ") .. "]")
        end
    end

    -- 验证 flags
    if cfg.flags then
        local flagParts = {}
        for _, flagName in ipairs(cfg.flags) do
            if AbilityFlags and AbilityFlags[flagName] then
                table.insert(flagParts, flagName)
                validFlagCount = validFlagCount + 1
            else
                table.insert(flagParts, "[FAIL]" .. flagName)
                allValid = false
                invalidFlagCount = invalidFlagCount + 1
            end
        end
        if #flagParts > 0 then
            table.insert(parts, "flags:[" .. table.concat(flagParts, ", ") .. "]")
        end
    end

    local effectStr = #parts > 0 and table.concat(parts, " ") or "(none)"
end