-- Exercise the production adapter. Inventory movement is simulated; native swap rollback is tested in-game.
SERVER = false
Game = { IsMultiplayer = false }
local callback
Hook = { Add = function(_, _, fn) callback = fn end }
LuaUserData = { RegisterType = function() end, IsTargetType = function(value) return value.virtual end }
local package = {}
local reference = { ContentPackage = package, compatible = true }
ItemPrefab = { GetItemPrefab = function() return reference end }
assert(loadfile("Lua/Scripts/BenzeneTechnology/VirtualMagazineReload.lua"))()

local nextId = 0
local function item(count, compatible)
    nextId = nextId + 1
    local result = { ID = nextId, Prefab = { ContentPackage = package }, compatible = compatible ~= false }
    result.HasTag = function(tag) return tag == "556mag" and count ~= nil or tag == "weapon" and result.weapon end
    result.IsInteractable = function() return not result.blocked end
    if count then result.OwnInventory = { Container = { virtual = true, LoadedCount = count } } end
    return result
end

local function setup(current, reserve)
    local weapon = item()
    weapon.weapon = true
    local inventory = { current = current, calls = {}, AllItemsMod = {} }
    inventory.Container = { ContainedStateIndicatorSlot = 0, CanBeContained = function(value, slot)
        return slot == 0 and value.compatible
    end }
    inventory.GetItemAt = function() return inventory.current end
    inventory.TryPutItem = function(candidate, slot, swapping, combine, character, network, ignoreCondition)
        assert(slot == 0 and swapping and not combine and not ignoreCondition, "unsafe inventory options")
        inventory.calls[#inventory.calls + 1] = candidate
        if candidate.reject then return false end
        inventory.current = candidate
        return true
    end
    weapon.OwnInventory = inventory
    local character = { Inventory = { AllItemsMod = reserve } }
    character.CanAccessInventory = function(source) return not source.Locked end
    return { character = character, weapon = weapon, inventory = inventory, handled = false }
end

local old, low, high = item(15), item(5), item(20)
local request = setup(old, { low, high })
callback(request)
assert(request.handled and request.inventory.current == high, "did not choose most loaded compatible magazine")
assert(old.OwnInventory.Container.LoadedCount == 15 and high.OwnInventory.Container.LoadedCount == 20, "changed ammo")

request = setup(old, {})
callback(request)
assert(request.handled and request.inventory.current == old and #request.inventory.calls == 0, "no reserve fell through")

high.reject = true
request = setup(old, { high })
callback(request)
assert(request.handled and request.inventory.current == old, "failed stow discarded the old magazine")
request = setup(old, { high, low })
callback(request)
assert(request.inventory.current == low, "did not try the next reserve after a rejected swap")
high.reject = nil

local wrong, empty, blocked = item(60, false), item(0), item(30)
blocked.blocked = true
local otherGun, lockedBag, bag = item(), item(), item()
otherGun.weapon = true
otherGun.OwnInventory = { AllItemsMod = { item(60) } }
lockedBag.OwnInventory = { Locked = true, AllItemsMod = { item(60) } }
bag.OwnInventory = { AllItemsMod = { high } }
request = setup(nil, { wrong, empty, blocked, otherGun, lockedBag, bag })
request.otherWeapon = otherGun
callback(request)
assert(request.handled and request.inventory.current == high, "empty-slot/nested-bag filtering failed")

request = setup(old, { high })
request.inventory.Container.ContainedStateIndicatorSlot = 1
callback(request)
assert(not request.handled, "hijacked the underbarrel slot")
request = setup(item(), { high })
callback(request)
assert(not request.handled, "hijacked a legacy magazine")
request = setup(old, { high })
request.weapon.Prefab.ContentPackage = {}
callback(request)
assert(not request.handled, "hijacked another mod's weapon")

request = setup(old, { high })
request.handled = true
callback(request)
assert(#request.inventory.calls == 0, "ignored another adapter's handled flag")
request = setup(old, { high })
Game.IsMultiplayer = true
callback(request)
assert(request.handled and #request.inventory.calls == 0, "mutated unsupported multiplayer ammo")
print("ok: whole-magazine reload, ordering, failed swaps, nested/locked inventories, legacy/underbarrel/multiplayer guards")
