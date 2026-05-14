-- ============================================================
-- AdjustStatvalue.lua
-- 当玩家装备(Holdable)指定物品时，直接修改玩家的 StatValue 和 AbilityFlag
-- 取消装备时自动撤销
-- ============================================================

local CONFIG = {
    checkInterval = 0.3,
    debug = false,
    items = {
        ["deep_AK12"] = {
            IsMain = true,
            stats = {
                { statType = "WalkingSpeed", value = 1 },
            },
            flags = {
                "ImmuneToPressure",
            },
        },
        ["vertical_grip"] = {
            IsSub = true,
            stats = {
                { statType = "WalkingSpeed", value = -1.5 },
            },
            flags = {
                "MoveNormallyWhileDragging",
            },
        },
    },
}

-- ============================================================
-- 模块级缓存
-- ============================================================

local subConfigCache = {}
for itemId, cfg in pairs(CONFIG.items) do
    if cfg.IsSub then
        subConfigCache[itemId] = cfg
    end
end

local HAND_SLOTS = { InvSlotType.RightHand, InvSlotType.LeftHand }

-- ============================================================
-- 日志
-- ============================================================

local dbgPrint
if not CONFIG.debug then
    dbgPrint = function() end
elseif CONFIG.debug == "errors" then
    dbgPrint = function(...)
        local msg = table.concat({...}, " ")
        if msg:match("ERROR") or msg:match("equip") or msg:match("unequip") or msg:match("FAIL") then
            print("[AdjustStatvalue]", ...)
        end
    end
else
    dbgPrint = function(...)
        print("[AdjustStatvalue]", ...)
    end
end

-- ============================================================
-- 辅助函数
-- ============================================================

