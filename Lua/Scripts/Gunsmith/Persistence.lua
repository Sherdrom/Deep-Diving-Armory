Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Persistence = {}
Gunsmith.Persistence = Persistence

local saveVersion = 1

local function jsonEscape(value)
    return tostring(value):gsub('[\\"]', {
        ["\\"] = "\\\\",
        ["\""] = "\\\""
    })
end

local function jsonUnescape(value)
    return tostring(value):gsub("\\(.)", function(escaped)
        if escaped == "\\" then return "\\" end
        if escaped == "\"" then return "\"" end
        if escaped == "/" then return "/" end
        if escaped == "n" then return "\n" end
        if escaped == "r" then return "\r" end
        if escaped == "t" then return "\t" end
        return escaped
    end)
end

local function sortedSavedPaths(savedParts)
    local paths = {}
    for path, _ in pairs(savedParts) do
        table.insert(paths, path)
    end
    table.sort(paths, function(left, right)
        local _, leftDepth = string.gsub(left, "/", "")
        local _, rightDepth = string.gsub(right, "/", "")
        if leftDepth == rightDepth then return left < right end
        return leftDepth < rightDepth
    end)
    return paths
end

function Persistence.Encode(selection, platform)
    local entries = {}

    for _, slot in ipairs(platform.slots) do
        local partId = selection[slot]
        if partId ~= platform.defaults[slot] then
            table.insert(entries, string.format("\"%s\":\"%s\"", jsonEscape(slot), jsonEscape(partId or Gunsmith.EmptyPartId)))
        end
    end

    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        if not Core.IsRootSlot(platform, path) and selection[path] then
            table.insert(entries, string.format("\"%s\":\"%s\"", jsonEscape(path), jsonEscape(selection[path])))
        end
    end

    return string.format("{\"v\":%d,\"parts\":{%s}}", saveVersion, table.concat(entries, ","))
end

function Persistence.Decode(json)
    if type(json) ~= "string" or json == "" then return nil end

    local partsText = string.match(json, '"parts"%s*:%s*{(.-)}')
    if not partsText then return nil end

    local parts = {}
    for rawPath, rawPartId in string.gmatch(partsText, '"([^"]*)"%s*:%s*"([^"]*)"') do
        local path = jsonUnescape(rawPath)
        local partId = jsonUnescape(rawPartId)
        if path ~= "" and partId ~= "" then
            parts[path] = partId
        end
    end

    return parts
end

function Persistence.ApplySavedParts(selection, platform, savedParts)
    if type(savedParts) ~= "table" then return end

    for _, path in ipairs(sortedSavedPaths(savedParts)) do
        local partId = savedParts[path]
        if Core.IsValidPath(selection, platform, path) then
            if partId == Gunsmith.EmptyPartId then
                selection[path] = nil
            else
                local part = Gunsmith.Config.parts[partId]
                if part and part.slot == Core.LeafSlot(path) then
                    selection[path] = partId
                end
            end
            Core.PruneInvalidSelections(selection, platform)
        end
    end
end

function Persistence.Receive(item, json)
    local State = Gunsmith.State
    local platform = Core.PlatformConfig(item)
    local key = Core.ItemKey(item)
    if not State or not platform or not key then return end

    local selection = Core.CopyDefaults(platform)
    Persistence.ApplySavedParts(selection, platform, Persistence.Decode(json))
    Core.PruneInvalidSelections(selection, platform)

    State.selections[key] = selection
    State.loadedStates[key] = true
    State.appliedSignatures[item] = nil
end

function Persistence.Request(item)
    if not Hook or not Hook.Call then return end
    Hook.Call("DeepGunsmithRequestState", item)
end

function Persistence.Save(item)
    if not Hook or not Hook.Call then return end
    local platform = Core.PlatformConfig(item)
    local selection = Gunsmith.Runtime and Gunsmith.Runtime.GetSelection(item) or nil
    if not platform or not selection then return end

    Core.PruneInvalidSelections(selection, platform)
    Hook.Call("DeepGunsmithSaveState", item, Persistence.Encode(selection, platform))
end
