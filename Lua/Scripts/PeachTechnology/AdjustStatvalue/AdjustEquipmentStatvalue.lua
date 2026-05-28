-- ============================================================
-- AdjustEquipmentStatvalue.lua
-- 当玩家穿上(Wearable)指定装备时，直接修改玩家的 StatValue 和 AbilityFlag
-- 取消装备时自动撤销
-- 支持 IsMain（主体装备）和 IsSub（主体装备内的子配件）
-- 主体装备：使用 item.equip/item.unequip 事件驱动（零轮询）
-- 子配件：使用轻量 think 仅扫描已跟踪角色的主物品库存
-- affliction 配置项：equip 时施加指定 Affliction，unequip 时移除
--   affliction = { id = "affliction_identifier", strength = 1.0 }
-- 配置位于 AdjustEquipmentStatvalue-Config.lua



-- 主要目的，将甲鱼的StatusEffect——Affliction——StatValue的流程，简化为Lua脚本直接修改 StatValue，减少不必要的性能损失
-- 有些功能必须要用Affliction，比如护甲升级的效果，设置护甲升级芯片的Affliction的strengthchange=0，做到最小的性能损失
-- 移除xml代码中的StatusEffect，将脉冲周期施加Affliction的方法彻底移除



-- ============================================================

local CONFIG = _G.AdjustEquipmentConfig
if not CONFIG then
    error("[AdjustEquipmentStatvalue] AdjustEquipmentConfig not found. Did you forget to load AdjustEquipmentStatvalue-Config.lua?")
end

local subConfigCache = _G.AdjustEquipmentSubConfigCache or {}
local WEARABLE_SLOTS = _G.AdjustEquipmentWearableSlots or {
    InvSlotType.Head,
    InvSlotType.InnerClothes,
    InvSlotType.OuterClothes,
    InvSlotType.Headset,
    InvSlotType.Card,
    InvSlotType.Bag,
}

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
            print("[AdjustEquipmentStatvalue]", ...)
        end
    end
else
    dbgPrint = function(...)
        print("[AdjustEquipmentStatvalue]", ...)
    end
end

-- ============================================================
-- 辅助函数
-- ============================================================

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
        else
            dbgPrint("WARN: invalid statType:", stat.statType)
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
        else
            dbgPrint("WARN: invalid flagName:", flagName)
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

local function applyAfflictionItem(character, afflictionCfg)
    if not afflictionCfg or not afflictionCfg.id then return nil end
    local prefab = AfflictionPrefab.Prefabs[afflictionCfg.id]
    if not prefab then
        dbgPrint("ERROR: affliction prefab not found:", afflictionCfg.id)
        return nil
    end
    local strength = afflictionCfg.strength or 1
    local instance = prefab:Instantiate(strength)

    local headLimb = nil
    if character.AnimController then
        for _, limb in pairs(character.AnimController.Limbs) do
            if limb.type == LimbType.Head then
                headLimb = limb
                break
            end
        end
    end

    character.CharacterHealth:ApplyAffliction(headLimb, instance)
    dbgPrint("affliction applied:", afflictionCfg.id, "strength=" .. strength)
    return { id = afflictionCfg.id, strength = strength }
end

local function removeAfflictionItem(character, afflictionInfo)
    if not afflictionInfo or not afflictionInfo.id then return end
    character.CharacterHealth:ReduceAfflictionOnAllLimbs(afflictionInfo.id, afflictionInfo.strength or 999)
    dbgPrint("affliction removed:", afflictionInfo.id)
end

local function removeAllEffects(character, state)
    removeStats(character, state.mainStats)
    removeFlags(character, state.mainFlags)
    removeAfflictionItem(character, state.mainAffliction)
    for _, subStatRecord in pairs(state.subStats or {}) do
        removeStats(character, subStatRecord)
    end
    for _, subFlagRecord in pairs(state.subFlags or {}) do
        removeFlags(character, subFlagRecord)
    end
    for _, subAffliction in pairs(state.subAfflictions or {}) do
        removeAfflictionItem(character, subAffliction)
    end
end

local function isItemStillEquipped(character, item)
    if not character or not character.Inventory then return false end
    for _, slotType in ipairs(WEARABLE_SLOTS) do
        if character.Inventory:GetItemInLimbSlot(slotType) == item then
            return true
        end
    end
    return false
end

