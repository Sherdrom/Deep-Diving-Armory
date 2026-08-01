local events, patches = {}, {}
local now = 0

Timer = {
    GetTime = function() return now end,
}

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
StatTypes = { None = "None", MovementSpeed = "MovementSpeed" }
AbilityFlags = { SharedFlag = "SharedFlag" }
Identifier = function(value) return value end

Hook = { HookMethodType = { After = "After" } }
function Hook.Add(name, _, callback) events[name] = callback end
function Hook.Patch(_, className, methodName, _, callback, patchType)
    assert(className == "Barotrauma.Item"
        or className == "Barotrauma.Character"
        or className == "Barotrauma.Items.Components.Wearable"
        or className == "Barotrauma.Items.Components.ItemContainer")
    assert(patchType == Hook.HookMethodType.After)
    patches[className .. "." .. methodName] = callback
end

local markerPrefab = { id = "marker", Duration = 1 }
function markerPrefab:Instantiate(strength)
    return { id = self.id, Strength = strength, Duration = self.Duration }
end
AfflictionPrefab = { Prefabs = { marker = markerPrefab } }
ItemPrefab = { GetItemPrefab = function() return true end }

_G.AdjustEquipmentConfig = {
    fallbackInterval = 2.0,
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
    },
    heldWeapons = {
        integrated = { talentMarkers = { "weapon_marker" } },
    },
}

local function makeItem(identifier)
    local item = { Prefab = { Identifier = identifier }, Removed = false, contents = {} }
    function item:GetRootInventoryOwner() return self.rootOwner end
    item.OwnInventory = setmetatable({}, {
        __index = function(_, key)
            if key ~= "AllItemsMod" then return nil end
            local index = 0
            return function()
                index = index + 1
                return item.contents[index]
            end
        end,
    })
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
    local existing = self.afflictions[affliction.id]
    if existing then
        existing.Strength = existing.Strength + affliction.Strength
    else
        self.afflictions[affliction.id] = affliction
    end
end
function health:ReduceAfflictionOnAllLimbs(id, amount)
    local affliction = self.afflictions[id]
    if affliction then affliction.Strength = math.max(0, affliction.Strength - amount) end
end

local character = {
    Name = "test",
    Removed = false,
    IsDead = false,
    stats = {},
    flags = {},
    addFlagCalls = 0,
    removeFlagCalls = 0,
    resistances = {},
    addResistanceCalls = 0,
    removeResistanceCalls = 0,
    Info = { savedStats = { talent_marker = 1, weapon_marker = 1 }, changeCalls = 0 },
    CharacterHealth = health,
    Inventory = {},
    AnimController = {},
}
function character.Inventory:GetItemInLimbSlot(slot) return slots[slot] end
function character.AnimController:GetLimb() return {} end
function character.Info:GetSavedStatValue(_, id) return self.savedStats[id] or 0 end
function character.Info:ChangeSavedStatValue(_, value, id)
    self.changeCalls = self.changeCalls + 1
    self.savedStats[id] = value
end
function character:ChangeStat(statType, value)
    self.stats[statType] = (self.stats[statType] or 0) + value
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
        return typeName == "Barotrauma.Character" and value == character
    end,
}

Character = { CharacterList = { character } }

dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue.lua")
events.loaded()
assert(character.Info.savedStats.talent_marker == 0, "saved talent marker was not reset on load")
assert(character.Info.savedStats.weapon_marker == 0, "saved weapon marker was not reset on load")
local markerChangeBaseline = character.Info.changeCalls

local function tick()
    now = now + 0.5
    events.think()
end
function character:ChangeAbilityResistance(key, multiplier)
    self.addResistanceCalls = self.addResistanceCalls + 1
    self.resistances[key] = multiplier
end
function character:RemoveAbilityResistance(key)
    self.removeResistanceCalls = self.removeResistanceCalls + 1
    self.resistances[key] = nil
end

local armor, helmet = makeItem("armor"), makeItem("helmet")
local module1, module2 = makeItem("module"), makeItem("module")
armor.rootOwner, helmet.rootOwner = character, character

local equip = patches["Barotrauma.Item.Equip"]
local unequip = patches["Barotrauma.Item.Unequip"]
local itemContained = patches["Barotrauma.Items.Components.ItemContainer.OnItemContained"]
local itemRemoved = patches["Barotrauma.Items.Components.ItemContainer.OnItemRemoved"]
local revive = patches["Barotrauma.Character.Revive"]
local armorContainer = { Item = armor }

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
assert(character.stats.MovementSpeed == 4, "shared accessory stats stacked while dual-wielding")
assert(character.Info.savedStats.weapon_marker == 1, "weapon marker reference counting failed")

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
health.afflictions.deep_enemy_affliction_resistance = nil
for _ = 1, 4 do tick() end
assert(character.stats.MovementSpeed == 9, "fallback did not restore an unblocked accessory effect")
health.afflictions.deep_enemy_affliction_resistance = { Strength = 1 }
for _ = 1, 4 do tick() end
assert(character.stats.MovementSpeed == 0, "fallback did not suppress a newly blocked accessory effect")
slots[InvSlotType.LeftHand] = nil
unequip(blockedWeapon, { character = character })
health.afflictions.deep_enemy_affliction_resistance = nil

local integrated = makeItem("integrated")
integrated.rootOwner = character
slots[InvSlotType.LeftHand] = integrated
equip(integrated, { character = character })
assert(character.Info.savedStats.weapon_marker == 1, "held weapon marker was not applied")
character.IsDead = true
events["character.death"](character)
assert(character.Info.savedStats.weapon_marker == 0, "death leaked held weapon marker")
character.IsDead = false
revive(character, { removeAfflictions = true, createNetworkEvent = false })
assert(character.Info.savedStats.weapon_marker == 1, "revive did not restore held weapon marker")
slots[InvSlotType.LeftHand] = nil
unequip(integrated, { character = character })
assert(character.Info.savedStats.weapon_marker == 0, "held weapon marker cleanup failed")

Deep_Lua = { Path = "." }
_G.AdjustEquipmentConfig = nil
dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua")
local production = _G.AdjustEquipmentConfig
local function countEntries(values)
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end
assert(countEntries(production.mainItems) == 68
    and countEntries(production.subItems) == 80
    and countEntries(production.weaponAccessories) == 36
    and countEntries(production.heldWeapons) == 5,
    "split production config lost or duplicated items")
assert(production.mainItems.deep_hpc
    and production.mainItems.deep_meteorite.stats[1].value == -0.2
    and production.subItems.deep_plate_metal_3.statGroup == "deep_plate_debuff"
    and production.subItems.chip_frogman.talentMarkers[1] == "chip_frogman_1"
    and production.subItems.chip_assistant_2.affliction[1].id == "chip_assistant_2"
    and production.weaponAccessories["8x_sight"].stats[1].value == 0.9
    and production.weaponAccessories.chip_first_aid.flags[1] == "MoveNormallyWhileDragging"
    and production.heldWeapons.deep_g36c_roger.effects[2].talentMarkers[1] == "chip_headshot_detect",
    "split production config changed category data")

print("AdjustEquipmentStatvalue state check OK")
