-- Runs the production hooks with the smallest Barotrauma surface they need.
AdjustEquipmentConfig = {
    mainItems = {}, subItems = {}, weaponAccessories = {}, heldWeapons = {}, legacyAfflictions = {}
}
SERVER, CLIENT = true, false
Identifier = tostring
LuaUserData = {
    CreateStatic = function() return function() return {} end end,
    IsTargetType = function(value, typeName) return value.__type == typeName end,
}
InvSlotType = {
    Head = 1, InnerClothes = 2, OuterClothes = 3, Headset = 4,
    Card = 5, Bag = 6, LeftHand = 7, RightHand = 8,
}
CharacterTeamType = { None = 0 }
StatTypes = {
    None = "none", ElectricalSkillBonus = "electrical", HelmSkillBonus = "helm",
    MechanicalSkillBonus = "mechanical", MedicalSkillBonus = "medical", WeaponsSkillBonus = "weapons",
}

local callbacks = {}
local now = 0
Timer = { GetTime = function() return now end }
Hook = {
    HookMethodType = { After = "after", Before = "before" },
    Patch = function(name, ...)
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if type(value) == "function" then callbacks[name] = value end
        end
    end,
    Add = function(_, name, callback) callbacks[name] = callback end,
}

assert(loadfile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue.lua"))()
local putItem = assert(callbacks["AdjustEquipmentStatvalue.InventoryPutItem"])
local serverEventRead = assert(callbacks["AdjustEquipmentStatvalue.InventoryServerEventRead"])
local think = assert(callbacks["AdjustEquipmentStatvalue.Think"])

local character = {
    __type = "Barotrauma.Character", TeamID = CharacterTeamType.None,
    Removed = false, IsDead = false, wearableChanges = 0,
}
function character:OnWearablesChanged() self.wearableChanges = self.wearableChanges + 1 end
function character:ChangeStat() end
local inventory = { Owner = character, GetItemInLimbSlot = function() end }
character.Inventory = inventory

local function expect(expected, message)
    assert(character.wearableChanges == expected, message .. ": " .. character.wearableChanges)
end

putItem(inventory, { item = {} })
putItem(inventory, { item = {} })
expect(0, "PutItem ran synchronously")
think()
expect(1, "same-frame requests were not coalesced")

putItem(inventory, { item = {} })
think()
expect(2, "next-frame request was lost")

putItem(inventory, { item = {} })
serverEventRead(inventory)
expect(3, "server reconciliation did not synchronize immediately")
think()
expect(3, "immediate synchronization did not cancel pending work")

print("ok: production equipment sync hooks coalesce and cancel pending work")
