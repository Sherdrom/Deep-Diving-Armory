Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Persistence = Gunsmith.Persistence
local Runtime = Gunsmith.Runtime
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

function Hooks.Register()
    if not CLIENT then return end
    if Hooks.Registered then return end
    Hooks.Registered = true

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
            Runtime.SetPart(item, strings[1], strings[2])
            Runtime.Open(item)
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

        local item = Runtime.SelectedHandWeapon(instance)
        if item then
            Runtime.SetCurrentUiPath(item, Runtime.GetCurrentUiPath(item))
            Runtime.Open(item)
        end
    end, Hook.HookMethodType.After)

    Hook.Add("think", "DeepGunsmithApplyDefaults", function()
        local currentTime = Timer.GetTime()
        if currentTime - Gunsmith.State.lastScanTime < 1.0 then return end
        Gunsmith.State.lastScanTime = currentTime

        if not Item or not Item.ItemList then return end
        for item in Item.ItemList do
            if Core.WeaponConfig(item) then
                Runtime.Apply(item)
            end
        end
    end)

    Hook.Add("item.removed", "DeepGunsmithCleanup", function(item)
        Runtime.Cleanup(item)
    end)
end
