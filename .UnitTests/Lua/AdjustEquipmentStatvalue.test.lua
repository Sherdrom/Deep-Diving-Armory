local events, patches = {}, {}
local now = 0
local timerQueue = {}
local warningMessages = {}
local warningBox

CLIENT = true
SERVER = true
GUI = {
    MessageBox = function(header, message)
        assert(header == "Deep-Diving-Armory")
        warningMessages[#warningMessages + 1] = message
        warningBox = { Closed = false }
        return warningBox
    end,
}

Timer = {
    GetTime = function() return now end,
    Wait = function(callback, delay)
        assert(type(callback) == "function")
        timerQueue[#timerQueue + 1] = {
            callback = callback,
            deadline = now + (delay or 0) / 1000,
        }
    end,
}

local function runDueTimers()
    local due = {}
    for index = #timerQueue, 1, -1 do
        if timerQueue[index].deadline <= now then
            due[#due + 1] = table.remove(timerQueue, index)
        end
    end
    for index = #due, 1, -1 do due[index].callback() end
end

local networkMessages, networkReceivers = {}, {}
Networking = {
    Start = function(identifier)
        local message = { identifier = identifier, values = {} }
        function message.WriteByte(value) message.values[#message.values + 1] = value end
        function message.WriteUInt16(value) message.values[#message.values + 1] = value end
        function message.WriteString(value) message.values[#message.values + 1] = value end
        function message.WriteBoolean(value) message.values[#message.values + 1] = value end
        return message
    end,
    Send = function(message, connection)
        networkMessages[#networkMessages + 1] = { message = message, connection = connection }
    end,
    Receive = function(identifier, callback) networkReceivers[identifier] = callback end,
}
Game = { IsMultiplayer = true }

InvSlotType = {
    Head = "Head",
    InnerClothes = "InnerClothes",
    OuterClothes = "OuterClothes",
    Headset = "Headset",
    Card = "Card",
    Bag = "Bag",
    LeftHand = "LeftHand",
    RightHand = "RightHand",
}
LimbType = { Head = "Head" }
CharacterTeamType = { None = 0, Team1 = 1, Team2 = 2 }
StatTypes = {
    None = "None",
    MovementSpeed = "MovementSpeed",
    RangedAttackSpeed = "RangedAttackSpeed",
    RangedSpreadReduction = "RangedSpreadReduction",
    ElectricalSkillBonus = "ElectricalSkillBonus",
    HelmSkillBonus = "HelmSkillBonus",
    MechanicalSkillBonus = "MechanicalSkillBonus",
    MedicalSkillBonus = "MedicalSkillBonus",
    WeaponsSkillBonus = "WeaponsSkillBonus",
}
AbilityFlags = { SharedFlag = "SharedFlag", DynamicFlag = "DynamicFlag" }
Identifier = function(value) return value end

Hook = { HookMethodType = { After = "After" } }
function Hook.Add(name, _, callback) events[name] = callback end
function Hook.Patch(_, className, methodName, parameterTypes, callback, patchType)
    if type(parameterTypes) == "function" then
        patchType = callback
        callback = parameterTypes
        parameterTypes = nil
    end
    assert(className == "Barotrauma.Item"
        or className == "Barotrauma.Character"
        or className == "Barotrauma.Items.Components.Wearable"
        or className == "Barotrauma.Items.Components.ItemContainer"
        or className == "Barotrauma.Inventory")
    if className == "Barotrauma.Inventory" and (methodName == "ServerEventRead" or methodName == "PutItem") then
        assert(parameterTypes == nil, "inventory hook must use parameter-inference overload")
    end
    assert(patchType == Hook.HookMethodType.After)
    patches[className .. "." .. methodName] = callback
end

local markerPrefab = { id = "marker", Duration = 1 }
function markerPrefab:Instantiate(strength)
    return { id = self.id, Strength = strength, Duration = self.Duration }
end
local permanentMarkerPrefab = { id = "permanent_marker", Duration = 0 }
function permanentMarkerPrefab:Instantiate(strength)
    return { id = self.id, Strength = strength, Duration = self.Duration }
end
local function makeLegacyPrefab(identifier)
    local prefab = { id = identifier, Identifier = identifier, Duration = 0 }
    function prefab:Instantiate(strength)
        return {
            id = self.id,
            Identifier = self.Identifier,
            Prefab = self,
            Strength = strength,
            Duration = self.Duration,
        }
    end
    return prefab
end
local legacyMarkerPrefab = makeLegacyPrefab("legacy_marker")
local legacySemiPrefab = makeLegacyPrefab("deep_Semi")
local legacyBurstPrefab = makeLegacyPrefab("deep_Burst")
AfflictionPrefab = {
    Prefabs = {
        marker = markerPrefab,
        permanent_marker = permanentMarkerPrefab,
        legacy_marker = legacyMarkerPrefab,
        deep_Semi = legacySemiPrefab,
        deep_Burst = legacyBurstPrefab,
    },
}
ItemPrefab = { GetItemPrefab = function() return true end }

_G.AdjustEquipmentConfig = {
    fallbackInterval = 2.0,
    dynamicInterval = 0.5,
    wearableSlots = { InvSlotType.Head, InvSlotType.OuterClothes, InvSlotType.Bag },
    weaponSlots = { InvSlotType.LeftHand, InvSlotType.RightHand },
    mainItems = {
        armor = {
            stats = {
                { statType = "MovementSpeed", value = 2 },
                { statType = "MovementSpeed", value = 3 },
            },
            flags = { "SharedFlag" },
            talentMarkers = { "talent_marker" },
            affliction = { id = "marker", strength = 1 },
        },
        helmet = {
            stats = { { statType = "MovementSpeed", value = 7 } },
            flags = { "SharedFlag" },
            talentMarkers = { "talent_marker" },
            affliction = { id = "marker", strength = 1 },
        },
        bagweapon = {
            stats = { { statType = "MovementSpeed", value = -0.2 } },
        },
    },
    subItems = {
        module = {
            stats = { { statType = "MovementSpeed", value = 1 } },
            flags = { "SharedFlag" },
            resistances = { { id = "burn", multiplier = 0.5 } },
        },
        plate = {
            stats = { { statType = "MovementSpeed", value = -4 } },
            statGroup = "plateDebuff",
        },
        defender = {
            blocksStatGroups = { "plateDebuff" },
        },
    },
    weaponAccessories = {
        optic = {
            effects = {
                { statsKey = "optic", stats = { { statType = "MovementSpeed", value = 4 } } },
                { talentMarkers = { "weapon_marker" } },
            },
        },
        blockedoptic = {
            blockedByEnemyResistance = true,
            stats = { { statType = "MovementSpeed", value = 9 } },
        },
        grip_a = { resistances = { { id = "stun", multiplier = 0.7, source = "grip_a" } } },
        grip_b = { resistances = { { id = "stun", multiplier = 0.8, source = "grip_b" } } },
        nested_dynamic = {
            pollInterval = 0.9,
            when = function(character, host, accessory)
                character.accessoryChecks = character.accessoryChecks + 1
                return host.Condition < 1
                    and accessory.OwnInventory:FindItemByTag("dynamic_ammo", false) ~= nil
            end,
            statsKey = "nested_dynamic",
            stats = { { statType = "MovementSpeed", value = 8 } },
            talentMarkers = { "nested_marker" },
        },
    },
    heldWeapons = {
        none_weapon = {
            stats = {
                { statType = "RangedAttackSpeed", value = 0.3 },
                { statType = "RangedSpreadReduction", value = 0.25 },
            },
        },
        integrated = { talentMarkers = { "weapon_marker" } },
        failedweapon = { affliction = { id = "permanent_marker", strength = 1 } },
        dynamicweapon = {
            blockedByEnemyResistance = true,
            when = function(character)
                character.dynamicChecks = character.dynamicChecks + 1
                return character.dynamicActive
            end,
            statsKey = "dynamicweapon",
            stats = { { statType = "MovementSpeed", value = 6 } },
            flags = { "DynamicFlag" },
            resistances = { { id = "damage", multiplier = 0.2, source = "dynamicweapon" } },
        },
        dynamicpair = {
            effects = {
                {
                    pollInterval = 0.5,
                    when = function(character)
                        character.pairSemiChecks = character.pairSemiChecks + 1
                        return character.pairSemiActive
                    end,
                    statsKey = "pair_semi",
                    statGroup = "deep_Semi",
                    stats = { { statType = "MovementSpeed", value = 3 } },
                },
                {
                    pollInterval = 1.0,
                    when = function(character)
                        character.pairBurstChecks = character.pairBurstChecks + 1
                        return character.pairBurstActive
                    end,
                    statsKey = "pair_burst",
                    blocksStatGroups = { "deep_Semi" },
                    stats = { { statType = "MovementSpeed", value = 5 } },
                },
            },
        },
    },
    legacyAfflictions = {
        legacy_marker = {
            timeout = 2.0,
            stats = { { statType = "MovementSpeed", value = 13 } },
        },
        deep_Semi = {
            timeout = 2.0,
            statsKey = "legacy_semi",
            statGroup = "deep_Semi",
            stats = { { statType = "MovementSpeed", value = 3 } },
        },
        deep_Burst = {
            timeout = 1.0,
            statsKey = "legacy_burst",
            blocksStatGroups = { "deep_Semi" },
            stats = { { statType = "MovementSpeed", value = 5 } },
        },
    },
}

local function makeItem(identifier)
    local item = {
        Prefab = { Identifier = identifier },
        Removed = false,
        contents = {},
        inventoryScans = 0,
        tags = {},
        components = {},
        Condition = 100,
        Speed = 0,
        findByTagCalls = 0,
    }
    function item.HasTag(tag) return item.tags[tag] == true end
    function item.GetComponentString(component) return item.components[component] end
    function item:GetRootInventoryOwner() return self.rootOwner end
    local inventory = {}
    function inventory:FindItemByTag(tag)
        item.findByTagCalls = item.findByTagCalls + 1
        for _, contained in ipairs(item.contents) do
            if contained.HasTag(tag) then return contained end
        end
    end
    item.OwnInventory = setmetatable(inventory, {
        __index = function(_, key)
            if key ~= "AllItems" then return nil end
            item.inventoryScans = item.inventoryScans + 1
            local index = 0
            return function()
                index = index + 1
                return item.contents[index]
            end
        end,
    })
    function inventory:GetItemAt(index) return item.contents[index + 1] end
    return item
end

local slots = {}
local health = { afflictions = {} }
function health:GetAfflictionStrengthByIdentifier(id)
    local affliction = self.afflictions[id]
    return affliction and affliction.Strength or 0
end
function health:GetAffliction(id) return self.afflictions[id] end
function health:ApplyAffliction(_, affliction)
    if self.failNextAffliction == affliction.id then
        self.failNextAffliction = nil
        return
    end
    local existing = self.afflictions[affliction.id]
    if existing then
        existing.Strength = existing.Strength + affliction.Strength
    else
        self.afflictions[affliction.id] = affliction
    end
    local callback = events["character.applyAffliction"]
    if callback then callback(self, nil, affliction) end
end
function health:ReduceAfflictionOnAllLimbs(id, amount)
    local affliction = self.afflictions[id]
    if affliction then affliction.Strength = math.max(0, affliction.Strength - amount) end
end

local character = {
    ID = 1,
    Name = "test",
    TeamID = CharacterTeamType.None,
    Removed = false,
    IsDead = false,
    stats = {},
    nativeWearableStats = {},
    flags = {},
    addFlagCalls = 0,
    removeFlagCalls = 0,
    resistances = {},
    addResistanceCalls = 0,
    removeResistanceCalls = 0,
    dynamicActive = false,
    dynamicChecks = 0,
    pairSemiActive = false,
    pairBurstActive = false,
    pairSemiChecks = 0,
    pairBurstChecks = 0,
    accessoryChecks = 0,
    Info = {
        TeamID = CharacterTeamType.None,
        savedStats = { talent_marker = 1, weapon_marker = 1, nested_marker = 1 },
        changeCalls = 0,
    },
    CharacterHealth = health,
    Inventory = {},
    AnimController = {},
}
health.Character = character
function character.Inventory:GetItemInLimbSlot(slot) return slots[slot] end
character.Inventory.Owner = character
function character.AnimController:GetLimb() return {} end
function character.Info:GetSavedStatValue(_, id) return self.savedStats[id] or 0 end
function character.Info:ChangeSavedStatValue(_, value, id)
    self.changeCalls = self.changeCalls + 1
    self.savedStats[id] = value
end
function character:ChangeStat(statType, value)
    self.stats[statType] = (self.stats[statType] or 0) + value
end
function character:OnWearablesChanged()
    self.nativeWearableStats = {}
    for _, slot in ipairs({ InvSlotType.Head, InvSlotType.OuterClothes, InvSlotType.Bag }) do
        local item = slots[slot]
        local wearable = item and item.GetComponentString("Wearable")
        for statType, value in pairs(wearable and wearable.WearableStatValues or {}) do
            self.nativeWearableStats[statType] = (self.nativeWearableStats[statType] or 0) + value
        end
    end
end
function character:GetEffectiveStat(statType)
    local value = (self.stats[statType] or 0) + (self.nativeWearableStats[statType] or 0)
    local seen = {}
    for _, slot in ipairs({ InvSlotType.LeftHand, InvSlotType.RightHand }) do
        local item = slots[slot]
        if item and not seen[item] then
            seen[item] = true
            local holdable = item.GetComponentString("Holdable")
            value = value + ((holdable and holdable.HoldableStatValues[statType]) or 0)
        end
    end
    return value
end
function character:HasAbilityFlag(flag) return self.flags[flag] == true end
function character:AddAbilityFlag(flag)
    self.addFlagCalls = self.addFlagCalls + 1
    self.flags[flag] = true
end
function character:RemoveAbilityFlag(flag)
    self.removeFlagCalls = self.removeFlagCalls + 1
    self.flags[flag] = nil
end
LuaUserData = {
    CreateStatic = function(typeName, addCallConstructor)
        assert(typeName == "Barotrauma.TalentResistanceIdentifier" and addCallConstructor)
        return function(resistanceId, sourceId) return resistanceId .. "|" .. sourceId end
    end,
    IsTargetType = function(value, typeName)
        return (typeName == "Barotrauma.Character" and value == character)
            or (typeName == "Barotrauma.HumanoidAnimController" and value == character.AnimController)
    end,
}

Character = { CharacterList = { character }, Controlled = character }

local noneArmor, noneModule = makeItem("armor"), makeItem("module")
noneArmor.rootOwner = character
noneArmor.contents = { noneModule }
slots[InvSlotType.OuterClothes] = noneArmor

dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue.lua")
events.loaded()
assert(character.Info.savedStats.talent_marker == 0, "saved talent marker was not reset on load")
assert(character.Info.savedStats.weapon_marker == 0, "saved weapon marker was not reset on load")
assert(character.Info.savedStats.nested_marker == 0, "saved nested marker was not reset on load")
local markerChangeBaseline = character.Info.changeCalls

local function approximately(actual, expected)
    return math.abs((actual or 0) - expected) < 0.000001
end

local function assertNoEquipmentEffects(context)
    assert(approximately(character.stats.MovementSpeed, 0), context .. " applied stats")
    assert(approximately(character.stats.RangedAttackSpeed, 0),
        context .. " applied weapon operation stats")
    assert(approximately(character.stats.RangedSpreadReduction, 0),
        context .. " applied weapon spread stats")
    assert(approximately(character.stats.WeaponsSkillBonus, 0),
        context .. " applied weapon skill stats")
    assert(not character.flags.SharedFlag, context .. " applied flags")
    assert(character.Info.savedStats.talent_marker == 0, context .. " applied talent markers")
    assert(not character.resistances["burn|dda_adjust_equipment"], context .. " applied resistance")
    assert(health:GetAfflictionStrengthByIdentifier("marker") == 0, context .. " applied affliction")
end

assertNoEquipmentEffects("Team.None initial scan")
assert(noneArmor.inventoryScans == 0, "Team.None initial scan read equipment contents")

local function tick()
    now = now + 0.5
    events.think()
    runDueTimers()
end
local function advanceTime(seconds)
    now = now + seconds
    runDueTimers()
end
function character:ChangeAbilityResistance(key, multiplier)
    self.addResistanceCalls = self.addResistanceCalls + 1
    self.resistances[key] = multiplier
end
function character:RemoveAbilityResistance(key)
    self.removeResistanceCalls = self.removeResistanceCalls + 1
    self.resistances[key] = nil
end
character.talents = {}
function character:HasTalent(identifier) return self.talents[identifier] == true end

local armor, helmet = makeItem("armor"), makeItem("helmet")
local module1, module2 = makeItem("module"), makeItem("module")
armor.rootOwner, helmet.rootOwner = character, character

local equip = patches["Barotrauma.Item.Equip"]
local unequip = patches["Barotrauma.Item.Unequip"]
local itemContained = patches["Barotrauma.Items.Components.ItemContainer.OnItemContained"]
local itemRemoved = patches["Barotrauma.Items.Components.ItemContainer.OnItemRemoved"]
local revive = patches["Barotrauma.Character.Revive"]
local characterRemove = patches["Barotrauma.Character.Remove"]
local serverInventoryRead = patches["Barotrauma.Inventory.ServerEventRead"]
local clientApplyReceivedState = patches["Barotrauma.Inventory.ApplyReceivedState"]
local putItem = patches["Barotrauma.Inventory.PutItem"]
local removeItem = patches["Barotrauma.Inventory.RemoveItem"]
local teamChanged = patches["Barotrauma.Character.set_TeamID"]
local armorContainer = { Item = armor }
assert(characterRemove and serverInventoryRead and clientApplyReceivedState and putItem and removeItem and teamChanged,
    "authority hooks were not registered")

local function setTeam(team)
    character.TeamID = team
    character.Info.TeamID = team
end

equip(noneArmor, { character = character })
assertNoEquipmentEffects("Team.None equip")
assert(noneArmor.inventoryScans == 0, "Team.None equip read equipment contents")

local noneBag, noneWeapon = makeItem("bagweapon"), makeItem("none_weapon")
noneBag.rootOwner, noneWeapon.rootOwner = character, character
slots[InvSlotType.Bag], slots[InvSlotType.LeftHand] = noneBag, noneWeapon
equip(noneBag, { character = character })
equip(noneWeapon, { character = character })
assertNoEquipmentEffects("Team.None bag and held weapon equip")

setTeam(CharacterTeamType.Team1)
teamChanged(character, { value = character.TeamID })
assert(approximately(character.stats.MovementSpeed, 5.8)
    and approximately(character.stats.RangedAttackSpeed, 0.3)
    and approximately(character.stats.RangedSpreadReduction, 0.25)
    and character.flags.SharedFlag
    and character.Info.savedStats.talent_marker == 1
    and character.resistances["burn|dda_adjust_equipment"] == 0.5
    and health:GetAfflictionStrengthByIdentifier("marker") == 1,
    "non-None team did not receive armor, bag and weapon effects")

setTeam(CharacterTeamType.None)
teamChanged(character, { value = character.TeamID })
assertNoEquipmentEffects("Team.None transition")

slots[InvSlotType.Bag], slots[InvSlotType.LeftHand] = nil, nil
unequip(noneBag, { character = character })
unequip(noneWeapon, { character = character })

local nativeBag, nativeHeld = makeItem("native_bag"), makeItem("native_held")
nativeBag.Prefab.ContentPackage = { Name = "Deep-Diving-Armory" }
nativeBag.components.Wearable = {
    WearableStatValues = { [StatTypes.MovementSpeed] = -0.3 },
    SkillModifiers = { weapons = -20 },
}
nativeHeld.Prefab.ContentPackage = { Name = "Deep-Diving-Armory" }
nativeHeld.components.Holdable = {
    HoldableStatValues = {
        [StatTypes.MovementSpeed] = -0.2,
        [StatTypes.RangedSpreadReduction] = 0.4,
    },
}
nativeBag.rootOwner, nativeHeld.rootOwner = character, character
slots[InvSlotType.Bag], slots[InvSlotType.LeftHand] = nativeBag, nativeHeld
character:OnWearablesChanged()
equip(nativeBag, { character = character })
equip(nativeHeld, { character = character })
assert(approximately(character.stats.MovementSpeed, 0.5)
    and approximately(character.stats.WeaponsSkillBonus, 20)
    and approximately(character.stats.RangedSpreadReduction, -0.4),
    "Team.None did not compensate native wearable and holdable values")
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0)
    and approximately(character:GetEffectiveStat(StatTypes.RangedSpreadReduction), 0),
    "Team.None native equipment was not numerically neutral")

setTeam(CharacterTeamType.Team1)
teamChanged(character, { value = character.TeamID })
assert(approximately(character.stats.MovementSpeed, 6)
    and approximately(character.stats.WeaponsSkillBonus, 0)
    and approximately(character.stats.RangedSpreadReduction, 0),
    "non-None transition retained native equipment compensation")
setTeam(CharacterTeamType.None)
teamChanged(character, { value = character.TeamID })
assert(approximately(character.stats.MovementSpeed, 0.5)
    and approximately(character.stats.WeaponsSkillBonus, 20)
    and approximately(character.stats.RangedSpreadReduction, -0.4),
    "Team.None transition did not restore native equipment compensation")

slots[InvSlotType.Bag] = nil
putItem({ Owner = makeItem("container") }, { item = nativeBag })
assert(approximately(character.stats.MovementSpeed, 0.2)
    and approximately(character.stats.WeaponsSkillBonus, 0)
    and approximately(character.stats.RangedSpreadReduction, -0.4),
    "moving a native bag directly to a container left its compensation behind")
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0),
    "moving a Team.None native bag left its wearable stat cached")
unequip(nativeBag, { character = character })
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0),
    "Team.None native bag Unequip changed effective movement")
slots[InvSlotType.LeftHand] = nil
putItem({ Owner = makeItem("container") }, { item = nativeHeld })
unequip(nativeHeld, { character = character })
assertNoEquipmentEffects("Team.None native equipment removal")
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0)
    and approximately(character:GetEffectiveStat(StatTypes.RangedSpreadReduction), 0),
    "Team.None native equipment removal changed effective stats")

