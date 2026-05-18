Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Runtime = Gunsmith.Runtime
local Debug = {}
Gunsmith.Debug = Debug

local function normalizeArgs(...)
    local raw = { ... }
    if #raw == 1 and type(raw[1]) == "table" then
        return raw[1]
    end
    return raw
end

local function numberArg(value)
    local parsed = tonumber(value)
    return parsed
end

local function rootConfig(weaponId, rootPath)
    local config = Gunsmith.Config
    local weapon = config and config.weapons and config.weapons[weaponId] or nil
    if type(weapon) ~= "table" then
        print("[Gunsmith][Debug] Unknown weapon '" .. tostring(weaponId) .. "'.")
        return nil
    end
    if type(weapon.roots) ~= "table" or type(weapon.roots[rootPath]) ~= "table" then
        print("[Gunsmith][Debug] Unknown root '" .. tostring(rootPath) .. "' for weapon '" .. tostring(weaponId) .. "'.")
        return nil
    end
    return weapon.roots[rootPath]
end

local function reapplyWeaponItems(weaponId)
    if SERVER or not Runtime or not Runtime.Apply then return 0 end
    if not Item or not Item.ItemList then return 0 end

    local count = 0
    for item in Item.ItemList do
        if item and not item.removed and Core.ItemIdentifier(item) == weaponId then
            local key = Core.ItemKey(item)
            if key and Gunsmith.State and Gunsmith.State.appliedSignatures then
                Gunsmith.State.appliedSignatures[item] = nil
            end
            Runtime.Apply(item)
            count = count + 1
        end
    end
    return count
end

local function printOrigin(weaponId, rootPath, root)
    local origin = root.itemPosOrigin or { x = 0, y = 0 }
    local socket = root.socket or { x = 0, y = 0 }
    print(string.format(
        "[Gunsmith][Debug] %s roots.%s.itemPosOrigin = { x = %.4f, y = %.4f } canvas = { x = %.4f, y = %.4f }",
        tostring(weaponId),
        tostring(rootPath),
        origin.x or 0,
        origin.y or 0,
        (socket.x or 0) + (origin.x or 0),
        (socket.y or 0) + (origin.y or 0)))
end

local function setItemPosOrigin(weaponId, rootPath, x, y)
    local root = rootConfig(weaponId, rootPath)
    if not root then return end

    root.itemPosOrigin = { x = x, y = y }
    printOrigin(weaponId, rootPath, root)
    local count = reapplyWeaponItems(weaponId)
    if count > 0 then
        print("[Gunsmith][Debug] Reapplied " .. tostring(count) .. " item(s).")
    end
end

function Debug.RegisterCommands()
    if Debug.CommandsRegistered or not Game or not Game.AddCommand then return end
    Debug.CommandsRegistered = true

    Game.AddCommand("DeepGunsmithSetItemPosOrigin", "Set weapon roots[root].itemPosOrigin: <weaponId> <root> <x> <y>", function(...)
        local args = normalizeArgs(...)
        local weaponId = tostring(args[1] or "")
        local rootPath = tostring(args[2] or "")
        local x = numberArg(args[3])
        local y = numberArg(args[4])
        if weaponId == "" or rootPath == "" or not x or not y then
            print("[Gunsmith][Debug] Usage: DeepGunsmithSetItemPosOrigin <weaponId> <root> <x> <y>")
            return
        end
        setItemPosOrigin(weaponId, rootPath, x, y)
    end, nil, false)

    Game.AddCommand("DeepGunsmithNudgeItemPosOrigin", "Nudge weapon roots[root].itemPosOrigin: <weaponId> <root> <dx> <dy>", function(...)
        local args = normalizeArgs(...)
        local weaponId = tostring(args[1] or "")
        local rootPath = tostring(args[2] or "")
        local dx = numberArg(args[3])
        local dy = numberArg(args[4])
        local root = rootConfig(weaponId, rootPath)
        if weaponId == "" or rootPath == "" or not dx or not dy or not root then
            print("[Gunsmith][Debug] Usage: DeepGunsmithNudgeItemPosOrigin <weaponId> <root> <dx> <dy>")
            return
        end
        local origin = root.itemPosOrigin or { x = 0, y = 0 }
        setItemPosOrigin(weaponId, rootPath, (origin.x or 0) + dx, (origin.y or 0) + dy)
    end, nil, false)

    Game.AddCommand("DeepGunsmithPrintItemPosOrigin", "Print weapon roots[root].itemPosOrigin: <weaponId> <root>", function(...)
        local args = normalizeArgs(...)
        local weaponId = tostring(args[1] or "")
        local rootPath = tostring(args[2] or "")
        local root = rootConfig(weaponId, rootPath)
        if weaponId == "" or rootPath == "" or not root then
            print("[Gunsmith][Debug] Usage: DeepGunsmithPrintItemPosOrigin <weaponId> <root>")
            return
        end
        printOrigin(weaponId, rootPath, root)
    end, nil, false)
end
