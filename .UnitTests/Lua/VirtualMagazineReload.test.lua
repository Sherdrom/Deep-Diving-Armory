local vceType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
local function loadScripts(server, multiplayer, csActive, vceInstalled)
    SERVER, Game, CSActive = server, { IsMultiplayer = multiplayer }, csActive
    Identifier = function(value) return value end
    Deep_Lua, Descriptors = {}, {}
    local hooks, registrations = {}, 0
    Hook = {
        HookMethodType = { After = "After" },
        Add = function(event, name, callback) hooks[name] = callback end,
        Patch = function() end,
    }
    LuaUserData = {
        RegisterType = function(name)
            if name == vceType then
                registrations = registrations + 1
                if not CSActive then error("Type " .. name .. " can't be registered") end
                if not vceInstalled then error("type does not exist") end
            end
        end,
        CreateStatic = function() return function(id) return id end end,
        MakeFieldAccessible = function() end,
    }
    dofile("Lua/Scripts/AliceTechnology/HelpFunctions.lua")
    dofile("Lua/Scripts/BenzeneTechnology/reloadPatch.lua")
    dofile("Lua/Scripts/BenzeneTechnology/VirtualMagazineReload.lua")
    dofile("Lua/Scripts/PeachTechnology/ContainerConditionTransfer.lua")
    if server or not multiplayer then
        dofile("Lua/Scripts/PeachTechnology/AmmoFill/NpcMagazineLoadout.lua")
        assert(hooks["ContainerConditionTransfer.Update"], "legacy press failed to load")
        assert(hooks.NpcMagazineLoadout, "sandboxed spawns must still listen for new loadouts")
    end
    return hooks["DDA.VirtualMagazine.Reload"], registrations
end

local function magazine(id, count, tag, prefab, capacity)
    return {
        ID = id, Condition = count, MaxCondition = capacity or 30,
        Prefab = { Identifier = { Equals = function(other) return other.Value == (prefab or "mag") end,
            Value = prefab or "mag" } },
        HasTag = function(name) return name == tag end,
        IsInteractable = function() return true end,
    }
end

InvSlotType = { Bag = "bag", OuterClothes = "outer", InnerClothes = "inner" }

