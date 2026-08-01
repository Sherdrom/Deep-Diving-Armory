-- XML OnWearing -> event-driven equipment effects.
-- Main items, contained modules and revives use events; think is fallback-only.

if not _G.AdjustEquipmentConfig then
    dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua")
end
local CONFIG = _G.AdjustEquipmentConfig

local MAIN_CONFIG = CONFIG.mainItems or {}
local SUB_CONFIG = CONFIG.subItems or {}
local fallbackInterval = CONFIG.fallbackInterval or 5.0
local RESISTANCE_SOURCE = Identifier("dda_adjust_equipment")
local resistanceKeys = {}
local talentMarkerIds = {}
for _, configs in ipairs({ MAIN_CONFIG, SUB_CONFIG }) do
    for _, cfg in pairs(configs) do
        for _, id in ipairs(cfg.talentMarkers or {}) do
            if type(id) == "string" and id ~= "" then talentMarkerIds[id] = Identifier(id) end
        end
    end
end
local WEARABLE_SLOTS = CONFIG.wearableSlots or {
    InvSlotType.Head,
    InvSlotType.InnerClothes,
    InvSlotType.OuterClothes,
    InvSlotType.Headset,
    InvSlotType.Card,
    InvSlotType.Bag,
}

local function log(...)
    if CONFIG.debug then print("[AdjustEquipmentStatvalue]", ...) end
end

local function warn(...)
    print("[AdjustEquipmentStatvalue] ERROR:", ...)
end

local function afflictionList(value)
    if not value then return {} end
    if value.id then return { value } end
    return value
end

local function validateItemConfigs(configs)
    for itemId, cfg in pairs(configs) do
        if ItemPrefab and not ItemPrefab.GetItemPrefab(itemId) then
            warn("item prefab not found", itemId)
        end
        for _, stat in ipairs(cfg.stats or {}) do
            if not StatTypes[stat.statType] then
                warn("invalid StatType", itemId, tostring(stat.statType))
            elseif type(stat.value) ~= "number" then
                warn("invalid stat value", itemId, tostring(stat.statType))
            end
        end
        if cfg.statGroup ~= nil and (type(cfg.statGroup) ~= "string" or cfg.statGroup == "") then
            warn("invalid stat group", itemId, tostring(cfg.statGroup))
        end
        for _, group in ipairs(cfg.blocksStatGroups or {}) do
            if type(group) ~= "string" or group == "" then
                warn("invalid blocked stat group", itemId, tostring(group))
            end
        end
        for _, flagName in ipairs(cfg.flags or {}) do
            if not AbilityFlags[flagName] then
                warn("invalid AbilityFlag", itemId, tostring(flagName))
            end
        end
        for _, marker in ipairs(cfg.talentMarkers or {}) do
            if type(marker) ~= "string" or marker == "" then
                warn("invalid talent marker", itemId, tostring(marker))
            end
        end
        for _, resistance in ipairs(cfg.resistances or {}) do
            if type(resistance.id) ~= "string" or resistance.id == "" then
                warn("invalid resistance identifier", itemId, tostring(resistance.id))
            elseif type(resistance.multiplier) ~= "number" or resistance.multiplier < 0 then
                warn("invalid resistance multiplier", itemId, tostring(resistance.id))
            end
        end
        for _, affliction in ipairs(afflictionList(cfg.affliction)) do
            if not affliction.id or not AfflictionPrefab.Prefabs[affliction.id] then
                warn("invalid Affliction", itemId, tostring(affliction.id))
            end
        end
    end
end

local function validateConfig()
    validateItemConfigs(MAIN_CONFIG)
    validateItemConfigs(SUB_CONFIG)
    for itemId in pairs(MAIN_CONFIG) do
        if SUB_CONFIG[itemId] then warn("item configured as both main and sub", itemId) end
    end
end

local function getMainConfig(item)
    if not item or item.Removed or not item.Prefab then return nil end
    local itemId = tostring(item.Prefab.Identifier)
    local cfg = MAIN_CONFIG[itemId]
    if not cfg then return nil end
    return cfg, itemId