slots[InvSlotType.Bag] = nativeBag
character:OnWearablesChanged()
equip(nativeBag, { character = character })
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0),
    "Team.None native bag drop baseline was not neutral")
unequip(nativeBag, { character = character })
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0),
    "early Item.Unequip changed Team.None native bag movement")
slots[InvSlotType.Bag] = nil
removeItem(character.Inventory, { item = nativeBag })
assertNoEquipmentEffects("Team.None native equipment RemoveItem")
assert(approximately(character:GetEffectiveStat(StatTypes.MovementSpeed), 0),
    "dropping Team.None native equipment left a negative stat")

slots[InvSlotType.OuterClothes] = nil
setTeam(CharacterTeamType.Team1)
teamChanged(character, { value = character.TeamID })

slots[InvSlotType.Bag] = noneBag
equip(noneBag, { character = character })
assert(character.stats.MovementSpeed == -0.2, "Team1 bag baseline failed")
events["character.created"](character)
character.Info.TeamID = CharacterTeamType.None
advanceTime(0.01)
assertNoEquipmentEffects("Info.TeamID-only None transition")
slots[InvSlotType.Bag] = nil
unequip(noneBag, { character = character })
setTeam(CharacterTeamType.Team1)
teamChanged(character, { value = character.TeamID })
character.addFlagCalls, character.removeFlagCalls = 0, 0
character.addResistanceCalls, character.removeResistanceCalls = 0, 0
markerChangeBaseline = character.Info.changeCalls

