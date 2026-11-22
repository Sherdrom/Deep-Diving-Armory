local vceType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
local function loadScripts(server, multiplayer, csActive, vceInstalled)
    SERVER, Game, CSActive = server, { IsMultiplayer = multiplayer }, csActive
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
        assert((hooks.NpcMagazineLoadout ~= nil) == (csActive and vceInstalled))
    end
    return hooks["DDA.VirtualMagazine.Reload"], registrations
end

local function magazine(id, count, tag)
    return {
        ID = id, Condition = count,
        HasTag = function(name) return name == tag end,
        IsInteractable = function() return true end,
    }
end

local function reload(callback, current, spares, allowSwap)
    local nextSpare = 0
    local character = { CanAccessInventory = function() return true end }
    character.Inventory = { AllItemsMod = function()
        nextSpare = nextSpare + 1
        return spares[nextSpare]
    end }
    local inventory = {
        Container = { ContainedStateIndicatorSlot = 0, CanBeContained = function() return true end },
        GetItemAt = function() return current end,
        TryPutItem = function(item, slot, swap, combine, owner, network, ignoreCondition)
            assert(slot == 0 and swap and not combine and owner == character and network and not ignoreCondition)
            if allowSwap then current = item end
            return allowSwap
        end,
    }
    local request = { character = character, inventory = inventory,
        weapon = { Prefab = { ContentPackage = { Name = "Deep-Diving-Armory" } } } }
    callback(request)
    return current, request.handled
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

local _, count = loadScripts(false, false, false, false)
assert(count == 0)
_, count = loadScripts(false, true, true, true)
assert(count == 0)
_, count = loadScripts(false, false, true, false)
assert(count == 1 and not Deep_Lua.HF.VirtualMagazineType)
local server
server, count = loadScripts(true, true, true, true)
assert(not server and count == 1 and Deep_Lua.HF.VirtualMagazineType == vceType)
print("ok: sandboxed whole-magazine reload, legacy fallback and optional VCE registration")