local function storage(items, canStow)
    local inventory = { Capacity = #items }
    inventory.AllItemsMod = function(_, previous)
        for i, item in ipairs(items) do
            if not previous or items[i-1] == previous then return item end
        end
    end
    inventory.GetItemAt = function(slot) return items[slot+1] end
    inventory.GetItemInLimbSlot = function(limb)
        for _, item in ipairs(items) do
            if item.LimbSlot == limb then return item end
        end
    end
    inventory.FindIndex = function(item)
        for i, other in ipairs(items) do
            if item == other then return i - 1 end
        end
        return -1
    end
    inventory.CanBePutInSlot = function(_, slot) return not items[slot+1].StackFull end
    inventory.TryPutItem = function(item, slot, swap, combine, _, network, ignoreCondition)
        if type(slot) == "table" then
            if canStow then item.ParentInventory = inventory end
            return canStow
        end
        assert(not swap and not combine and network and not ignoreCondition)
        local target = items[slot+1]
        assert(inventory.CanBePutInSlot(item, slot) and item.Condition == 0 and target.Condition == 0)
        assert(target.Prefab.Identifier.Equals(item.Prefab.Identifier))
        item.ParentInventory, item.StackedWith = inventory, target
        return true
    end
    for _, item in ipairs(items) do item.ParentInventory = inventory end
    return inventory
end

local function reload(callback, current, spares, allowSwap, canStow)
    local character = { CanAccessInventory = function(inv) return not inv.Inaccessible end }
    character.Inventory = storage(spares, canStow)
    character.TryPutItemInAnySlot = function(item) return character.Inventory.TryPutItem(item, character) end
    local original = current
    local inventory = {
        Container = { ContainedStateIndicatorSlot = 0, CanBeContained = function() return true end },
    }
    inventory.GetItemAt = function() return current and current.ParentInventory == inventory and current or nil end
    inventory.TryPutItem = function(item, slot, swap, combine, owner, network, ignoreCondition, trigger)
        assert(slot == 0 and not combine and owner == character and network and not ignoreCondition)
        if item == original then
            assert(not swap and trigger == false and not inventory.GetItemAt())
            item.StackedWith = nil
        else
            assert(swap == (not original or original.ParentInventory == inventory))
            if not allowSwap then return false end
            if original and swap then original.ParentInventory = item.ParentInventory end
        end
        item.ParentInventory, current = inventory, item
        return true
    end
    if current then
        current.StackedWith = nil
        current.Dropped = nil
        current.ParentInventory = inventory
        current.GetRootInventoryOwner = function() return character end
        current.Drop = function(dropper, network, transform)
            assert(dropper == character and network and transform)
            original.ParentInventory, original.Dropped = nil, true
        end
    end
    local request = { character = character, inventory = inventory,
        weapon = { Prefab = { ContentPackage = { Name = "Deep-Diving-Armory" } } } }
    callback(request)
    return inventory.GetItemAt(), request.handled
end

local client, registrations = loadScripts(false, true, false, false)
assert(client and registrations == 0, "sandboxed multiplayer client tried to register VCE")
local current = magazine(1, 8, "deep_virtualmagazine")
local spare = magazine(2, 24, "VCE_VirtualizedMagazine")
local empty = magazine(3, 0, "deep_virtualmagazine")
local legacy = magazine(4, 100, "556mag")
local low = magazine(5, 2, "deep_virtualmagazine")
local selected, handled = reload(client, current, { legacy, empty, low, spare, current }, true)
assert(handled and selected == spare and current.Condition == 8 and spare.Condition == 24)
selected, handled = reload(client, current, { spare }, false)
assert(handled and selected == current, "failed swap fell through to ammo merging")
selected, handled = reload(client, legacy, { spare }, true)
assert(not handled and selected == legacy, "virtual reload intercepted a legacy magazine")
selected, handled = reload(client, nil, { empty, legacy }, true)
assert(not handled and not selected, "empty virtual magazine blocked legacy reload")

local full = magazine(6, 30, "deep_virtualmagazine", nil, 30.5)
local drum = magazine(7, 50, "deep_virtualmagazine", "drum", 60)
selected, handled = reload(client, full, { drum }, true)
assert(handled and selected == full, "full magazine was replaced by a larger spare")
local matching = magazine(8, 0, "deep_virtualmagazine")
local otherType = magazine(9, 0, "deep_virtualmagazine", "drum")
local bag = { HasTag = function() return false end, OwnInventory = storage({ matching }) }
selected, handled = reload(client, empty, { otherType, bag }, true)
assert(handled and not selected and empty.StackedWith == matching, "without spares the empty stayed in the weapon")
selected, handled = reload(client, current, { empty }, true)
assert(handled and selected == current and current.Condition == 8, "without spares a loaded magazine was ejected")
selected, handled = reload(client, empty, { otherType, spare, bag }, true)
assert(handled and selected == spare and empty.StackedWith == matching, "ejected empty did not join the bag stack")
local rootMatch = magazine(10, 0, "deep_virtualmagazine")
selected, handled = reload(client, empty, { spare, bag, rootMatch }, true)
assert(handled and selected == spare and empty.StackedWith == rootMatch, "root stack did not take priority")
selected, handled = reload(client, empty, { spare, rootMatch }, false)
assert(handled and selected == empty and not empty.StackedWith, "failed load did not restore the empty magazine")

local pending = {}
Timer = { Wait = function(callback, delay)
    assert(delay == 300)
    pending[#pending + 1] = callback
end }
rootMatch.StackFull = true
selected, handled = reload(client, empty, { spare, rootMatch }, true)
assert(handled and selected == spare and not empty.StackedWith and #pending == 1)
rootMatch.StackFull = false
pending[1]()
assert(empty.StackedWith == rootMatch and #pending == 1, "multiplayer retry did not stack the empty")

Game.IsMultiplayer = false
local emptyBag = { HasTag = function() return false end, LimbSlot = InvSlotType.Bag,
    OwnInventory = storage({}, true) }
selected, handled = reload(client, empty, { emptyBag }, true, true)
assert(handled and not selected and empty.ParentInventory == emptyBag.OwnInventory, "empty did not go to the bag")
selected, handled = reload(client, empty, {}, true, true)
assert(handled and not selected and empty.ParentInventory and not empty.Dropped, "empty did not go to main inventory")
selected, handled = reload(client, empty, {}, true)
assert(handled and not selected and empty.Dropped and not empty.ParentInventory, "empty was not dropped when inventory was full")

local _, count = loadScripts(false, false, false, false)
assert(count == 0)
_, count = loadScripts(false, true, true, true)
assert(count == 0)
_, count = loadScripts(false, false, true, false)
assert(count == 1 and not Deep_Lua.HF.VirtualMagazineType)
local server
server, count = loadScripts(true, true, true, true)
assert(not server and count == 1 and Deep_Lua.HF.VirtualMagazineType == vceType)
print("ok: whole-magazine reload, full-magazine guard, empty stacking and legacy fallback")