end

local function applyStats(character, stats)
    local applied = {}
    for _, stat in ipairs(stats or {}) do
        local statType = StatTypes[stat.statType]
        if statType and type(stat.value) == "number" then
            character:ChangeStat(statType, stat.value)
            applied[#applied + 1] = { statType = statType, value = stat.value }
        end
    end
    return applied
end

local function removeStats(character, applied)
    for _, stat in ipairs(applied or {}) do
        character:ChangeStat(stat.statType, -stat.value)
    end
end

local function eachActiveEffects(state, callback)
    for _, source in pairs(state.mains) do
        callback(source.effects)
        for _, sub in pairs(source.subs) do callback(sub.effects) end
    end
end

local function refreshStats(state)
    local blocked = {}
    eachActiveEffects(state, function(effects)
        for _, group in ipairs(effects.cfg.blocksStatGroups or {}) do blocked[group] = true end
    end)
    eachActiveEffects(state, function(effects)
        local shouldApply = not blocked[effects.cfg.statGroup]
        if shouldApply and not effects.statsApplied then
            effects.stats = applyStats(state.character, effects.cfg.stats)
            effects.statsApplied = true
        elseif not shouldApply and effects.statsApplied then
            removeStats(state.character, effects.stats)
            effects.stats = {}
            effects.statsApplied = false
        end
    end)
end

local function acquireFlags(state, flags)
    local applied = {}
    for _, flagName in ipairs(flags or {}) do
        local flag = AbilityFlags[flagName]
        if flag then
            local ref = state.flagRefs[flagName]
            if not ref then
                ref = { count = 0, owned = not state.character:HasAbilityFlag(flag), value = flag }
                state.flagRefs[flagName] = ref
                if ref.owned then state.character:AddAbilityFlag(flag) end
            end
            ref.count = ref.count + 1
            applied[#applied + 1] = flagName
        end
    end
    return applied
end

local function releaseFlags(state, applied)
    for _, flagName in ipairs(applied or {}) do
        local ref = state.flagRefs[flagName]
        if ref then
            ref.count = ref.count - 1
            if ref.count <= 0 then
                if ref.owned then state.character:RemoveAbilityFlag(ref.value) end
                state.flagRefs[flagName] = nil
            end
        end
    end
end

local function acquireTalentMarkers(state, configured)
    local applied = {}
    local info = state.character.Info
    if not info then return applied end
    for _, id in ipairs(configured or {}) do
        if type(id) == "string" and id ~= "" then
            local ref = state.talentMarkerRefs[id]
            if not ref then
                local identifier = talentMarkerIds[id] or Identifier(id)
                ref = { count = 0, identifier = identifier }
                state.talentMarkerRefs[id] = ref
                info:ChangeSavedStatValue(StatTypes.None, 1, identifier, true, 1, true)
            end
            ref.count = ref.count + 1
            applied[#applied + 1] = id
        end
    end
    return applied
end

local function releaseTalentMarkers(state, applied)
    local info = state.character.Info
    for _, id in ipairs(applied or {}) do
        local ref = state.talentMarkerRefs[id]
        if ref then
            ref.count = ref.count - 1
            if ref.count <= 0 then
                if info then info:ChangeSavedStatValue(StatTypes.None, 0, ref.identifier, true, 1, true) end
                state.talentMarkerRefs[id] = nil
            end
        end
    end
end

local function resistanceKey(id)
    local key = resistanceKeys[id]
    if not key then
        key = CS.Barotrauma.TalentResistanceIdentifier(Identifier(id), RESISTANCE_SOURCE)
        resistanceKeys[id] = key
    end
    return key
end

local function acquireResistances(state, configured)
    local applied = {}
    for _, cfg in ipairs(configured or {}) do
        if type(cfg.id) == "string" and type(cfg.multiplier) == "number" and cfg.multiplier >= 0 then
            local ref = state.resistanceRefs[cfg.id]
            if not ref then
                ref = { count = 0, key = resistanceKey(cfg.id), multiplier = cfg.multiplier }
                state.resistanceRefs[cfg.id] = ref
                state.character:ChangeAbilityResistance(ref.key, ref.multiplier)
            elseif ref.multiplier ~= cfg.multiplier then
                warn("conflicting resistance multiplier", cfg.id, tostring(cfg.multiplier))
            end
            ref.count = ref.count + 1
            applied[#applied + 1] = cfg.id
        end
    end
    return applied
end

local function releaseResistances(state, applied)
    for _, id in ipairs(applied or {}) do
        local ref = state.resistanceRefs[id]
        if ref then
            ref.count = ref.count - 1
            if ref.count <= 0 then
                state.character:RemoveAbilityResistance(ref.key)
                state.resistanceRefs[id] = nil
            end
        end
    end
end

local function acquireAfflictions(state, configured)
    local applied = {}
    local character = state.character
    local health = character.CharacterHealth
    if not health then return applied end

    local head = character.AnimController and character.AnimController:GetLimb(LimbType.Head) or nil
    for _, cfg in ipairs(afflictionList(configured)) do
        local prefab = cfg.id and AfflictionPrefab.Prefabs[cfg.id]
        if prefab then
            local ref = state.afflictionRefs[cfg.id]
            if not ref then
                local before = health:GetAfflictionStrengthByIdentifier(cfg.id)
                health:ApplyAffliction(head, prefab:Instantiate(cfg.strength or 1))
                local instance = health:GetAffliction(cfg.id, true)
                if instance then instance.Strength = before + (cfg.strength or 1) end
                local after = health:GetAfflictionStrengthByIdentifier(cfg.id)
                local refreshDuration = prefab.Duration > 0 and fallbackInterval * 2 or nil
                if instance and refreshDuration then instance.Duration = refreshDuration end
                ref = {
                    count = 0,
                    amount = math.max(0, after - before),
                    target = after,
                    prefabDuration = prefab.Duration,
                    refreshDuration = refreshDuration,
                }
                state.afflictionRefs[cfg.id] = ref
            end
            ref.count = ref.count + 1
            applied[#applied + 1] = cfg.id
        end
    end
    return applied
end

local function releaseAfflictions(state, applied)
    local health = state.character.CharacterHealth
    if not health then return end
    for _, id in ipairs(applied or {}) do
        local ref = state.afflictionRefs[id]
        if ref then
            ref.count = ref.count - 1
            if ref.count <= 0 then
                if ref.refreshDuration then
                    local instance = health:GetAffliction(id, true)
                    if instance then instance.Duration = ref.prefabDuration end
                end
                if ref.amount > 0 then health:ReduceAfflictionOnAllLimbs(id, ref.amount) end
                state.afflictionRefs[id] = nil
            end
        end
    end
end

local function refreshAfflictions(state)
    local health = state.character.CharacterHealth
    if not health then return end
    local head = state.character.AnimController and state.character.AnimController:GetLimb(LimbType.Head) or nil
    for id, ref in pairs(state.afflictionRefs) do
        local instance = health:GetAffliction(id, true)
        if not instance then
            local prefab = AfflictionPrefab.Prefabs[id]
            if prefab then
                health:ApplyAffliction(head, prefab:Instantiate(ref.target))
                instance = health:GetAffliction(id, true)
            end
        end
        if instance then
            if instance.Strength < ref.target then instance.Strength = ref.target end
            if ref.refreshDuration then instance.Duration = ref.refreshDuration end
        end
    end
end

local function applyEffects(state, cfg)
    return {
        cfg = cfg,
        stats = applyStats(state.character, cfg.stats),
        statsApplied = true,
        flags = acquireFlags(state, cfg.flags),
        talentMarkers = acquireTalentMarkers(state, cfg.talentMarkers),
        resistances = acquireResistances(state, cfg.resistances),
        afflictions = acquireAfflictions(state, cfg.affliction),
    }
end

local function removeEffects(state, effects)
    if not effects then return end
    if effects.statsApplied then removeStats(state.character, effects.stats) end
    releaseFlags(state, effects.flags)
    releaseTalentMarkers(state, effects.talentMarkers)
    releaseResistances(state, effects.resistances)
    releaseAfflictions(state, effects.afflictions)
end

local function activeSubItems(mainItem)
    local result = {}
    local inventory = mainItem.OwnInventory
    if inventory and inventory.AllItemsMod then
        for item in inventory.AllItemsMod do
            if item and not item.Removed and item.Prefab then
                local itemId = tostring(item.Prefab.Identifier)
                local cfg = SUB_CONFIG[itemId]
                if cfg then result[item] = { cfg = cfg, itemId = itemId } end
            end
        end
    elseif mainItem.ContainedItems then
        for item in mainItem.ContainedItems do
            if item and not item.Removed and item.Prefab then
                local itemId = tostring(item.Prefab.Identifier)
                local cfg = SUB_CONFIG[itemId]
                if cfg then result[item] = { cfg = cfg, itemId = itemId } end
            end
        end
    end
    return result
end

local function syncSubItems(state, source)
    local current = activeSubItems(source.item)
    for item, data in pairs(current) do
        if not source.subs[item] then
            source.subs[item] = { itemId = data.itemId, effects = applyEffects(state, data.cfg) }
            log("equip sub", data.itemId, "in", source.itemId)
        end
    end
    for item, sub in pairs(source.subs) do
        if not current[item] then
            removeEffects(state, sub.effects)
            source.subs[item] = nil
            log("unequip sub", sub.itemId, "from", source.itemId)
        end
    end
    refreshStats(state)
end

local charStates = {}

local function syncChangedContainer(container)
    local mainItem = container and container.Item
    local character = mainItem and mainItem:GetRootInventoryOwner()
    local state = character and charStates[character]
    local source = state and state.mains[mainItem]
    if source then syncSubItems(state, source) end
end

local function ensureState(character)
    local state = charStates[character]
    if not state then
        state = {
            character = character,
            mains = {},
            flagRefs = {},
            talentMarkerRefs = {},
            resistanceRefs = {},
            afflictionRefs = {},
        }
        charStates[character] = state
    end
    return state
end

local function isStillEquipped(character, item)
    if not character or not character.Inventory then return false end
    for _, slot in ipairs(WEARABLE_SLOTS) do
        if character.Inventory:GetItemInLimbSlot(slot) == item then return true end
    end
    return false
end

local function addMain(character, item)
    if not character or character.Removed or character.IsDead then return end
    local cfg, itemId = getMainConfig(item)
    if not cfg then return end

    local state = ensureState(character)
    if state.mains[item] then return end

    local source = {
        item = item,
        itemId = itemId,
        effects = applyEffects(state, cfg),
        subs = {},
    }
    state.mains[item] = source
    syncSubItems(state, source)
    log("equip main", character.Name or "?", itemId)
end

local function removeMain(state, item)
    local source = state.mains[item]
    if not source then return end
    for _, sub in pairs(source.subs) do removeEffects(state, sub.effects) end
    removeEffects(state, source.effects)
    state.mains[item] = nil
    refreshStats(state)
    log("unequip main", state.character.Name or "?", source.itemId)
end

local function clearState(state)
    for item in pairs(state.mains) do removeMain(state, item) end
end

local function removeEmptyState(state)
    if not state.dead and not next(state.mains) then charStates[state.character] = nil end
end

local function resetTalentMarkers(character)
    local info = character and character.Info
    if not info then return end
    for _, identifier in pairs(talentMarkerIds) do
        if info:GetSavedStatValue(StatTypes.None, identifier) ~= 0 then
            info:ChangeSavedStatValue(StatTypes.None, 0, identifier, true, 1, true)
        end
    end
end

local function scanCharacter(character)
    if not character or character.Removed or character.IsDead then return end
    resetTalentMarkers(character)
    if not character.Inventory then return end
    for _, slot in ipairs(WEARABLE_SLOTS) do
        addMain(character, character.Inventory:GetItemInLimbSlot(slot))
    end
end

local function scanAllCharacters()
    for _, character in pairs(Character.CharacterList) do scanCharacter(character) end
end

local function restoreRevivedCharacter(character)
    if not character or character.Removed or character.IsDead then return end
    local state = charStates[character]
    if state then state.dead = nil end
    scanCharacter(character)
    state = charStates[character]
    if state then removeEmptyState(state) end
end

local function clearAllStates()
    for _, state in pairs(charStates) do
        if state.character and not state.character.Removed then clearState(state) end
    end
    charStates = {}
end

Hook.Patch(
    "AdjustEquipmentStatvalue.Equip",
    "Barotrauma.Item",
    "Equip",
    { "Barotrauma.Character" },
    function(item, ptable) addMain(ptable["character"], item) end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.Unequip",
    "Barotrauma.Items.Components.Wearable",
    "Unequip",
    { "Barotrauma.Character" },
    function(wearable, ptable)
        local character = ptable["character"]
        local state = character and charStates[character]
        if state then
            removeMain(state, wearable.Item)
            removeEmptyState(state)
        end
    end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.ItemContained",
    "Barotrauma.Items.Components.ItemContainer",
    "OnItemContained",
    { "Barotrauma.Item", "System.Boolean" },
    syncChangedContainer,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.ItemRemovedFromContainer",
    "Barotrauma.Items.Components.ItemContainer",
    "OnItemRemoved",
    { "Barotrauma.Item" },
    syncChangedContainer,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.Revive",
    "Barotrauma.Character",
    "Revive",
    { "System.Boolean", "System.Boolean" },
    restoreRevivedCharacter,
    Hook.HookMethodType.After
)

Hook.Add("item.removed", "AdjustEquipmentStatvalue.ItemRemoved", function(item)
    for _, state in pairs(charStates) do
        if state.mains[item] then
            removeMain(state, item)
            removeEmptyState(state)
        else
            local changed = false
            for _, source in pairs(state.mains) do
                local sub = source.subs[item]
                if sub then
                    removeEffects(state, sub.effects)
                    source.subs[item] = nil
                    changed = true
                end
            end
            if changed then refreshStats(state) end
        end
    end
end)

Hook.Add("character.death", "AdjustEquipmentStatvalue.Death", function(character)
    local state = charStates[character]
    if not state then return end
    clearState(state)
    state.dead = true
end)

Hook.Add("character.created", "AdjustEquipmentStatvalue.CharacterCreated", resetTalentMarkers)

Hook.Add("loaded", "AdjustEquipmentStatvalue.Loaded", function()
    validateConfig()
    scanAllCharacters()
end)

Hook.Add("roundStart", "AdjustEquipmentStatvalue.RoundStart", function()
    clearAllStates()
    scanAllCharacters()
end)

Hook.Add("roundEnd", "AdjustEquipmentStatvalue.RoundEnd", clearAllStates)

local lastFallbackTime = Timer.GetTime()

Hook.Add("think", "AdjustEquipmentStatvalue.Think", function()
    local now = Timer.GetTime()
    if now - lastFallbackTime < fallbackInterval then return end
    lastFallbackTime = now

    for character, state in pairs(charStates) do
        if not character or character.Removed then
            charStates[character] = nil
        elseif state.dead then
            if not character.IsDead then restoreRevivedCharacter(character) end
        elseif character.IsDead then
            clearState(state)
            state.dead = true
        else
            for item in pairs(state.mains) do
                if item.Removed or not isStillEquipped(character, item) then
                    removeMain(state, item)
                end
            end
            if next(state.afflictionRefs) then
                refreshAfflictions(state)
            end
            removeEmptyState(state)
        end
    end
end)
