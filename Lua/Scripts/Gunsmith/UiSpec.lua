Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local UiSpec = {}
Gunsmith.UiSpec = UiSpec

local function appendPartEntry(entries, partId)
    local part = Gunsmith.Config.parts[partId]
    if part then
        table.insert(entries, partId .. ":" .. part.name)
    end
end

function UiSpec.Build(selection, platform, currentPath)
    local path = currentPath or ""
    local entries = {}

    for _, slot in ipairs(Core.SlotsForPath(selection, platform, path)) do
        local partEntries = { Gunsmith.EmptyPartId .. ":[空]" }
        for _, partId in ipairs(Core.GetPartsForSlot(slot.slot)) do
            appendPartEntry(partEntries, partId)
        end

        local slotPath = slot.path
        local currentPartId = tostring(selection[slotPath] or "")
        local canEnter = Core.HasChildSlots(selection, platform, slotPath) and "1" or "0"
        table.insert(entries, table.concat({
            slotPath,
            slot.name,
            currentPartId,
            canEnter,
            table.concat(partEntries, ",")
        }, "|"))
    end

    return table.concat({
        path,
        Core.PathLabel(selection, platform, path),
        Core.ParentPath(path)
    }, "|") .. "::" .. table.concat(entries, ";")
end