local function logMainEquip(character, itemId, mainCfg, mainStatApplied, mainFlagApplied, currentSubItems)
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
    local subInfo = ""
    if next(currentSubItems) then
        local subNames = {}
        for subId, _ in pairs(currentSubItems) do
            subNames[#subNames + 1] = subId
        end
        subInfo = " subs:[" .. table.concat(subNames, ", ") .. "]"
    end
    if #parts > 0 or #subInfo > 0 then
        dbgPrint("equip [MAIN]", character.Name or "?", "->", itemId, table.concat(parts, " ") .. subInfo)
    end
end

local function logSubEquip(charName, subId, mainItemId, subCfg, subStatApplied, subFlagApplied)
    local parts = {}
    if next(subStatApplied or {}) then
        local s = {}
        for _, stat in ipairs(subCfg.stats or {}) do
            s[#s + 1] = stat.statType .. "=" .. stat.value
        end
        parts[#parts + 1] = "stats:[" .. table.concat(s, ", ") .. "]"
    end
    if next(subFlagApplied or {}) then
        parts[#parts + 1] = "flags:[" .. table.concat(subCfg.flags or {}, ", ") .. "]"
    end
    if #parts > 0 then
        dbgPrint("equip [SUB]", charName or "?", "->", subId, "(in", mainItemId, ")", table.concat(parts, " "))
    end
end

-- ============================================================
-- charState
-- ============================================================

local charState = {}

-- ============================================================
-- 核心装备处理
-- ============================================================

local function equipMainItem(character, item)
    if not item or not item.Prefab then return end
    local itemId = tostring(item.Prefab.Identifier)
    local cfg = CONFIG.items[itemId]
    if not cfg or not cfg.IsMain then return end

    local lastState = charState[character.ID]
    if lastState and lastState.mainItem == item then
        return
    end

    if lastState then
        removeAllEffects(character, lastState)
        dbgPrint("unequip [ALL] (replaced)", character.Name or "?")
    end

    local mainStatApplied = applyStats(character, cfg.stats)
    local mainFlagApplied = applyFlags(character, cfg.flags)
    local mainAffliction = applyAfflictionItem(character, cfg.affliction)

    local state = {
        itemId = itemId,
        mainItem = item,
        character = character,
        mainStats = mainStatApplied,
        mainFlags = mainFlagApplied,
        mainAffliction = mainAffliction,
        subStats = {},
        subFlags = {},
        subAfflictions = {},
        lastSubItems = {},
    }
    charState[character.ID] = state

    local currentSubItems = getActiveSubItems(item)
    for subId, subCfg in pairs(currentSubItems) do
        state.subStats[subId] = applyStats(character, subCfg.stats)
        state.subFlags[subId] = applyFlags(character, subCfg.flags)
        state.subAfflictions[subId] = applyAfflictionItem(character, subCfg.affliction)
        state.lastSubItems[subId] = true
        logSubEquip(character.Name, subId, itemId, subCfg, state.subStats[subId], state.subFlags[subId])
    end

    logMainEquip(character, itemId, cfg, mainStatApplied, mainFlagApplied, currentSubItems)
end

-- ============================================================
-- item.equip 事件：主体装备装上时触发
-- ============================================================

Hook.Add("item.equip", "AdjustEquipmentStatvalue.Equip", function(item, character)
    if not character or not character.ID or character.Removed or character.IsDead then return end
    equipMainItem(character, item)
end)

-- ============================================================
-- item.unequip 事件：主体装备卸下时触发
-- ============================================================

Hook.Add("item.unequip", "AdjustEquipmentStatvalue.Unequip", function(item, character)
    if not item or not item.Prefab then return end
    if not character or not character.ID then return end

    local itemId = tostring(item.Prefab.Identifier)
    local cfg = CONFIG.items[itemId]
    if not cfg or not cfg.IsMain then return end

    local state = charState[character.ID]
    if not state or state.itemId ~= itemId or state.mainItem ~= item then return end

    removeAllEffects(character, state)
    charState[character.ID] = nil
    dbgPrint("unequip [ALL]", character.Name or "?")
end)

-- ============================================================
-- 角色死亡时：撤销 stats/flags，保留 state 以检测 revive
-- affliction 不手动清除（会被 revive 的 RemoveAllAfflictions 清空）
-- ============================================================

Hook.Add("character.death", "AdjustEquipmentStatvalue.Death", function(character)
    if not character or not character.ID then return end
    local state = charState[character.ID]
    if not state then return end
    dbgPrint("death cleanup:", character.Name)
    removeStats(character, state.mainStats)
    removeFlags(character, state.mainFlags)
    for _, subStatRecord in pairs(state.subStats or {}) do
        removeStats(character, subStatRecord)
    end
    for _, subFlagRecord in pairs(state.subFlags or {}) do
        removeFlags(character, subFlagRecord)
    end
    state.dead = true
end)

-- ============================================================
-- 初始扫描：处理脚本加载时已装备的物品
-- ============================================================

local function scanExistingCharacters()
    for _, char in pairs(Character.CharacterList) do
        if char.ID and not char.Removed and not char.IsDead then
            local inv = char.Inventory
            if inv then
                for _, slotType in ipairs(WEARABLE_SLOTS) do
                    local item = inv:GetItemInLimbSlot(slotType)
                    if item and item.Prefab then
                        local id = tostring(item.Prefab.Identifier)
                        local cfg = CONFIG.items[id]
                        if cfg and cfg.IsMain then
                            equipMainItem(char, item)
                        end
                    end
                end
            end
        end
    end
end

Hook.Add("loaded", "AdjustEquipmentStatvalue.Loaded", function()
    scanExistingCharacters()
end)

Hook.Add("roundStart", "AdjustEquipmentStatvalue.RoundStart", function()
    scanExistingCharacters()
end)

-- ============================================================
-- 轻量 think：仅扫描已跟踪角色的子配件变化
-- 不再遍历 Character.CharacterList，只遍历 charState（通常 0~少数人）
-- ============================================================

local frameCounter = 0
local framesPerCheck = math.max(1, math.floor(CONFIG.checkInterval * 60))

Hook.Add("think", "AdjustEquipmentStatvalue.Think", function()
    frameCounter = frameCounter + 1
    if frameCounter < framesPerCheck then return end
    frameCounter = 0

    for charId, state in pairs(charState) do
        local character = state.character

        -- revive 检测：角色死亡后复活，延迟 0.5s 重新施加效果
        if state.dead then
            if not character or character.Removed then
                charState[charId] = nil
            elseif not character.IsDead then
                state.reviveTimer = (state.reviveTimer or 0) + CONFIG.checkInterval
                if state.reviveTimer >= 0.5 then
                    local mainCfg = CONFIG.items[state.itemId]
                    if mainCfg then
                        state.mainStats = applyStats(character, mainCfg.stats)
                        state.mainFlags = applyFlags(character, mainCfg.flags)
                        state.mainAffliction = applyAfflictionItem(character, mainCfg.affliction)
                    end

                    local mainItem = state.mainItem
                    if mainItem and not mainItem.Removed and isItemStillEquipped(character, mainItem) then
                        local currentSubItems = getActiveSubItems(mainItem)
                        for subId, subCfg in pairs(currentSubItems) do
                            state.subStats[subId] = applyStats(character, subCfg.stats)
                            state.subFlags[subId] = applyFlags(character, subCfg.flags)
                            state.subAfflictions[subId] = applyAfflictionItem(character, subCfg.affliction)
                            state.lastSubItems[subId] = true
                        end
                    end

                    state.dead = nil
                    state.reviveTimer = nil
                    dbgPrint("revive re-apply:", character.Name)
                end
            end
        elseif not character or character.Removed or character.IsDead then
            if character then
                removeAllEffects(character, state)
            end
            charState[charId] = nil
        else
            local mainItem = state.mainItem
            if not mainItem or mainItem.Removed or not isItemStillEquipped(character, mainItem) then
                removeAllEffects(character, state)
                charState[charId] = nil
            else
                local currentSubItems = getActiveSubItems(mainItem)
                local lastSubItems = state.lastSubItems or {}

                for subId, subCfg in pairs(currentSubItems) do
                    if not state.subStats[subId] then
                        state.subStats[subId] = applyStats(character, subCfg.stats)
                        state.subFlags[subId] = applyFlags(character, subCfg.flags)
                        state.subAfflictions[subId] = applyAfflictionItem(character, subCfg.affliction)
                        logSubEquip(character.Name, subId, state.itemId, subCfg, state.subStats[subId], state.subFlags[subId])
                    end
                end

                for subId, _ in pairs(lastSubItems) do
                    if not currentSubItems[subId] then
                        removeStats(character, state.subStats[subId])
                        removeFlags(character, state.subFlags[subId])
                        removeAfflictionItem(character, state.subAfflictions[subId])
                        state.subStats[subId] = nil
                        state.subFlags[subId] = nil
                        state.subAfflictions[subId] = nil
                        dbgPrint("unequip [SUB]", character.Name or "?", "<-", subId)
                    end
                end

                state.lastSubItems = {}
                for subId, _ in pairs(currentSubItems) do
                    state.lastSubItems[subId] = true
                end
            end
        end
    end
end)