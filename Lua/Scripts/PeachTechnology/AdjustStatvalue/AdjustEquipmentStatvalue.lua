-- XML OnWearing -> event-driven equipment effects.
-- Main items, contained modules and revives use events; think only polls registered dynamic or fallback states.

if not _G.AdjustEquipmentConfig then
    dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua")
end
local CONFIG = _G.AdjustEquipmentConfig

local MAIN_CONFIG = CONFIG.mainItems or {}
local SUB_CONFIG = CONFIG.subItems or {}
local WEAPON_ACCESSORY_CONFIG = CONFIG.weaponAccessories or {}
local HELD_WEAPON_CONFIG = CONFIG.heldWeapons or {}
local LEGACY_AFFLICTION_CONFIG = CONFIG.legacyAfflictions or {}
local fallbackInterval = CONFIG.fallbackInterval or 5.0
local dynamicInterval = CONFIG.dynamicInterval or 0.5
local DYNAMIC_SWEEP_INTERVAL = 0.25
local RESISTANCE_SOURCE = Identifier("dda_adjust_equipment")
local TalentResistanceIdentifier = LuaUserData.CreateStatic("Barotrauma.TalentResistanceIdentifier", true)
local ENEMY_ACCESSORY_RESISTANCE = "deep_enemy_affliction_resistance"
local resistanceKeys = {}
local talentMarkerIds = {}
for _, configs in ipairs({
    MAIN_CONFIG,
    SUB_CONFIG,
    WEAPON_ACCESSORY_CONFIG,
    HELD_WEAPON_CONFIG,
    LEGACY_AFFLICTION_CONFIG,
}) do
    for _, cfg in pairs(configs) do
        for _, effect in ipairs(cfg.effects or { cfg }) do
            for _, id in ipairs(effect.talentMarkers or {}) do
                if type(id) == "string" and id ~= "" then talentMarkerIds[id] = Identifier(id) end
            end
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
local WEAPON_SLOTS = CONFIG.weaponSlots or {
    InvSlotType.LeftHand,
    InvSlotType.RightHand,
}

local function log(...)
    if CONFIG.debug then print("[AdjustEquipmentStatvalue]", ...) end
end

local function warn(...)
    print("[AdjustEquipmentStatvalue] ERROR:", ...)
end

local function isNoneTeam(character)
    return character
        and (character.TeamID == CharacterTeamType.None
            or (character.Info and character.Info.TeamID == CharacterTeamType.None))
end

local function canAdjustCharacter(character)
    return character and not isNoneTeam(character)
end

local DDA_PACKAGE_NAME = "Deep-Diving-Armory"
local SKILL_STAT_TYPES = {
    electrical = StatTypes.ElectricalSkillBonus,
    helm = StatTypes.HelmSkillBonus,
    mechanical = StatTypes.MechanicalSkillBonus,
    medical = StatTypes.MedicalSkillBonus,
    weapons = StatTypes.WeaponsSkillBonus,
}
local nativeEquipmentCompensations = {}
local nativeEquipmentItems = {}
local nativeEquipmentOwners = setmetatable({}, { __mode = "k" })
local pendingNativeEquipmentSync = setmetatable({}, { __mode = "k" })

local function eachDictionaryEntry(dictionary, callback)
    if not dictionary then return end
    if type(dictionary) == "table" then
        for key, value in pairs(dictionary) do callback(key, value) end
        return
    end
    for entry in dictionary do callback(entry.Key, entry.Value) end
end

local function addNativeValues(target, dictionary)
    eachDictionaryEntry(dictionary, function(statType, value)
        value = tonumber(value) or 0
        if value ~= 0 then target[statType] = (target[statType] or 0) + value end
    end)
end

local function addNativeSkillValues(target, dictionary)
    eachDictionaryEntry(dictionary, function(skillIdentifier, value)
        local statType = SKILL_STAT_TYPES[tostring(skillIdentifier)]
        value = tonumber(value) or 0
        if statType and value ~= 0 then target[statType] = (target[statType] or 0) + value end
    end)
end

local function isDdaItem(item)
    local package = item and item.Prefab and item.Prefab.ContentPackage
    return package and package.Name == DDA_PACKAGE_NAME
end

local function collectNativeEquipmentValues(character)
    local values, seen = {}, {}
    local inventory = character and character.Inventory
    if not inventory then return values, seen end

    for _, slot in ipairs(WEARABLE_SLOTS) do
        local item = inventory:GetItemInLimbSlot(slot)
        if item and not item.Removed and not seen[item] and isDdaItem(item) then
            seen[item] = true
            local wearable = item.GetComponentString("Wearable")
            if wearable then
                addNativeValues(values, wearable.WearableStatValues)
                addNativeSkillValues(values, wearable.SkillModifiers)
            end
        end
    end
    for _, slot in ipairs(WEAPON_SLOTS) do
        local item = inventory:GetItemInLimbSlot(slot)
        if item and not item.Removed and not seen[item] and isDdaItem(item) then
            seen[item] = true
            local holdable = item.GetComponentString("Holdable")
            if holdable then addNativeValues(values, holdable.HoldableStatValues) end
        end
    end
    return values, seen
end

local function setNativeEquipmentItems(character, items)
    for item in pairs(nativeEquipmentItems[character] or {}) do
        if not items[item] and nativeEquipmentOwners[item] == character then nativeEquipmentOwners[item] = nil end
    end
    for item in pairs(items) do nativeEquipmentOwners[item] = character end
    nativeEquipmentItems[character] = next(items) and items or nil