local legacyNetworkId = "DDA.AdjustEquipment.LegacyAffliction"
local legacyApply = events["character.applyAffliction"]
assert(legacyApply and networkReceivers[legacyNetworkId], "legacy bridge hooks were not registered")
local legacyNetworkBaseline = #networkMessages
local legacyTimerBaseline = #timerQueue
local legacyStatBaseline = character.stats.MovementSpeed or 0
local legacyPrefab = AfflictionPrefab.Prefabs.legacy_marker

health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
assert(character.stats.MovementSpeed == legacyStatBaseline + 13,
    "legacy Affliction did not apply its configured effect")
assert(#timerQueue == legacyTimerBaseline + 1, "legacy Affliction did not arm one expiry timer")
assert(#networkMessages == legacyNetworkBaseline + 1
    and networkMessages[#networkMessages].message.values[1] == 1
    and networkMessages[#networkMessages].message.values[2] == character.ID
    and networkMessages[#networkMessages].message.values[3] == "legacy_marker"
    and networkMessages[#networkMessages].message.values[4] == true,
    "legacy activation did not send one active transition")

advanceTime(1.0)
health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
assert(character.stats.MovementSpeed == legacyStatBaseline + 13,
    "legacy duplicate Affliction reapplied or stacked its effect")
assert(#timerQueue == legacyTimerBaseline + 1
    and #networkMessages == legacyNetworkBaseline + 1,
    "legacy duplicate Affliction armed or notified twice")
advanceTime(1.1)
assert(character.stats.MovementSpeed == legacyStatBaseline + 13
    and #timerQueue == legacyTimerBaseline + 1,
    "legacy duplicate Affliction did not extend its deadline")
advanceTime(1.0)
assert(character.stats.MovementSpeed == legacyStatBaseline
    and #timerQueue == legacyTimerBaseline
    and #networkMessages == legacyNetworkBaseline + 2
    and networkMessages[#networkMessages].message.values[1] == 1
    and networkMessages[#networkMessages].message.values[4] == false,
    "legacy Affliction did not expire and send one inactive transition")

health:ApplyAffliction(nil, { id = "unknown_legacy", Identifier = "unknown_legacy", Strength = 1 })
health:ApplyAffliction(nil, legacyPrefab:Instantiate(0))
assert(character.stats.MovementSpeed == legacyStatBaseline
    and #timerQueue == legacyTimerBaseline
    and #networkMessages == legacyNetworkBaseline + 2,
    "zero-strength or unknown legacy Affliction activated")

setTeam(CharacterTeamType.None)
health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
assert(character.stats.MovementSpeed == legacyStatBaseline
    and #timerQueue == legacyTimerBaseline
    and #networkMessages == legacyNetworkBaseline + 2,
    "Team.None legacy Affliction activated")
setTeam(CharacterTeamType.Team1)

health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
assert(#timerQueue == legacyTimerBaseline + 1
    and #networkMessages == legacyNetworkBaseline + 3,
    "legacy Affliction did not reactivate after expiry")
character.IsDead = true
events["character.death"](character)
assert(character.stats.MovementSpeed == legacyStatBaseline
    and #networkMessages == legacyNetworkBaseline + 4,
    "death did not clear the legacy effect")
advanceTime(2.1)
assert(#timerQueue == legacyTimerBaseline
    and character.stats.MovementSpeed == legacyStatBaseline
    and #networkMessages == legacyNetworkBaseline + 4,
    "old legacy expiry timer was not a no-op after death")

character.IsDead = false
health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
assert(#timerQueue == legacyTimerBaseline + 1
    and #networkMessages == legacyNetworkBaseline + 5,
    "legacy Affliction did not reactivate after death")
character.Removed = true
characterRemove(character, {})
assert(character.stats.MovementSpeed == legacyStatBaseline
    and #networkMessages == legacyNetworkBaseline + 6,
    "Remove did not clear the legacy effect")
advanceTime(2.1)
assert(#timerQueue == legacyTimerBaseline
    and character.stats.MovementSpeed == legacyStatBaseline
    and #networkMessages == legacyNetworkBaseline + 6,
    "old legacy expiry timer was not a no-op after Remove")
character.Removed = false

health:ApplyAffliction(nil, legacyPrefab:Instantiate(1))
local networkBeforeSnapshot = #networkMessages
local snapshotConnection = {}
local serverLegacyReceive = networkReceivers[legacyNetworkId]
serverLegacyReceive({ ReadByte = function() return 0 end }, { Connection = snapshotConnection })
assert(#networkMessages == networkBeforeSnapshot + 1
    and networkMessages[#networkMessages].connection == snapshotConnection
    and networkMessages[#networkMessages].message.values[1] == 2
    and networkMessages[#networkMessages].message.values[2] == 1
    and networkMessages[#networkMessages].message.values[3] == character.ID
    and networkMessages[#networkMessages].message.values[4] == "legacy_marker",
    "server legacy request did not return a snapshot")
serverLegacyReceive({ ReadByte = function() return 0 end }, { Connection = snapshotConnection })
assert(#networkMessages == networkBeforeSnapshot + 1,
    "server legacy snapshot request was not rate-limited")
serverLegacyReceive({ ReadByte = function() return 1 end }, { Connection = snapshotConnection })
assert(#networkMessages == networkBeforeSnapshot + 1,
    "server legacy receiver accepted a non-request operation")
serverLegacyReceive({ LengthBits = 0, BitPosition = 0 }, { Connection = snapshotConnection })
assert(#networkMessages == networkBeforeSnapshot + 1,
    "server legacy receiver accepted an empty request")
character.IsDead = true
events["character.death"](character)
advanceTime(2.1)
character.IsDead = false
character.Removed = false
revive(character, { removeAfflictions = true, createNetworkEvent = false })

local semiPrefab = AfflictionPrefab.Prefabs.deep_Semi
local burstPrefab = AfflictionPrefab.Prefabs.deep_Burst
health:ApplyAffliction(nil, semiPrefab:Instantiate(1))
assert(character.stats.MovementSpeed == legacyStatBaseline + 3,
    "legacy Semi did not apply its stat-group effect")
advanceTime(0.5)
health:ApplyAffliction(nil, burstPrefab:Instantiate(1))
assert(character.stats.MovementSpeed == legacyStatBaseline + 5,
    "legacy Burst did not block the active legacy Semi group")
health:ApplyAffliction(nil, semiPrefab:Instantiate(1))
advanceTime(1.1)
assert(character.stats.MovementSpeed == legacyStatBaseline + 3,
    "legacy Semi did not restore when legacy Burst expired")
advanceTime(0.9)
assert(character.stats.MovementSpeed == legacyStatBaseline,
    "legacy Semi remained active after its refreshed deadline")
now = 0

local vanillaGun = makeItem("vanilla_gun")
vanillaGun.tags.gun = true
vanillaGun.components.RangedWeapon = {}
vanillaGun.rootOwner = character
slots[InvSlotType.LeftHand] = vanillaGun
equip(vanillaGun, { character = character })
assert(#warningMessages == 0, "vanilla DDA weapon triggered the VCE warning")

local vceGun = makeItem("vce_gun")
vceGun.tags.gun = true
vceGun.components.RangedWeapon = {}
vceGun.rootOwner = character
slots[InvSlotType.LeftHand] = vceGun
equip(vceGun, { character = character })
assert(#warningMessages == 0, "installed VCE triggered the VCE warning")

local missingVceGun = makeItem("missing_vce_gun")
missingVceGun.tags.gun = true
missingVceGun.rootOwner = character
slots[InvSlotType.LeftHand] = missingVceGun
equip(missingVceGun, { character = character })
equip(missingVceGun, { character = character })
assert(#warningMessages == 1, "simultaneous equip opened duplicate VCE warnings")
warningBox.Closed = true
equip(missingVceGun, { character = character })
assert(#warningMessages == 2, "VCE warning did not reopen after the previous box closed")
slots[InvSlotType.LeftHand] = nil

local nestedHost = makeItem("nested_host")
nestedHost.rootOwner = setmetatable({}, {
    __index = function(_, field) error("cannot access field " .. field .. " of userdata<Barotrauma.Item>") end,
})
assert(pcall(itemContained, { Item = nestedHost }, { containedItem = module1 }),
    "item-owned nested container was treated as a character")

slots[InvSlotType.OuterClothes] = armor
slots[InvSlotType.Head] = helmet
equip(armor, { character = character })
equip(helmet, { character = character })
assert(character.stats.MovementSpeed == 12, "simultaneous main items or duplicate stats failed")
assert(character.addFlagCalls == 1 and character.flags.SharedFlag, "flag reference counting failed")
assert(character.Info.savedStats.talent_marker == 1 and character.Info.changeCalls == markerChangeBaseline + 1,
    "talent marker reference counting failed")
assert(health:GetAfflictionStrengthByIdentifier("marker") == 1, "affliction reference counting failed")

health.afflictions.marker.Strength = 0.25
health.afflictions.marker.Duration = 0.25
tick()
assert(health.afflictions.marker.Strength == 0.25, "affliction refreshed before fallback interval")
for _ = 1, 3 do tick() end
assert(health.afflictions.marker.Strength == 1, "fallback did not repair lowered affliction")
assert(health.afflictions.marker.Duration == 4, "fallback did not maintain timed affliction")
health.afflictions.marker = nil
for _ = 1, 4 do tick() end
assert(health.afflictions.marker.Strength == 1, "fallback did not restore removed affliction")

armor.contents = { module1, module2 }
tick()
assert(character.stats.MovementSpeed == 12, "think still scanned contained items")
itemContained(armorContainer, { containedItem = module1 })
assert(character.stats.MovementSpeed == 14, "same-identifier subitems collapsed")
assert(character.resistances["burn|dda_adjust_equipment"] == 0.5 and character.addResistanceCalls == 1,
    "resistance reference counting failed")

armor.contents = { module2 }
tick()
assert(character.stats.MovementSpeed == 14, "think still scanned removed contained items")
itemRemoved(armorContainer, { containedItem = module1 })
assert(character.stats.MovementSpeed == 13, "subitem removal was not symmetric")
assert(character.resistances["burn|dda_adjust_equipment"] == 0.5 and character.removeResistanceCalls == 0,
    "shared resistance removed too early")

unequip(helmet, { character = character })
slots[InvSlotType.Head] = nil
assert(character.stats.MovementSpeed == 6 and character.flags.SharedFlag, "one main removed effects owned by another")
assert(character.Info.savedStats.talent_marker == 1 and character.Info.changeCalls == markerChangeBaseline + 1,
    "shared talent marker removed too early")
assert(health:GetAfflictionStrengthByIdentifier("marker") == 1, "shared affliction removed too early")

slots[InvSlotType.OuterClothes] = nil
unequip(armor, { character = character })
assert(character.stats.MovementSpeed == 0, "final main cleanup leaked stats")
assert(not character.flags.SharedFlag and character.removeFlagCalls == 1, "final flag cleanup failed")
assert(character.Info.savedStats.talent_marker == 0 and character.Info.changeCalls == markerChangeBaseline + 2,
    "final talent marker cleanup failed")
assert(not character.resistances["burn|dda_adjust_equipment"] and character.removeResistanceCalls == 1,
    "final resistance cleanup failed")
assert(health:GetAfflictionStrengthByIdentifier("marker") == 0, "final affliction cleanup failed")

slots[InvSlotType.OuterClothes] = armor
equip(armor, { character = character })
character.IsDead = true
events["character.death"](character)
assert(character.stats.MovementSpeed == 0 and health:GetAfflictionStrengthByIdentifier("marker") == 0, "death cleanup failed")

character.IsDead = false
tick()
assert(character.stats.MovementSpeed == 0, "think handled revive before the fallback interval")
revive(character, { removeAfflictions = true, createNetworkEvent = false })
assert(character.stats.MovementSpeed == 6 and health:GetAfflictionStrengthByIdentifier("marker") == 1, "revive event rescan failed")

character.IsDead = true
events["character.death"](character)
character.IsDead = false
for _ = 1, 4 do tick() end
assert(character.stats.MovementSpeed == 6 and health:GetAfflictionStrengthByIdentifier("marker") == 1, "revive fallback failed")

events.roundEnd()
assert(character.stats.MovementSpeed == 0 and health:GetAfflictionStrengthByIdentifier("marker") == 0, "round cleanup failed")

character.flags.SharedFlag = true
equip(armor, { character = character })
slots[InvSlotType.OuterClothes] = nil
unequip(armor, { character = character })
assert(character.flags.SharedFlag, "pre-existing external flag was removed")

local plate, defender = makeItem("plate"), makeItem("defender")
slots[InvSlotType.OuterClothes] = armor
armor.contents = { plate }
equip(armor, { character = character })
assert(character.stats.MovementSpeed == 1, "stat group baseline failed")
armor.contents = { plate, defender }
itemContained(armorContainer, { containedItem = defender })
assert(character.stats.MovementSpeed == 5, "stat group blocker did not remove active stats")
armor.contents = { plate }
itemRemoved(armorContainer, { containedItem = defender })
assert(character.stats.MovementSpeed == 1, "stat group blocker removal did not restore stats")
slots[InvSlotType.OuterClothes] = nil
unequip(armor, { character = character })
assert(character.stats.MovementSpeed == 0, "stat group cleanup leaked stats")

slots[InvSlotType.OuterClothes] = armor
armor.contents = { plate }
serverInventoryRead(character.Inventory, {})
assert(character.stats.MovementSpeed == 1, "server inventory reconcile did not apply the plate")
local armorScans = armor.inventoryScans
slots[InvSlotType.OuterClothes] = nil
tick()
assert(character.stats.MovementSpeed == 1, "tick unexpectedly reconciled an unequipped armor")
assert(armor.inventoryScans == armorScans, "tick scanned the armor inventory")
serverInventoryRead(character.Inventory, {})
assert(character.stats.MovementSpeed == 0, "server inventory reconcile did not remove the plate")
assert(armor.inventoryScans == armorScans, "inventory reconcile scanned the armor inventory")

slots[InvSlotType.OuterClothes] = armor
clientApplyReceivedState(character.Inventory, {})
assert(character.stats.MovementSpeed == 1, "client inventory reconcile did not apply the plate")
armorScans = armor.inventoryScans
slots[InvSlotType.OuterClothes] = nil
clientApplyReceivedState(character.Inventory, {})
assert(character.stats.MovementSpeed == 0, "client inventory reconcile did not remove the plate")
assert(armor.inventoryScans == armorScans, "client removal scanned the armor inventory")

local bagweapon = makeItem("bagweapon")
local bagoptic = makeItem("optic")
bagweapon.rootOwner = character
bagweapon.contents = { bagoptic }
slots[InvSlotType.LeftHand] = bagweapon
equip(bagweapon, { character = character })
assert(character.stats.MovementSpeed == 4, "held bag weapon did not apply only its accessory effect")
slots[InvSlotType.LeftHand] = nil
unequip(bagweapon, { character = character })
assert(character.stats.MovementSpeed == 0, "held bag weapon leaked accessory effects")
equip(bagweapon, { character = character })
assert(character.stats.MovementSpeed == 0, "bag effect applied while the item was not in the bag slot")
slots[InvSlotType.Bag] = bagweapon
equip(bagweapon, { character = character })
assert(character.stats.MovementSpeed == -0.2, "bag effect was not applied in the bag slot")
slots[InvSlotType.Bag] = nil
unequip(bagweapon, { character = character })
assert(character.stats.MovementSpeed == 0, "bag effect cleanup leaked stats")

local rifle1, rifle2 = makeItem("rifle1"), makeItem("rifle2")
local optic1, optic2 = makeItem("optic"), makeItem("optic")
rifle1.rootOwner, rifle2.rootOwner = character, character
rifle1.contents, rifle2.contents = { optic1 }, { optic2 }
slots[InvSlotType.LeftHand], slots[InvSlotType.RightHand] = rifle1, rifle2
equip(rifle1, { character = character })
equip(rifle1, { character = character })
equip(rifle2, { character = character })
assert(rifle1.inventoryScans == 1, "duplicate weapon equip rescanned its inventory")
assert(character.stats.MovementSpeed == 4, "shared accessory stats stacked while dual-wielding")
assert(character.Info.savedStats.weapon_marker == 1, "weapon marker reference counting failed")

local rifle1Scans, rifle2Scans = rifle1.inventoryScans, rifle2.inventoryScans
for _ = 1, 4 do tick() end
assert(rifle1.inventoryScans == rifle1Scans and rifle2.inventoryScans == rifle2Scans,
    "fallback scanned successfully applied weapon effects")

slots[InvSlotType.LeftHand] = nil
unequip(rifle1, { character = character })
assert(character.stats.MovementSpeed == 4 and character.Info.savedStats.weapon_marker == 1,
    "first weapon removal released shared accessory effects")

rifle2.contents = {}
itemRemoved({ Item = rifle2 }, { containedItem = optic2 })
assert(character.stats.MovementSpeed == 0 and character.Info.savedStats.weapon_marker == 0,
    "weapon accessory removal was not immediate")

rifle2.contents = { optic2 }
itemContained({ Item = rifle2 }, { containedItem = optic2 })
assert(character.stats.MovementSpeed == 4 and character.Info.savedStats.weapon_marker == 1,
    "weapon accessory insertion was not immediate")

rifle2.contents = {}
events["item.removed"](optic2)
events["item.removed"](optic2)
assert(character.stats.MovementSpeed == 0 and character.Info.savedStats.weapon_marker == 0,
    "indexed item removal was not immediate or idempotent")

slots[InvSlotType.RightHand] = nil
unequip(rifle2, { character = character })
assert(character.stats.MovementSpeed == 0 and character.Info.savedStats.weapon_marker == 0,
    "stowed weapon leaked accessory effects")

local gripWeapon1, gripWeapon2 = makeItem("gripWeapon1"), makeItem("gripWeapon2")
gripWeapon1.rootOwner, gripWeapon2.rootOwner = character, character
gripWeapon1.contents, gripWeapon2.contents = { makeItem("grip_a") }, { makeItem("grip_b") }
slots[InvSlotType.LeftHand], slots[InvSlotType.RightHand] = gripWeapon1, gripWeapon2
equip(gripWeapon1, { character = character })
equip(gripWeapon2, { character = character })
assert(character.resistances["stun|dda_adjust_equipment"] == 0.5,
    "different grip resistances were not combined")
slots[InvSlotType.LeftHand] = nil
unequip(gripWeapon1, { character = character })
assert(character.resistances["stun|dda_adjust_equipment"] == 0.8,
    "remaining grip resistance was not restored")
slots[InvSlotType.RightHand] = nil
unequip(gripWeapon2, { character = character })
assert(not character.resistances["stun|dda_adjust_equipment"], "grip resistance cleanup failed")

local blockedWeapon, blockedOptic = makeItem("blockedWeapon"), makeItem("blockedoptic")
blockedWeapon.rootOwner = character
blockedWeapon.contents = { blockedOptic }
health.afflictions.deep_enemy_affliction_resistance = { Strength = 1 }
slots[InvSlotType.LeftHand] = blockedWeapon
equip(blockedWeapon, { character = character })
assert(character.stats.MovementSpeed == 0, "enemy accessory resistance was bypassed")
local blockedWeaponScans = blockedWeapon.inventoryScans
health.afflictions.deep_enemy_affliction_resistance = nil
for _ = 1, 4 do tick() end
assert(character.stats.MovementSpeed == 9, "fallback did not restore an unblocked accessory effect")
health.afflictions.deep_enemy_affliction_resistance = { Strength = 1 }
for _ = 1, 4 do tick() end
assert(character.stats.MovementSpeed == 0, "fallback did not suppress a newly blocked accessory effect")
assert(blockedWeapon.inventoryScans == blockedWeaponScans,
    "conditional fallback scanned the weapon inventory")
slots[InvSlotType.LeftHand] = nil
unequip(blockedWeapon, { character = character })
health.afflictions.deep_enemy_affliction_resistance = nil

local failedWeapon = makeItem("failedweapon")
failedWeapon.rootOwner = character
health.failNextAffliction = "permanent_marker"
slots[InvSlotType.LeftHand] = failedWeapon
equip(failedWeapon, { character = character })
assert(health:GetAfflictionStrengthByIdentifier("permanent_marker") == 0,
    "failed affliction unexpectedly applied")
local failedWeaponScans = failedWeapon.inventoryScans
for _ = 1, 4 do tick() end
assert(health:GetAfflictionStrengthByIdentifier("permanent_marker") == 1,
    "failed effect was not repaired by fallback")
assert(failedWeapon.inventoryScans == failedWeaponScans,
    "failed effect repair scanned the weapon inventory")
slots[InvSlotType.LeftHand] = nil
unequip(failedWeapon, { character = character })
assert(health:GetAfflictionStrengthByIdentifier("permanent_marker") == 0,
    "repaired affliction leaked after unequip")

local integrated = makeItem("integrated")
integrated.rootOwner = character
slots[InvSlotType.LeftHand] = integrated
equip(integrated, { character = character })
assert(character.Info.savedStats.weapon_marker == 1, "held weapon marker was not applied")
putItem(character.Inventory, { item = integrated })
assert(character.Info.savedStats.weapon_marker == 1, "PutItem removed a weapon that was still held")
slots[InvSlotType.LeftHand] = nil
putItem({ Owner = makeItem("container") }, { item = integrated })
assert(character.Info.savedStats.weapon_marker == 0, "PutItem did not immediately remove a stowed weapon")
slots[InvSlotType.LeftHand] = integrated
equip(integrated, { character = character })
character.IsDead = true
events["character.death"](character)
assert(character.Info.savedStats.weapon_marker == 0, "death leaked held weapon marker")
character.IsDead = false
revive(character, { removeAfflictions = true, createNetworkEvent = false })
assert(character.Info.savedStats.weapon_marker == 1, "revive did not restore held weapon marker")
slots[InvSlotType.LeftHand] = nil
unequip(integrated, { character = character })
assert(character.Info.savedStats.weapon_marker == 0, "held weapon marker cleanup failed")

local dynamic1, dynamic2 = makeItem("dynamicweapon"), makeItem("dynamicweapon")
dynamic1.rootOwner, dynamic2.rootOwner = character, character
slots[InvSlotType.LeftHand], slots[InvSlotType.RightHand] = dynamic1, dynamic2
equip(dynamic1, { character = character })
equip(dynamic2, { character = character })
assert(character.stats.MovementSpeed == 0 and not character.flags.DynamicFlag,
    "inactive dynamic held effect applied on equip")
local dynamic1Scans, dynamic2Scans = dynamic1.inventoryScans, dynamic2.inventoryScans
character.dynamicActive = true
tick()
assert(character.stats.MovementSpeed == 6 and character.flags.DynamicFlag,
    "dynamic held effect did not activate")
assert(math.abs(character.resistances["damage|dda_adjust_equipment"] - 0.2) < 0.000001,
    "dynamic held resistance did not activate")
assert(dynamic1.inventoryScans == dynamic1Scans and dynamic2.inventoryScans == dynamic2Scans,
    "dynamic held check scanned weapon inventories")
character.dynamicActive = false
tick()
assert(character.stats.MovementSpeed == 0 and not character.flags.DynamicFlag,
    "dynamic held effect did not deactivate")
assert(not character.resistances["damage|dda_adjust_equipment"],
    "dynamic held resistance did not deactivate")
slots[InvSlotType.LeftHand], slots[InvSlotType.RightHand] = nil, nil
unequip(dynamic1, { character = character })
unequip(dynamic2, { character = character })
local dynamicChecks = character.dynamicChecks
character.dynamicActive = true
tick()
assert(character.dynamicChecks == dynamicChecks, "removed dynamic sources remained in think")

local pairWeapon = makeItem("dynamicpair")
pairWeapon.rootOwner = character
slots[InvSlotType.LeftHand] = pairWeapon
equip(pairWeapon, { character = character })
local pairSemiChecks, pairBurstChecks = character.pairSemiChecks, character.pairBurstChecks
character.pairSemiActive = true
tick()
assert(character.pairSemiChecks == pairSemiChecks + 1
    and character.pairBurstChecks == pairBurstChecks,
    "dynamic effects did not use independent poll intervals")
assert(character.stats.MovementSpeed == 3, "dynamic Semi effect did not activate")
character.pairBurstActive = true
tick()
assert(character.pairBurstChecks == pairBurstChecks + 1
    and character.stats.MovementSpeed == 5,
    "dynamic Burst did not immediately block the applied Semi group")
slots[InvSlotType.LeftHand] = nil
unequip(pairWeapon, { character = character })

local nestedWeapon, nestedAccessory, nestedAmmo = makeItem("nested_weapon"), makeItem("nested_dynamic"), makeItem("ammo")
nestedWeapon.rootOwner = character
nestedAccessory.rootOwner = setmetatable({}, {
    __index = function(_, field) error("cannot access field " .. field .. " of userdata<Barotrauma.Item>") end,
})
nestedAmmo.tags.dynamic_ammo = true
nestedWeapon.contents = { nestedAccessory }
nestedAccessory.contents = { nestedAmmo }
slots[InvSlotType.LeftHand] = nestedWeapon
equip(nestedWeapon, { character = character })
assert(character.stats.MovementSpeed == 0 and character.Info.savedStats.nested_marker == 0,
    "nested dynamic accessory ignored its host condition")
nestedWeapon.Condition = 0
itemContained({ Item = nestedAccessory }, { containedItem = nestedAmmo })
assert(character.stats.MovementSpeed == 8 and character.Info.savedStats.nested_marker == 1,
    "nested ammo insertion did not immediately refresh the top-level weapon")
local nestedWeaponScans = nestedWeapon.inventoryScans
local accessoryChecks = character.accessoryChecks
tick()
assert(character.accessoryChecks == accessoryChecks, "dynamic accessory ignored its poll interval")
tick()
assert(character.accessoryChecks == accessoryChecks + 1, "dynamic accessory was not polled when due")
assert(nestedWeapon.inventoryScans == nestedWeaponScans,
    "dynamic accessory polling scanned the top-level weapon inventory")
nestedAccessory.contents = {}
itemRemoved({ Item = nestedAccessory }, { containedItem = nestedAmmo })
assert(character.stats.MovementSpeed == 0 and character.Info.savedStats.nested_marker == 0,
    "nested ammo removal did not immediately clear the accessory effect")
slots[InvSlotType.LeftHand] = nil
unequip(nestedWeapon, { character = character })

Deep_Lua = { Path = "." }
_G.AdjustEquipmentConfig = nil
dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua")
local production = _G.AdjustEquipmentConfig
local function countEntries(values)
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end
local function hasTalentMarker(cfg, marker)
    for _, effect in ipairs(cfg.effects or { cfg }) do
        for _, value in ipairs(effect.talentMarkers or {}) do
            if value == marker then return true end
        end
    end
    return false
end
local function sameStats(left, right)
    if #(left.stats or {}) ~= #(right.stats or {}) then return false end
    for index, stat in ipairs(left.stats or {}) do
        local expected = right.stats[index]
        if not expected or stat.statType ~= expected.statType or stat.value ~= expected.value then return false end
    end
    return true
end
assert(countEntries(production.mainItems) == 68
    and countEntries(production.subItems) == 83
    and countEntries(production.weaponAccessories) == 72
        and countEntries(production.heldWeapons) == 117
        and countEntries(production.legacyAfflictions) == 18,
    "split production config lost or duplicated items")
assert(production.legacyAfflictions.deep_Semi
    and production.legacyAfflictions.deep_Burst
    and production.legacyAfflictions.deep_upgrade_tool_steel_tit_confirm_rifle
    and production.legacyAfflictions.deep_machinegun_crouch
    and production.legacyAfflictions.deep_sniper_aim_heavy
    and production.legacyAfflictions.deep_muffler
    and production.legacyAfflictions["8x_sight"]
    and production.legacyAfflictions.deepgun_inwater_detect == nil
    and production.legacyAfflictions.deep_VCE_none == nil
    and production.legacyAfflictions.deep_VCE_yes == nil,
    "legacy Affliction mappings or excluded markers changed")
local legacy = production.legacyAfflictions
assert(legacy.deep_Semi.timeout == 1.25
    and legacy.deep_Semi.stats[1].value == 0.3
    and legacy.deep_Burst.blocksStatGroups[1] == "deep_Semi"
    and legacy.deep_upgrade_tool_steel_tit_confirm_shotgun.stats[2].value == 0.1
    and legacy.deep_machinegun_crouch.when
    and #legacy.deep_sniper_aim_heavy.effects == 3
    and hasTalentMarker(legacy.deep_shotgun_damgage_balance, "deep_shotgun_damgage_balance")
    and hasTalentMarker(legacy.deep_machinegunner_light_detect, "deep_machinegunner_light_detect")
    and hasTalentMarker(legacy.deep_muffler, "deep_muffler"),
    "legacy Affliction effect profiles changed")
assert(sameStats(legacy.deep_Semi, production.heldWeapons.deep_AK12.effects[1])
    and sameStats(legacy.deep_Burst, production.heldWeapons.deep_m4.effects[2])
    and sameStats(legacy.deep_upgrade_tool_steel_tit_confirm_rifle,
        production.heldWeapons.deep_m4.effects[3])
    and sameStats(legacy.deep_machinegun_crouch, production.heldWeapons.deep_m249.effects[1])
    and sameStats(legacy.deep_sniper_aim_heavy.effects[1], production.heldWeapons.deep_m82a1.effects[1])
    and sameStats(legacy.deep_compensator, production.weaponAccessories.deep_compensator.effects[1])
    and sameStats(legacy.deep_muffler, production.weaponAccessories.deep_muffler.effects[1])
    and sameStats(legacy.extended_barrel, production.weaponAccessories.extended_barrel.effects[1])
    and sameStats(legacy["2x_sight"], production.weaponAccessories["2x_sight"])
    and sameStats(legacy["8x_sight"], production.weaponAccessories["8x_sight"]),
    "legacy Affliction stats drifted from current equipment profiles")
assert(production.mainItems.deep_hpc
    and production.dynamicInterval == 0.5
    and production.mainItems.deep_meteorite.stats[1].value == -0.2
    and production.subItems.deep_plate_metal_3.statGroup == "deep_plate_debuff"
    and production.subItems.chip_frogman.talentMarkers[1] == "chip_frogman_1"
    and production.subItems.chip_assistant_2.affliction[1].id == "chip_assistant_2"
    and production.weaponAccessories["8x_sight"].stats[1].value == 0.9
    and production.weaponAccessories.deep_762_expansion.stats[1].value == -15
    and production.weaponAccessories.deep_12shell.talentMarkers[1] == "deep_damage_fall_off_600_1200_detect"
    and production.weaponAccessories.chip_first_aid.flags[1] == "MoveNormallyWhileDragging"
    and production.weaponAccessories.cqr_grips.when
    and production.weaponAccessories.oblique_grips.when
    and #production.weaponAccessories.deep_flash_hider.effects == 2
    and #production.weaponAccessories.deep_compensator.effects == 2
    and #production.weaponAccessories.deep_sub_hanging_master_key.effects == 2
    and hasTalentMarker(production.weaponAccessories.deep_sub_hanging_master_key,
        "deep_shotgun_damgage_balance_12shell")
    and hasTalentMarker(production.heldWeapons.deep_g36c_roger, "chip_headshot_detect")
    and hasTalentMarker(production.heldWeapons.deep_m249, "deep_machinegunner_light_detect")
    and production.heldWeapons.deep_m249.effects[1].when
    and production.heldWeapons.deep_m249.effects[1].stats[1].value == 0.7
    and production.heldWeapons.deep_CZ75.effects[1].statsKey == "deep_pistol_mozambique_aff"
    and #production.heldWeapons.deep_m82a1.effects == 3
    and production.heldWeapons.deep_knife.effects[1].when
    and #production.heldWeapons.deep_wuchuan.effects == 2
    and production.heldWeapons.deep_pp19.effects[2].affliction.id == "deep_pp19_buffalo"
    and production.heldWeapons.deep_pp19.effects[2].blockedByEnemyResistance
    and production.heldWeapons.deep_AK12.effects[1].statsKey == "deep_Semi"
    and production.heldWeapons.deep_m4.effects[1].statGroup == "deep_Semi"
    and production.heldWeapons.deep_m4.effects[2].when
    and production.heldWeapons.deep_m4.effects[2].blocksStatGroups[1] == "deep_Semi"
    and production.heldWeapons.deep_AK12.effects[2].talentMarkers[1] == "deep_shotgun_damgage_balance"
    and production.heldWeapons.deep_doublebarrel.effects[1].talentMarkers[1] == "deep_shotgun_damgage_balance"
    and production.heldWeapons.deep_m4.effects[3].statsKey == "deep_upgrade_rifle"
    and production.heldWeapons.deep_m4.effects[3].pollInterval == 0.25
    and production.heldWeapons.deep_AK12.effects[2].pollInterval == 0.5
    and production.heldWeapons.deep_flash_handed_shield == nil,
    "split production config changed category data")

local switchableHost = makeItem("deep_AK12")
local switchableValues = {
    currentFireModeSelected = 1,
    currentProjectileSelected = 0,
}
local switchableProperties = {}
for field in pairs(switchableValues) do
    switchableProperties[field] = {
        GetValue = function() return switchableValues[field] end,
    }
end
switchableHost.components.RangedWeapon = { SerializableProperties = switchableProperties }
local switchableEffects = production.heldWeapons.deep_AK12.effects
assert(switchableEffects[1].when(character, switchableHost), "semi-auto mode condition changed")
switchableValues.currentFireModeSelected = 0
switchableValues.currentProjectileSelected = 1
assert(not switchableEffects[1].when(character, switchableHost), "semi-auto mode read projectile index")
switchableValues.currentFireModeSelected = 1
assert(switchableEffects[1].when(character, switchableHost), "semi-auto mode did not restore")
assert(not switchableEffects[2].when(character, switchableHost), "master-key condition ignored")
switchableHost.contents = { makeItem("other_mount"), makeItem("deep_sub_hanging_master_key") }
assert(switchableEffects[2].when(character, switchableHost), "master-key condition did not detect slot 1")

character.MaxVitality, character.Vitality = 100, 60
character.AnimController.Crouching = false
assert(not production.heldWeapons.deep_m249.effects[1].when(character),
    "held condition ignored the common talent")
character.talents.deep_talent_all = true
character.AnimController.Crouching = true
assert(production.heldWeapons.deep_m249.effects[1].when(character),
    "machine-gun crouch condition changed")
assert(not production.heldWeapons.deep_CZ75.effects[1].when(character),
    "pistol low-vitality condition activated too early")
character.Vitality = 50
assert(production.heldWeapons.deep_CZ75.effects[1].when(character),
    "pistol low-vitality boundary changed")
local sniperEffects = production.heldWeapons.deep_m82a1.effects
assert(sniperEffects[1].when(character) and sniperEffects[2].when(character)
    and not sniperEffects[3].when(character), "heavy-sniper vitality tiers changed")
assert(not production.heldWeapons.deep_knife.effects[1].when(character),
    "knife smoke condition activated without smoke")
health.afflictions.m18_smoke = { Strength = 1 }
assert(production.heldWeapons.deep_knife.effects[1].when(character),
    "knife smoke condition did not activate")
character.talents.deep_talent_all = nil
character.talents.deep_talent_elite_enemy = true
assert(production.heldWeapons.deep_wuchuan.effects[1].when(character),
    "elite Wuchuan talent condition changed")

local host, masterKey, shotgunAmmo = makeItem("host"), makeItem("deep_sub_hanging_master_key"), makeItem("shotgun_ammo")
character.CurrentHull = nil
assert(not production.weaponAccessories.cqr_grips.when(character), "CQR activated outside")
character.CurrentHull = {}
assert(production.weaponAccessories.cqr_grips.when(character), "CQR did not activate inside")
host.Condition = 1
assert(not production.weaponAccessories.oblique_grips.when(character, host),
    "oblique grip condition boundary changed")
host.Condition = 0.99
assert(production.weaponAccessories.oblique_grips.when(character, host),
    "oblique grip did not activate while reloading")
host.Speed = 1
assert(production.weaponAccessories.deep_flash_hider.effects[1].when(character, host)
    and not production.weaponAccessories.deep_compensator.effects[1].when(character, host),
    "muzzle speed boundary changed")
shotgunAmmo.tags.deep_round_shotgun_attenuation = true
masterKey.contents = { shotgunAmmo }
assert(production.weaponAccessories.deep_sub_hanging_master_key.effects[2].when(character, host, masterKey),
    "Master Key shotgun-ammo condition changed")

print("AdjustEquipmentStatvalue state check OK")