local function getHeldItemInfo(character)
    local ids = {}
    local itemMap = {}
    if not character then return ids, itemMap end

    local inv = character.Inventory
    if inv then
        for _, slotType in ipairs(HAND_SLOTS) do
            local item = inv:GetItemInLimbSlot(slotType)
            if item and item.Prefab then
                local id = tostring(item.Prefab.Identifier)
                ids[#ids + 1] = id
                itemMap[id] = item
            end
        end
    end

    if #ids == 0 then
        local selItem = character.SelectedItem
        if selItem and selItem.Prefab then
            local id = tostring(selItem.Prefab.Identifier)
            ids[#ids + 1] = id
            itemMap[id] = selItem
        end
    end

    return ids, itemMap
end

local function findMainItem(heldIds)
    for _, id in ipairs(heldIds) do
        local cfg = CONFIG.items[id]
        if cfg and cfg.IsMain then
            return id
        end
    end
    return nil
end

local function getActiveSubItems(mainItem)
    local result = {}
    if not mainItem or not next(subConfigCache) then return result end

    local ownInv = mainItem.OwnInventory
    if ownInv then
        for item in ownInv.AllItemsMod do
            if item and item.Prefab then
                local cfg = subConfigCache[tostring(item.Prefab.Identifier)]
                if cfg then
                    result[tostring(item.Prefab.Identifier)] = cfg
                end
            end
        end
    end

    if not next(result) then
        for item in mainItem.ContainedItems do
            if item and item.Prefab then
                local cfg = subConfigCache[tostring(item.Prefab.Identifier)]
                if cfg then
                    result[tostring(item.Prefab.Identifier)] = cfg
                end
            end
        end
    end

    return result
end

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

local function removeStats(character, statsRecord)
    if not statsRecord then return end
    for statType, value in pairs(statsRecord) do
        local statTypeValue = StatTypes[statType]
        if statTypeValue then
            character:ChangeStat(statTypeValue, -value)
        end
    end
end

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

local function removeFlags(character, flagsRecord)
    if not flagsRecord then return end
    for flagName, _ in pairs(flagsRecord) do
        local flagValue = AbilityFlags[flagName]
        if flagValue then
            character:RemoveAbilityFlag(flagValue)
        end
    end
end

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

local charState = {}

local function processCharacter(character)
    local charId = character.ID

    if character.Removed or character.IsDead then
        if charState[charId] then
            removeAllEffects(character, charState[charId])
            charState[charId] = nil
            dbgPrint("cleanup removed/dead:", character.Name or charId)
        end
        return
    end

    local heldIds, itemMap = getHeldItemInfo(character)
    local mainItemId = findMainItem(heldIds)
    local lastState = charState[charId]

    if mainItemId then
        local mainCfg = CONFIG.items[mainItemId]
        local mainItem = itemMap[mainItemId]

        if not lastState or lastState.itemId ~= mainItemId then
            if lastState then
                removeAllEffects(character, lastState)
            end

            local mainStatApplied = applyStats(character, mainCfg.stats)
            local mainFlagApplied = applyFlags(character, mainCfg.flags)

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
                    s[#s + 1] = stat.statType .. "=" .. stat.value
                end
                parts[#parts + 1] = "stats:[" .. table.concat(s, ", ") .. "]"
            end
            if next(mainFlagApplied) then
                parts[#parts + 1] = "flags:[" .. table.concat(mainCfg.flags or {}, ", ") .. "]"
            end
            if #parts > 0 then
                dbgPrint("equip [MAIN]", character.Name or "?", "->", mainItemId, table.concat(parts, " "))
            end
        end

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
        local currentSubItems = getActiveSubItems(mainItem)
        local lastSubItems = state.lastSubItems or {}

        for subId, subCfg in pairs(currentSubItems) do
            if not state.subStats[subId] then
                state.subStats[subId] = applyStats(character, subCfg.stats)
                state.subFlags[subId] = applyFlags(character, subCfg.flags)

                local parts = {}
                if next(state.subStats[subId]) then
                    local s = {}
                    for _, stat in ipairs(subCfg.stats or {}) do
                        s[#s + 1] = stat.statType .. "=" .. stat.value
                    end
                    parts[#parts + 1] = "stats:[" .. table.concat(s, ", ") .. "]"
                end
                if next(state.subFlags[subId]) then
                    parts[#parts + 1] = "flags:[" .. table.concat(subCfg.flags or {}, ", ") .. "]"
                end
                if #parts > 0 then
                    dbgPrint("equip [SUB]", character.Name or "?", "->", subId, "(in", mainItemId, ")", table.concat(parts, " "))
                end
            end
        end

        for subId, _ in pairs(lastSubItems) do
            if not currentSubItems[subId] then
                removeStats(character, state.subStats[subId])
                removeFlags(character, state.subFlags[subId])
                state.subStats[subId] = nil
                state.subFlags[subId] = nil
                dbgPrint("unequip [SUB]", character.Name or "?", "<-", subId)
            end
        end

        state.lastSubItems = {}
        for subId, _ in pairs(currentSubItems) do
            state.lastSubItems[subId] = true
        end

    else
        if lastState then
            removeAllEffects(character, lastState)
            dbgPrint("unequip [ALL]", character.Name or "?")
            charState[charId] = nil
        end
    end
end

-- ============================================================
-- 主循环 Hook
-- ============================================================

local frameCounter = 0
local framesPerCheck = math.max(1, math.floor(CONFIG.checkInterval * 60))

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
    dbgPrint("death cleanup:", character.Name)
    removeAllEffects(character, state)
    charState[character.ID] = nil
end)

-- ============================================================
-- 启动验证
-- ============================================================

local mainCount, subCount = 0, 0
local validStats, invalidStats = 0, 0
local validFlags, invalidFlags = 0, 0

for itemId, cfg in pairs(CONFIG.items) do
    if cfg.IsMain then
        mainCount = mainCount + 1
    elseif cfg.IsSub then
        subCount = subCount + 1
    end

    if cfg.stats then
        for _, stat in ipairs(cfg.stats) do
            if StatTypes and StatTypes[stat.statType] then
                validStats = validStats + 1
            else
                invalidStats = invalidStats + 1
            end
        end
    end

    if cfg.flags then
        for _, flagName in ipairs(cfg.flags) do
            if AbilityFlags and AbilityFlags[flagName] then
                validFlags = validFlags + 1
            else
                invalidFlags = invalidFlags + 1
            end
        end
    end
end