end

local function setNativeEquipmentCompensation(character, compensation)
    local previous = nativeEquipmentCompensations[character] or {}
    local handled = {}
    for statType, previousValue in pairs(previous) do
        handled[statType] = true
        local nextValue = compensation[statType] or 0
        if nextValue ~= previousValue then character:ChangeStat(statType, nextValue - previousValue) end
    end
    for statType, nextValue in pairs(compensation) do
        if not handled[statType] then character:ChangeStat(statType, nextValue) end
    end
    nativeEquipmentCompensations[character] = next(compensation) and compensation or nil
end

local function syncNativeEquipmentCompensation(character)
    if not character then return end
    pendingNativeEquipmentSync[character] = nil
    if character.Removed then return end
    local compensation, items = {}, {}
    if isNoneTeam(character) and not character.IsDead then
        if character.Inventory then character:OnWearablesChanged() end
        local values
        values, items = collectNativeEquipmentValues(character)
        for statType, value in pairs(values) do
            compensation[statType] = -value
        end
    end
    setNativeEquipmentCompensation(character, compensation)
    setNativeEquipmentItems(character, items)
end

local function queueNativeEquipmentCompensation(character)
    if character and not character.Removed then pendingNativeEquipmentSync[character] = true end
end

local function clearNativeEquipmentCompensation(character)
    if not character then return end
    if not character.Removed then setNativeEquipmentCompensation(character, {}) end
    setNativeEquipmentItems(character, {})
end

local vceWarningBox
local function warnMissingVce(character, item)
    if not CLIENT or character ~= Character.Controlled then return end
    if vceWarningBox and not vceWarningBox.Closed then return end
    if not item.HasTag("gun")
        or item.GetComponentString("RangedWeapon")
        or item.GetComponentString("SwitchableRangedWeapon") then return end

    vceWarningBox = GUI.MessageBox(
        "Deep-Diving-Armory",
        "未检测到 VCE（Vanilla Components Expanded），请安装并启用，否则 DDA 枪械无法正常使用。\nVCE was not detected; install and enable it to use DDA firearms."
    )
end

local function afflictionList(value)
    if not value then return {} end
    if value.id then return { value } end
    return value
end

local fallbackStates = {}
local dynamicStates = {}

local function configNeedsFallback(cfg)
    for _, effect in ipairs(cfg.effects or { cfg }) do
        if effect.blockedByEnemyResistance then return true end
    end
    return false
end

local function configNeedsDynamic(cfg)
    for _, effect in ipairs(cfg.effects or { cfg }) do
        if effect.when then return true end
    end
    return false
end

local function updateFallbackState(state)
    local needsAfflictionRepair = false
    for _, ref in pairs(state.afflictionRefs or {}) do
        if ref.needsRepair or ref.refreshDuration then
            needsAfflictionRepair = true
            break
        end
    end

    if state.dead or next(state.conditionalConfigs or {}) or needsAfflictionRepair then
        fallbackStates[state] = true
    else
        fallbackStates[state] = nil
    end
end

local function validateEffectConfig(itemId, cfg)
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
    if cfg.statsKey ~= nil and (type(cfg.statsKey) ~= "string" or cfg.statsKey == "") then
        warn("invalid stats key", itemId, tostring(cfg.statsKey))
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
        elseif resistance.source ~= nil and (type(resistance.source) ~= "string" or resistance.source == "") then
            warn("invalid resistance source", itemId, tostring(resistance.source))
        end
    end
    for _, affliction in ipairs(afflictionList(cfg.affliction)) do
        if not affliction.id or not AfflictionPrefab.Prefabs[affliction.id] then
            warn("invalid Affliction", itemId, tostring(affliction.id))
        end
    end
    if cfg.blockedByEnemyResistance ~= nil and type(cfg.blockedByEnemyResistance) ~= "boolean" then
        warn("invalid blockedByEnemyResistance", itemId, tostring(cfg.blockedByEnemyResistance))
    end
    if cfg.when ~= nil and type(cfg.when) ~= "function" then
        warn("invalid dynamic condition", itemId)
    end
end

local function validateItemConfigs(configs)
    for itemId, cfg in pairs(configs) do
        if ItemPrefab and not ItemPrefab.GetItemPrefab(itemId) then
            warn("item prefab not found", itemId)
        end
        for _, effect in ipairs(cfg.effects or { cfg }) do validateEffectConfig(itemId, effect) end
    end
end

local function validateConfig()
    validateItemConfigs(MAIN_CONFIG)
    validateItemConfigs(SUB_CONFIG)
    validateItemConfigs(WEAPON_ACCESSORY_CONFIG)
    validateItemConfigs(HELD_WEAPON_CONFIG)
    for afflictionId, cfg in pairs(LEGACY_AFFLICTION_CONFIG) do
        if type(cfg.timeout) ~= "number" or cfg.timeout <= 0 then
            warn("invalid legacy Affliction timeout", afflictionId, tostring(cfg.timeout))
        end
        if not AfflictionPrefab.Prefabs[afflictionId] then
            warn("legacy Affliction prefab not found", afflictionId)
        end
        for _, effect in ipairs(cfg.effects or { cfg }) do
            validateEffectConfig("legacy:" .. afflictionId, effect)
        end
    end
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

local function eachAppliedEffect(effects, callback)
    for _, effect in pairs(effects or {}) do callback(effect) end
end

