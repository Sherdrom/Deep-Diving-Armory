local events, patches = {}, {}

InvSlotType = {
    Head = "Head",
    InnerClothes = "InnerClothes",
    OuterClothes = "OuterClothes",
    Headset = "Headset",
    Card = "Card",
    Bag = "Bag",
}
LimbType = { Head = "Head" }
StatTypes = { MovementSpeed = "MovementSpeed" }
AbilityFlags = { SharedFlag = "SharedFlag" }

Hook = { HookMethodType = { After = "After" } }
function Hook.Add(name, _, callback) events[name] = callback end
function Hook.Patch(_, className, methodName, _, callback, patchType)
    assert(className == "Barotrauma.Item")
    assert(patchType == Hook.HookMethodType.After)
    patches[methodName] = callback
end

local markerPrefab = { id = "marker" }
function markerPrefab:Instantiate(strength) return { id = self.id, Strength = strength } end
AfflictionPrefab = { Prefabs = { marker = markerPrefab } }
ItemPrefab = { GetItemPrefab = function() return true end }

_G.AdjustEquipmentConfig = {
    checkInterval = 1 / 60,
    migratedItems = { armor = true, helmet = true },
    items = {
        armor = {
            IsMain = true,
            stats = {
                { statType = "MovementSpeed", value = 2 },
                { statType = "MovementSpeed", value = 3 },
            },
            flags = { "SharedFlag" },
            affliction = { id = "marker", strength = 1 },
        },
        helmet = {
            IsMain = true,
            stats = { { statType = "MovementSpeed", value = 7 } },
            flags = { "SharedFlag" },
            affliction = { id = "marker", strength = 1 },
        },
        module = {
            IsSub = true,
            stats = { { statType = "MovementSpeed", value = 1 } },
            flags = { "SharedFlag" },
        },
    },
}
_G.AdjustEquipmentSubConfigCache = { module = _G.AdjustEquipmentConfig.items.module }
_G.AdjustEquipmentWearableSlots = { InvSlotType.Head, InvSlotType.OuterClothes }

local function makeItem(identifier)
    local item = { Prefab = { Identifier = identifier }, Removed = false, contents = {} }
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
local health = { strengths = {} }
function health:GetAfflictionStrengthByIdentifier(id) return self.strengths[id] or 0 end
function health:ApplyAffliction(_, affliction)
    self.strengths[affliction.id] = (self.strengths[affliction.id] or 0) + affliction.Strength
end
function health:ReduceAfflictionOnAllLimbs(id, amount)
    self.strengths[id] = math.max(0, (self.strengths[id] or 0) - amount)
end

local character = {
    Name = "test",
    Removed = false,
    IsDead = false,
    stats = {},
    flags = {},
    addFlagCalls = 0,
    removeFlagCalls = 0,
    CharacterHealth = health,
    Inventory = {},
    AnimController = {},
}
function character.Inventory:GetItemInLimbSlot(slot) return slots[slot] end
function character.AnimController:GetLimb() return {} end
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

Character = { CharacterList = { character } }

dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue.lua")
events.loaded()

local armor, helmet = makeItem("armor"), makeItem("helmet")
local module1, module2 = makeItem("module"), makeItem("module")

slots[InvSlotType.OuterClothes] = armor
slots[InvSlotType.Head] = helmet
patches.Equip(armor, { character = character })
patches.Equip(helmet, { character = character })
assert(character.stats.MovementSpeed == 12, "simultaneous main items or duplicate stats failed")
assert(character.addFlagCalls == 1 and character.flags.SharedFlag, "flag reference counting failed")
assert(health.strengths.marker == 1, "affliction reference counting failed")

armor.contents = { module1, module2 }
events.think()
assert(character.stats.MovementSpeed == 14, "same-identifier subitems collapsed")

armor.contents = { module2 }
events.think()
assert(character.stats.MovementSpeed == 13, "subitem removal was not symmetric")

slots[InvSlotType.Head] = nil
patches.Unequip(helmet, { character = character })
assert(character.stats.MovementSpeed == 6 and character.flags.SharedFlag, "one main removed effects owned by another")
assert(health.strengths.marker == 1, "shared affliction removed too early")

slots[InvSlotType.OuterClothes] = nil
patches.Unequip(armor, { character = character })
assert(character.stats.MovementSpeed == 0, "final main cleanup leaked stats")
assert(not character.flags.SharedFlag and character.removeFlagCalls == 1, "final flag cleanup failed")
assert(health.strengths.marker == 0, "final affliction cleanup failed")

slots[InvSlotType.OuterClothes] = armor
patches.Equip(armor, { character = character })
character.IsDead = true
events["character.death"](character)
assert(character.stats.MovementSpeed == 0 and health.strengths.marker == 0, "death cleanup failed")

character.IsDead = false
for _ = 1, 31 do events.think() end
assert(character.stats.MovementSpeed == 6 and health.strengths.marker == 1, "revive rescan failed")

events.roundEnd()
assert(character.stats.MovementSpeed == 0 and health.strengths.marker == 0, "round cleanup failed")

character.flags.SharedFlag = true
patches.Equip(armor, { character = character })
slots[InvSlotType.OuterClothes] = nil
patches.Unequip(armor, { character = character })
assert(character.flags.SharedFlag, "pre-existing external flag was removed")

print("AdjustEquipmentStatvalue state check OK")
