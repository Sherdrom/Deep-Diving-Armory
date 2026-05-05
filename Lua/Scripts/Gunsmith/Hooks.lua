Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Persistence = Gunsmith.Persistence
local Runtime = Gunsmith.Runtime
local QuickMod = Gunsmith.QuickMod
local Hooks = {}

Gunsmith.Hooks = Hooks

local function readItemAndStrings(args)
    local item = nil
    local strings = {}

    for _, value in ipairs(args) do
        if LuaUserData.IsTargetType(value, "Barotrauma.Item") then
            item = value
        elseif type(value) == "string" then
            table.insert(strings, value)
        end
    end

    return item, strings
end

local function applyGunsmithItem(item)
    if item and Core.WeaponConfig(item) then
        Runtime.Apply(item)
    end
end

local function registerHiddenQuickSlots()
    if not Hook or not Hook.Call then return end
    local config = Gunsmith.Config
    if not config or type(config.weapons) ~= "table" then return end

    for identifier, weapon in pairs(config.weapons) do
        if type(weapon.quickSlots) == "table" then
            local slots = {}
            for _, quickSlot in ipairs(weapon.quickSlots) do
                local slotIndex = tonumber(quickSlot.slot)
                if slotIndex then
                    table.insert(slots, tostring(slotIndex))
                end
            end

            if #slots > 0 then
                Hook.Call("DeepGunsmithRegisterHiddenQuickSlots", tostring(identifier), table.concat(slots, ","))
            end
        end
    end
end

function Hooks.Register()
    if not CLIENT then return end
    if Hooks.Registered then return end
    Hooks.Registered = true

    registerHiddenQuickSlots()

    Hook.Add("DeepGunsmithReceiveState", "DeepGunsmithReceiveState", function(...)
        local item, strings = readItemAndStrings({ ... })
        if item then
            Persistence.Receive(item, strings[1] or "")
        end
    end)

    Hook.Add("DeepGunsmithCycle", "DeepGunsmithCycle", function(...)
        local item, strings = readItemAndStrings({ ... })
        if item and strings[1] then
            Runtime.CyclePart(item, strings[1])
            Runtime.Open(item)
        end
    end)

    Hook.Add("DeepGunsmithSetPart", "DeepGunsmithSetPart", function(...)
        local item, strings = readItemAndStrings({ ... })
        if item and strings[1] and strings[2] then
            local shouldOpenNow = Runtime.SetPart(item, strings[1], strings[2])
            if shouldOpenNow ~= false then
                Runtime.Open(item)
            end
        end
    end)

    Hook.Add("DeepGunsmithSetQuickPart", "DeepGunsmithSetQuickPart", function(...)
        local item, strings = readItemAndStrings({ ... })
        if item and strings[1] and strings[2] then
            local shouldOpenNow = Runtime.SetPart(item, strings[1], strings[2], "quick")
            if shouldOpenNow ~= false then
                Runtime.OpenQuick(item)
            end
        end
    end)

    Hook.Add("DeepGunsmithEnterPath", "DeepGunsmithEnterPath", function(...)
        local item, strings = readItemAndStrings({ ... })
        if item and strings[1] then
            Runtime.SetCurrentUiPath(item, strings[1])
            Runtime.Open(item)
        end
    end)

    Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
        if not PlayerInput or not Keys then return end
        local keyOk, keyHit = pcall(function() return PlayerInput.KeyHit(Keys.G) end)
        if not keyOk or not keyHit then return end

        local shiftDown = false
        pcall(function()
            shiftDown = PlayerInput.KeyDown(Keys.LeftShift) or PlayerInput.KeyDown(Keys.RightShift)
        end)

        local item = Runtime.SelectedHandWeapon(instance)
        if item then
            if shiftDown and QuickMod and QuickMod.IsQuickItem(item) then
                Runtime.OpenQuick(item)
            else
                Runtime.SetCurrentUiPath(item, Runtime.GetCurrentUiPath(item))
                Runtime.Open(item)
            end
        end
    end, Hook.HookMethodType.After)

    Hook.Patch("Barotrauma.Item", "OnMapLoaded", function(instance, ptable)
        applyGunsmithItem(instance)
    end, Hook.HookMethodType.After)

    pcall(function()
        Hook.Patch("Barotrauma.Item", ".ctor", { "Microsoft.Xna.Framework.Rectangle", "Barotrauma.ItemPrefab", "Barotrauma.Submarine", "System.Boolean", "System.UInt16" }, function(instance, ptable)
            applyGunsmithItem(instance)
        end, Hook.HookMethodType.After)
    end)

    local function syncQuickModContainer(instance)
        if not instance then return end
        local ok, item = pcall(function() return instance.Item end)
        if not ok or not item then return end
        if Core.WeaponConfig(item) and QuickMod and QuickMod.IsQuickItem(item) then
            Runtime.SyncQuickModContainerItem(item)
        end
    end

    Hook.Patch("Barotrauma.Items.Components.ItemContainer", "OnItemContained", { "Barotrauma.Item", "System.Boolean" }, function(instance, ptable)
        syncQuickModContainer(instance)
    end, Hook.HookMethodType.After)

    Hook.Patch("Barotrauma.Items.Components.ItemContainer", "OnItemRemoved", { "Barotrauma.Item" }, function(instance, ptable)
        syncQuickModContainer(instance)
    end, Hook.HookMethodType.After)

    Hook.Add("item.removed", "DeepGunsmithCleanup", function(item)
        Runtime.Cleanup(item)
    end)
end