local function eachActiveEffects(state, callback)
    for _, sources in ipairs({ state.mains, state.weapons }) do
        for _, source in pairs(sources) do
            eachAppliedEffect(source.effects, callback)
            for _, sub in pairs(source.subs) do eachAppliedEffect(sub.effects, callback) end
        end
    end
    for _, source in pairs(state.legacyAfflictions or {}) do
        eachAppliedEffect(source.effects, callback)
    end
end

local function refreshStats(state)
    local blocked = {}
    eachActiveEffects(state, function(effects)
        for _, group in ipairs(effects.cfg.blocksStatGroups or {}) do blocked[group] = true end
    end)
    local seen = {}
    eachActiveEffects(state, function(effects)
        local target = effects.statRef or effects
        if not seen[target] then
            seen[target] = true
            local shouldApply = canAdjustCharacter(state.character) and not blocked[target.cfg.statGroup]
            if shouldApply and not target.statsApplied then
                target.stats = applyStats(state.character, target.cfg.stats)
                target.statsApplied = true
            elseif not shouldApply and target.statsApplied then
                removeStats(state.character, target.stats)
                target.stats = {}
                target.statsApplied = false
            end
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
        key = TalentResistanceIdentifier(Identifier(id), RESISTANCE_SOURCE)
        resistanceKeys[id] = key
    end
    return key
end

local function refreshResistance(state, ref)
    if ref.applied then state.character:RemoveAbilityResistance(ref.key) end
    local multiplier = 1
    for _, source in pairs(ref.sources) do
        if source.count > 0 then multiplier = multiplier - (1 - source.multiplier) end
    end
    state.character:ChangeAbilityResistance(ref.key, math.max(0, multiplier))
    ref.applied = true
end

local function acquireResistances(state, configured)
    local applied = {}
    for _, cfg in ipairs(configured or {}) do
        if type(cfg.id) == "string" and type(cfg.multiplier) == "number" and cfg.multiplier >= 0 then
            local source = cfg.source or tostring(RESISTANCE_SOURCE)
            local ref = state.resistanceRefs[cfg.id]
            if not ref then
                ref = { key = resistanceKey(cfg.id), sources = {} }
                state.resistanceRefs[cfg.id] = ref
            end
            local sourceRef = ref.sources[source]
            if not sourceRef then
                sourceRef = { count = 0, multiplier = cfg.multiplier }
                ref.sources[source] = sourceRef
            elseif sourceRef.multiplier ~= cfg.multiplier then
                warn("conflicting resistance multiplier", cfg.id, tostring(cfg.multiplier))
            end
            sourceRef.count = sourceRef.count + 1
            if sourceRef.count == 1 then refreshResistance(state, ref) end
            applied[#applied + 1] = { id = cfg.id, source = source }
        end
    end
    return applied
end

local function releaseResistances(state, applied)
    for _, token in ipairs(applied or {}) do
        local ref = state.resistanceRefs[token.id]
        if ref then
            local source = ref.sources[token.source]
            if source then source.count = source.count - 1 end
            if source and source.count <= 0 then
                ref.sources[token.source] = nil
                if next(ref.sources) then
                    refreshResistance(state, ref)
                else
                    if ref.applied then state.character:RemoveAbilityResistance(ref.key) end
                    state.resistanceRefs[token.id] = nil
                end
            elseif not source then
                warn("missing resistance source", token.id, token.source)
            end
        end
    end
end

local function acquireStats(state, cfg)
    if not cfg.statsKey then
        return nil, applyStats(state.character, cfg.stats), true
    end

    local ref = state.statRefs[cfg.statsKey]
    if not ref then
        ref = {
            count = 0,
            cfg = cfg,
            stats = applyStats(state.character, cfg.stats),
            statsApplied = true,
        }
        state.statRefs[cfg.statsKey] = ref
    end
    ref.count = ref.count + 1
    return ref, {}, false
end

local function releaseStats(state, effects)
    local ref = effects.statRef
    if not ref then
        if effects.statsApplied then removeStats(state.character, effects.stats) end
        return
    end

    ref.count = ref.count - 1
    if ref.count <= 0 then
        if ref.statsApplied then removeStats(state.character, ref.stats) end
        state.statRefs[effects.cfg.statsKey] = nil
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
                local requestedAmount = cfg.strength or 1
                local target = before + requestedAmount
                health:ApplyAffliction(head, prefab:Instantiate(requestedAmount))
                local instance = health:GetAffliction(cfg.id, true)
                if instance then instance.Strength = target end
                local after = health:GetAfflictionStrengthByIdentifier(cfg.id)
                local refreshDuration = prefab.Duration > 0 and fallbackInterval * 2 or nil
                if instance and refreshDuration then instance.Duration = refreshDuration end
                ref = {
                    count = 0,
                    amount = math.max(0, after - before),
                    target = instance and after or target,
                    prefabDuration = prefab.Duration,
                    refreshDuration = refreshDuration,
                    needsRepair = not instance,
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
        if ref.needsRepair or ref.refreshDuration then
            local before = health:GetAfflictionStrengthByIdentifier(id)
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
                if ref.needsRepair then
                    local after = health:GetAfflictionStrengthByIdentifier(id)
                    ref.amount = ref.amount + math.max(0, after - before)
                    ref.target = after
                    ref.needsRepair = false
                end
                if ref.refreshDuration then instance.Duration = ref.refreshDuration end
            end
        end
    end
    updateFallbackState(state)
end

local function applyEffects(state, cfg)
    local statRef, stats, statsApplied = acquireStats(state, cfg)
    return {
        cfg = cfg,
        statRef = statRef,
        stats = stats,
        statsApplied = statsApplied,
        flags = acquireFlags(state, cfg.flags),
        talentMarkers = acquireTalentMarkers(state, cfg.talentMarkers),
        resistances = acquireResistances(state, cfg.resistances),
        afflictions = acquireAfflictions(state, cfg.affliction),
    }
end

local function isBlockedByEnemyResistance(state, cfg)
    local health = state.character.CharacterHealth
    return cfg.blockedByEnemyResistance
        and health
        and health:GetAfflictionStrengthByIdentifier(ENEMY_ACCESSORY_RESISTANCE) > 0
end

local function isEffectActive(state, cfg, host, accessory)
    return canAdjustCharacter(state.character)
        and not isBlockedByEnemyResistance(state, cfg)
        and (not cfg.when or cfg.when(state.character, host, accessory))
end

local function applyConfig(state, cfg, host, accessory)
    local applied = {}
    for index, effect in ipairs(cfg.effects or { cfg }) do
        if isEffectActive(state, effect, host, accessory) then
            applied[index] = applyEffects(state, effect)
        end
    end
    if configNeedsDynamic(cfg) then
        local dynamicEffects = {}
        local now = Timer.GetTime()
        for index, effect in ipairs(cfg.effects or { cfg }) do
            if effect.when then
                dynamicEffects[index] = {
                    interval = effect.pollInterval or cfg.pollInterval or dynamicInterval,
                    lastCheck = now,
                }
            end
        end
        state.dynamicConfigs[applied] = {
            cfg = cfg,
            host = host,
            accessory = accessory,
            effects = dynamicEffects,
        }
        dynamicStates[state] = true
    elseif configNeedsFallback(cfg) then
        state.conditionalConfigs[applied] = cfg
    end
    updateFallbackState(state)
    return applied
end

local removeEffects
local syncConfigEffect
local function syncConfigEffects(state, cfg, applied, host, accessory)
    local changed = false
    for index, effect in ipairs(cfg.effects or { cfg }) do
        changed = syncConfigEffect(state, cfg, applied, index, host, accessory) or changed
    end
    local dynamic = state.dynamicConfigs[applied]
    if dynamic then
        local now = Timer.GetTime()
        for index in pairs(dynamic.effects) do
            dynamic.effects[index].lastCheck = now
        end
    end
    updateFallbackState(state)
    return changed
end

removeEffects = function(state, effects)
    if not effects then return end
    releaseStats(state, effects)
    releaseFlags(state, effects.flags)
    releaseTalentMarkers(state, effects.talentMarkers)
    releaseResistances(state, effects.resistances)
    releaseAfflictions(state, effects.afflictions)
end

syncConfigEffect = function(state, cfg, applied, index, host, accessory)
    local effect = (cfg.effects or { cfg })[index]
    local active = isEffectActive(state, effect, host, accessory)
    if not active and applied[index] then
        removeEffects(state, applied[index])
        applied[index] = nil
        return true
    elseif active and not applied[index] then
        applied[index] = applyEffects(state, effect)
        return true
    end
    return false
end

local function removeConfigEffects(state, effects)
    state.conditionalConfigs[effects] = nil
    state.dynamicConfigs[effects] = nil
    if not next(state.dynamicConfigs) then dynamicStates[state] = nil end
    for _, effect in pairs(effects or {}) do removeEffects(state, effect) end
    updateFallbackState(state)
end

local function activeSubItems(mainItem, configs)
    local result = {}
    local inventory = mainItem.OwnInventory
    local checkSubSlot = configs == SUB_CONFIG
    local container = inventory and inventory.Container
    -- ponytail: DDA XML marks dedicated equipment slots with maxstacksize=1; add an explicit role if that changes.
    if checkSubSlot and (not inventory or not container
        or not inventory.FindIndex
        or not container.GetMaxStackSize
        or not container.CanBeContained) then
        return result
    end
    local items = inventory and inventory.AllItems or mainItem.ContainedItems
    if items then
        for item in items do
            if item and not item.Removed and item.Prefab then
                local itemId = tostring(item.Prefab.Identifier)
                local cfg = configs[itemId]
                if cfg then
                    local slot = checkSubSlot and inventory:FindIndex(item)
                    if not checkSubSlot
                        or (type(slot) == "number" and slot >= 0
                            and container:GetMaxStackSize(slot) == 1
                            and container:CanBeContained(item, slot)) then
                        result[item] = { cfg = cfg, itemId = itemId }
                    end
                end
            end
        end
    end
    return result
end

local trackedItems = {}

local function trackItem(item, state, kind, source)
    trackedItems[item] = { state = state, kind = kind, source = source }
end

local function untrackItem(item, state, source)
    local tracked = trackedItems[item]
    if tracked and tracked.state == state and tracked.source == source then trackedItems[item] = nil end
end

local function syncSubItems(state, source, current)
    if source.cfg then syncConfigEffects(state, source.cfg, source.effects, source.item) end
    current = current or activeSubItems(source.item, source.subConfig)
    for item, data in pairs(current) do
        if not source.subs[item] then
            source.subs[item] = {
                itemId = data.itemId,
                cfg = data.cfg,
                effects = applyConfig(state, data.cfg, source.item, item),
            }
            trackItem(item, state, "sub", source)
            log("equip sub", data.itemId, "in", source.itemId)
        else
            syncConfigEffects(state, data.cfg, source.subs[item].effects, source.item, item)
        end
    end
    for item, sub in pairs(source.subs) do
        if not current[item] then
            removeConfigEffects(state, sub.effects)
            source.subs[item] = nil
            untrackItem(item, state, source)
            log("unequip sub", sub.itemId, "from", source.itemId)
        end
    end
    refreshStats(state)
end

local charStates = {}
local clearLegacyEffects

local function ensureState(character)
    local state = charStates[character]
    if not state then
        state = {
            character = character,
            mains = {},
            weapons = {},
            statRefs = {},
            flagRefs = {},
            talentMarkerRefs = {},
            resistanceRefs = {},
            afflictionRefs = {},
            conditionalConfigs = {},
            dynamicConfigs = {},
            legacyAfflictions = {},
        }
        charStates[character] = state
    end
    return state
end

local function isInSlots(character, item, slots)
    if not character or not character.Inventory then return false end
    for _, slot in ipairs(slots) do
        if character.Inventory:GetItemInLimbSlot(slot) == item then return true end
    end
    return false
end

local function isStillEquipped(character, item)
    return isInSlots(character, item, WEARABLE_SLOTS)
end

local function isStillHeld(character, item)
    return isInSlots(character, item, WEAPON_SLOTS)
end

local function addMain(character, item)
    if not canAdjustCharacter(character) or character.Removed or character.IsDead then return end
    local cfg, itemId = getMainConfig(item)
    if not cfg or not isStillEquipped(character, item) then return end

    local state = ensureState(character)
    if state.mains[item] then return end

    local source = {
        item = item,
        itemId = itemId,
        cfg = cfg,
        effects = applyConfig(state, cfg, item),
        subs = {},
        subConfig = SUB_CONFIG,
    }
    state.mains[item] = source
    trackItem(item, state, "main", source)
    syncSubItems(state, source)
    log("equip main", character.Name or "?", itemId)
end

local function removeMain(state, item)
    local source = state.mains[item]
    if not source then return end
    for subItem, sub in pairs(source.subs) do
        removeConfigEffects(state, sub.effects)
        untrackItem(subItem, state, source)
    end
    removeConfigEffects(state, source.effects)
    state.mains[item] = nil
    untrackItem(item, state, source)
    refreshStats(state)
    log("unequip main", state.character.Name or "?", source.itemId)
end

local function addWeapon(character, item)
    if not canAdjustCharacter(character) or character.Removed or character.IsDead or not isStillHeld(character, item) then return end
    if not item or item.Removed or not item.Prefab then return end
    local itemId = tostring(item.Prefab.Identifier)
    local state = charStates[character]
    if state and state.weapons[item] then return end

    local cfg = HELD_WEAPON_CONFIG[itemId]
    local current = activeSubItems(item, WEAPON_ACCESSORY_CONFIG)
    if not cfg and not next(current) then return end

    state = ensureState(character)

    local source = {
        item = item,
        itemId = itemId,
        cfg = cfg,
        effects = cfg and applyConfig(state, cfg, item) or {},
        subs = {},
        subConfig = WEAPON_ACCESSORY_CONFIG,
    }
    state.weapons[item] = source
    trackItem(item, state, "weapon", source)
    syncSubItems(state, source, current)
    log("equip weapon", character.Name or "?", itemId)
end

local function removeWeapon(state, item)
    local source = state.weapons[item]
    if not source then return end
    for subItem, sub in pairs(source.subs) do
        removeConfigEffects(state, sub.effects)
        untrackItem(subItem, state, source)
    end
    removeConfigEffects(state, source.effects)
    state.weapons[item] = nil
    untrackItem(item, state, source)
    refreshStats(state)
    log("unequip weapon", state.character.Name or "?", source.itemId)
end

local function syncChangedContainer(container)
    local host = container and container.Item
    local tracked = host and trackedItems[host]
    local state = tracked and tracked.state
    local character = state and state.character or (host and host:GetRootInventoryOwner())
    if not character or not LuaUserData.IsTargetType(character, "Barotrauma.Character") or not character.CharacterHealth then return end

    state = state or charStates[character]
    local source = tracked and tracked.source or (state and (state.mains[host] or state.weapons[host]))
    if source then
        syncSubItems(state, source)
        if state.weapons[source.item] and not HELD_WEAPON_CONFIG[source.itemId] and not next(source.subs) then
            removeWeapon(state, source.item)
        end
    else
        addWeapon(character, host)
    end
end

local function clearState(state)
    for item in pairs(state.mains) do removeMain(state, item) end
    for item in pairs(state.weapons) do removeWeapon(state, item) end
    clearLegacyEffects(state)
end

local function discardStateIndex(state)
    for item, source in pairs(state.mains) do
        untrackItem(item, state, source)
        for subItem in pairs(source.subs) do untrackItem(subItem, state, source) end
    end
    for item, source in pairs(state.weapons) do
        untrackItem(item, state, source)
        for subItem in pairs(source.subs) do untrackItem(subItem, state, source) end
    end
end

local function removeEmptyState(state)
    if not state.dead
        and not next(state.mains)
        and not next(state.weapons)
        and not next(state.legacyAfflictions) then
        fallbackStates[state] = nil
        dynamicStates[state] = nil
        charStates[state.character] = nil
    end
end

local LEGACY_NET_ID = "DDA.AdjustEquipment.LegacyAffliction"
local LEGACY_NET_REQUEST = 0
local LEGACY_NET_CHANGE = 1
local LEGACY_NET_SNAPSHOT = 2

local function sendLegacyChange(character, afflictionId, active)
    if not SERVER or not Networking or not Game or not Game.IsMultiplayer then return end
    local message = Networking.Start(LEGACY_NET_ID)
    message.WriteByte(LEGACY_NET_CHANGE)
    message.WriteUInt16(character.ID)
    message.WriteString(afflictionId)
    message.WriteBoolean(active)
    Networking.Send(message)
end

local function deactivateLegacyAffliction(state, afflictionId, notify)
    local entry = state.legacyAfflictions[afflictionId]
    if not entry then return end
    state.legacyAfflictions[afflictionId] = nil
    removeConfigEffects(state, entry.effects)
    refreshStats(state)
    if notify ~= false then sendLegacyChange(state.character, afflictionId, false) end
end

clearLegacyEffects = function(state, notify)
    for afflictionId in pairs(state.legacyAfflictions) do
        deactivateLegacyAffliction(state, afflictionId, notify)
    end
end

local function activateLegacyAffliction(character, afflictionId, notify)
    local cfg = LEGACY_AFFLICTION_CONFIG[afflictionId]
    if not cfg or not canAdjustCharacter(character) or character.Removed or character.IsDead then return nil end

    local state = ensureState(character)
    local entry = state.legacyAfflictions[afflictionId]
    if entry then return entry end

    entry = { effects = applyConfig(state, cfg) }
    state.legacyAfflictions[afflictionId] = entry
    refreshStats(state)
    if notify ~= false then sendLegacyChange(character, afflictionId, true) end
    return entry
end

local function scheduleLegacyExpiry(state, afflictionId, entry, delay)
    Timer.Wait(function()
        local character = state.character
        if charStates[character] ~= state
            or state.legacyAfflictions[afflictionId] ~= entry
            or character.Removed
            or character.IsDead then return end

        local remaining = entry.deadline - Timer.GetTime()
        if remaining > 0 then
            scheduleLegacyExpiry(state, afflictionId, entry, remaining)
            return
        end

        deactivateLegacyAffliction(state, afflictionId)
        removeEmptyState(state)
    end, math.max(1, math.ceil(delay * 1000)))
end

local function armLegacyAffliction(character, afflictionId)
    local cfg = LEGACY_AFFLICTION_CONFIG[afflictionId]
    if not cfg then return end

    local state = charStates[character]
    local entry = state and state.legacyAfflictions[afflictionId]
    if not entry then
        entry = activateLegacyAffliction(character, afflictionId)
        if not entry then return end
        state = charStates[character]
        entry.deadline = Timer.GetTime() + cfg.timeout
        scheduleLegacyExpiry(state, afflictionId, entry, cfg.timeout)
        return
    end
    entry.deadline = Timer.GetTime() + cfg.timeout
end

local function sendLegacySnapshot(connection)
    local count = 0
    for _, state in pairs(charStates) do
        if canAdjustCharacter(state.character) and not state.character.Removed and not state.character.IsDead then
            for _ in pairs(state.legacyAfflictions) do count = count + 1 end
        end
    end

    local message = Networking.Start(LEGACY_NET_ID)
    message.WriteByte(LEGACY_NET_SNAPSHOT)
    message.WriteUInt16(count)
    for _, state in pairs(charStates) do
        if canAdjustCharacter(state.character) and not state.character.Removed and not state.character.IsDead then
            for afflictionId in pairs(state.legacyAfflictions) do
                message.WriteUInt16(state.character.ID)
                message.WriteString(afflictionId)
            end
        end
    end
    Networking.Send(message, connection)
end

local snapshotRequestPending = false
local function requestLegacySnapshot()
    if not CLIENT or SERVER or not Networking or not Game or not Game.IsMultiplayer
        or snapshotRequestPending then return end
    snapshotRequestPending = true
    Timer.Wait(function()
        snapshotRequestPending = false
        if not Game or not Game.IsMultiplayer then return end
        local message = Networking.Start(LEGACY_NET_ID)
        message.WriteByte(LEGACY_NET_REQUEST)
        Networking.Send(message)
    end, 500)
end

local function applyLegacyNetworkState(characterId, afflictionId, active)
    local character = Entity.FindEntityByID(characterId)
    if not character
        or not LuaUserData.IsTargetType(character, "Barotrauma.Character")
        or character.Removed then return end

    if active then
        activateLegacyAffliction(character, afflictionId, false)
        return
    end

    local state = charStates[character]
    if state then
        deactivateLegacyAffliction(state, afflictionId, false)
        removeEmptyState(state)
    end
end

local legacySnapshotRequestTimes = setmetatable({}, { __mode = "k" })
if Networking then
    if SERVER then
        Networking.Receive(LEGACY_NET_ID, function(message, client)
            if not message or (message.LengthBits and message.LengthBits - message.BitPosition < 8) then return end
            if message.ReadByte() ~= LEGACY_NET_REQUEST or not client or not client.Connection then return end
            local now = Timer.GetTime()
            local clientKey = client.Connection
            if now - (legacySnapshotRequestTimes[clientKey] or -math.huge) < 1 then return end
            legacySnapshotRequestTimes[clientKey] = now
            sendLegacySnapshot(client.Connection)
        end)
    elseif CLIENT then
        Networking.Receive(LEGACY_NET_ID, function(message)
            if not message or (message.LengthBits and message.LengthBits - message.BitPosition < 8) then return end
            local operation = message.ReadByte()
            if operation == LEGACY_NET_CHANGE then
                applyLegacyNetworkState(
                    message.ReadUInt16(),
                    message.ReadString(),
                    message.ReadBoolean()
                )
            elseif operation == LEGACY_NET_SNAPSHOT then
                local states = {}
                for _, state in pairs(charStates) do states[#states + 1] = state end
                for _, state in ipairs(states) do
                    clearLegacyEffects(state, false)
                    removeEmptyState(state)
                end
                for _ = 1, message.ReadUInt16() do
                    applyLegacyNetworkState(message.ReadUInt16(), message.ReadString(), true)
                end
            end
        end)
    end
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

local function addEquippedItems(character)
    if not canAdjustCharacter(character) or character.Removed or character.IsDead or not character.Inventory then return end
    for _, slot in ipairs(WEARABLE_SLOTS) do
        addMain(character, character.Inventory:GetItemInLimbSlot(slot))
    end
    for _, slot in ipairs(WEAPON_SLOTS) do
        addWeapon(character, character.Inventory:GetItemInLimbSlot(slot))
    end
end

local function syncCharacterTeam(character)
    if not character or character.Removed or character.IsDead then return end
    syncNativeEquipmentCompensation(character)
    if canAdjustCharacter(character) then
        addEquippedItems(character)
        return
    end

    local state = charStates[character]
    if state then
        clearState(state)
        removeEmptyState(state)
    end
end

local function discardCharacterState(character)
    nativeEquipmentCompensations[character] = nil
    setNativeEquipmentItems(character, {})
    local state = charStates[character]
    if not state then return end
    clearLegacyEffects(state)
    discardStateIndex(state)
    charStates[character] = nil
    fallbackStates[state] = nil
    dynamicStates[state] = nil
end

local function reconcileCharacterInventory(inventory)
    local character = inventory and inventory.Owner
    if not LuaUserData.IsTargetType(character, "Barotrauma.Character")
        or character.Removed
        or character.IsDead
        or not character.Inventory
        or character.Inventory ~= inventory then return end

    local state = charStates[character]
    if state then
        for item in pairs(state.mains) do
            if item.Removed or not isStillEquipped(character, item) then removeMain(state, item) end
        end
        for item in pairs(state.weapons) do
            if item.Removed or not isStillHeld(character, item) then removeWeapon(state, item) end
        end
    end

    addEquippedItems(character)
    state = charStates[character]
    if state then removeEmptyState(state) end
    syncNativeEquipmentCompensation(character)
end

local function clearMovedEquipment(inventory, ptable)
    local item = ptable and ptable["item"]
    local nativeOwner = item and nativeEquipmentOwners[item]
    local tracked = item and trackedItems[item]
    if tracked and (tracked.kind == "main" or tracked.kind == "weapon") then
        local state = tracked.state
        if tracked.kind == "main" then
            if not isStillEquipped(state.character, item) then removeMain(state, item) end
        elseif not isStillHeld(state.character, item) then
            removeWeapon(state, item)
        end
        removeEmptyState(state)
    end
    if nativeOwner then queueNativeEquipmentCompensation(nativeOwner) end
    local owner = inventory and inventory.Owner
    if owner and LuaUserData.IsTargetType(owner, "Barotrauma.Character") and owner ~= nativeOwner then
        queueNativeEquipmentCompensation(owner)
    end
end

local function clearRemovedEquipment(_, ptable)
    local item = ptable and ptable["item"]
    local tracked = item and trackedItems[item]
    if not nativeEquipmentOwners[item]
        and not (tracked and (tracked.kind == "main" or tracked.kind == "weapon")) then return end
    clearMovedEquipment(nil, ptable)
end

local function scanCharacter(character)
    if not character or character.Removed or character.IsDead then return end
    resetTalentMarkers(character)
    syncCharacterTeam(character)
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
    if state then
        updateFallbackState(state)
        removeEmptyState(state)
    end
end

local function clearAllStates()
    for _, state in pairs(charStates) do
        if state.character and not state.character.Removed then clearState(state) end
    end
    for character in pairs(nativeEquipmentCompensations) do
        clearNativeEquipmentCompensation(character)
    end
    charStates = {}
    trackedItems = {}
    fallbackStates = {}
    dynamicStates = {}
    nativeEquipmentCompensations = {}
    nativeEquipmentItems = {}
    nativeEquipmentOwners = setmetatable({}, { __mode = "k" })
    pendingNativeEquipmentSync = setmetatable({}, { __mode = "k" })
end

Hook.Patch(
    "AdjustEquipmentStatvalue.Equip",
    "Barotrauma.Item",
    "Equip",
    { "Barotrauma.Character" },
    function(item, ptable)
        local character = ptable["character"]
        if isStillHeld(character, item) then warnMissingVce(character, item) end
        addMain(character, item)
        addWeapon(character, item)
        queueNativeEquipmentCompensation(character)
    end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.Unequip",
    "Barotrauma.Item",
    "Unequip",
    { "Barotrauma.Character" },
    function(item, ptable)
        local character = ptable["character"]
        local state = character and charStates[character]
        if state then
            removeMain(state, item)
            removeWeapon(state, item)
            removeEmptyState(state)
        end
        queueNativeEquipmentCompensation(character)
    end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "AdjustEquipmentStatvalue.InventoryPutItem",
    "Barotrauma.Inventory",
    "PutItem",
    clearMovedEquipment,
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

Hook.Patch(
    "AdjustEquipmentStatvalue.InventoryRemoveItem",
    "Barotrauma.Inventory",
    "RemoveItem",
    { "Barotrauma.Item" },
    clearRemovedEquipment,
    Hook.HookMethodType.After
)

Hook.Add("character.applyAffliction", "AdjustEquipmentStatvalue.LegacyAffliction", function(
    characterHealth,
    _,
    newAffliction
)
    if not characterHealth or not newAffliction or (tonumber(newAffliction.Strength) or 0) <= 0 then return end
    if CLIENT and not SERVER and Game and Game.IsMultiplayer then return end

    local prefab = newAffliction.Prefab
    local afflictionId = tostring(prefab and prefab.Identifier or newAffliction.Identifier)
    if not LEGACY_AFFLICTION_CONFIG[afflictionId] then return end
    armLegacyAffliction(characterHealth.Character, afflictionId)
end)

Hook.Patch(
    "AdjustEquipmentStatvalue.TeamChanged",
    "Barotrauma.Character",
    "set_TeamID",
    { "Barotrauma.CharacterTeamType" },
    syncCharacterTeam,
    Hook.HookMethodType.After
)

if SERVER then
    Hook.Patch(
        "AdjustEquipmentStatvalue.InventoryServerEventRead",
        "Barotrauma.Inventory",
        "ServerEventRead",
        reconcileCharacterInventory,
        Hook.HookMethodType.After
    )
end

if CLIENT then
    Hook.Patch(
        "AdjustEquipmentStatvalue.InventoryApplyReceivedState",
        "Barotrauma.Inventory",
        "ApplyReceivedState",
        {},
        reconcileCharacterInventory,
        Hook.HookMethodType.After
    )
end

Hook.Patch(
    "AdjustEquipmentStatvalue.CharacterRemove",
    "Barotrauma.Character",
    "Remove",
    {},
    discardCharacterState,
    Hook.HookMethodType.After
)

Hook.Add("item.removed", "AdjustEquipmentStatvalue.ItemRemoved", function(item)
    local nativeOwner = nativeEquipmentOwners[item]
    local tracked = trackedItems[item]
    if tracked then
        local state = tracked.state
        if tracked.kind == "main" then
            removeMain(state, item)
            removeEmptyState(state)
        elseif tracked.kind == "weapon" then
            removeWeapon(state, item)
            removeEmptyState(state)
        else
            local source = tracked.source
            local sub = source and source.subs[item]
            if sub then
                removeConfigEffects(state, sub.effects)
                source.subs[item] = nil
                untrackItem(item, state, source)
                refreshStats(state)
            end
        end
    end
    if nativeOwner then queueNativeEquipmentCompensation(nativeOwner) end
end)

Hook.Add("character.death", "AdjustEquipmentStatvalue.Death", function(character)
    clearNativeEquipmentCompensation(character)
    local state = charStates[character]
    if not state then return end
    clearState(state)
    state.dead = true
    updateFallbackState(state)
end)

Hook.Add("character.created", "AdjustEquipmentStatvalue.CharacterCreated", function(character)
    resetTalentMarkers(character)
    Timer.Wait(function()
        if character and not character.Removed and not character.IsDead then scanCharacter(character) end
    end, 1)
    requestLegacySnapshot()
end)

Hook.Add("loaded", "AdjustEquipmentStatvalue.Loaded", function()
    validateConfig()
    scanAllCharacters()
    requestLegacySnapshot()
end)

Hook.Add("roundStart", "AdjustEquipmentStatvalue.RoundStart", function()
    clearAllStates()
    scanAllCharacters()
    requestLegacySnapshot()
end)

Hook.Add("roundEnd", "AdjustEquipmentStatvalue.RoundEnd", clearAllStates)

local lastFallbackTime = Timer.GetTime()
local lastDynamicTime = lastFallbackTime

Hook.Add("think", "AdjustEquipmentStatvalue.Think", function()
    local now = Timer.GetTime()
    if next(pendingNativeEquipmentSync) then
        local pending = pendingNativeEquipmentSync
        pendingNativeEquipmentSync = setmetatable({}, { __mode = "k" })
        for character in pairs(pending) do syncNativeEquipmentCompensation(character) end
    end
    local checkDynamic = now - lastDynamicTime >= DYNAMIC_SWEEP_INTERVAL
    local checkFallback = now - lastFallbackTime >= fallbackInterval
    if not checkDynamic and not checkFallback then return end

    if checkDynamic then
        lastDynamicTime = now
        for state in pairs(dynamicStates) do
            local character = state.character
            if not character or character.Removed then
                discardStateIndex(state)
                if character then charStates[character] = nil end
                fallbackStates[state] = nil
                dynamicStates[state] = nil
            elseif character.IsDead then
                clearState(state)
                state.dead = true
                updateFallbackState(state)
            else
                for applied, dynamic in pairs(state.dynamicConfigs) do
                    local changed = false
                    for index, effect in pairs(dynamic.effects) do
                        if now - effect.lastCheck >= effect.interval then
                            effect.lastCheck = now
                            changed = syncConfigEffect(
                                state, dynamic.cfg, applied, index, dynamic.host, dynamic.accessory
                            ) or changed
                        end
                    end
                    if changed then
                        refreshStats(state)
                        updateFallbackState(state)
                    end
                end
            end
        end
    end

    if not checkFallback then return end
    lastFallbackTime = now

    for state in pairs(fallbackStates) do
        local character = state.character
        if not character or character.Removed then
            discardStateIndex(state)
            charStates[character] = nil
            fallbackStates[state] = nil
        elseif state.dead then
            if not character.IsDead then restoreRevivedCharacter(character) end
        elseif character.IsDead then
            clearState(state)
            state.dead = true
            updateFallbackState(state)
        else
            for applied, cfg in pairs(state.conditionalConfigs) do syncConfigEffects(state, cfg, applied) end
            refreshAfflictions(state)
        end
    end
end)
