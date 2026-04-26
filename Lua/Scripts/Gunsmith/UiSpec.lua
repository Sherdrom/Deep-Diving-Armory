Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Inventory = Gunsmith.Inventory
local Stats = Gunsmith.Stats
local UiSpec = {}
Gunsmith.UiSpec = UiSpec

local function encodePreview(item, platform)
    local weapon = Core.WeaponConfig(item) or {}
    local preview = weapon.preview or {}
    local offset = preview.offset or { x = 0, y = 0 }
    return string.format(
        "padding=%.4f,zoom=%.4f,offsetX=%.4f,offsetY=%.4f",
        preview.padding or 12,
        preview.zoom or 1.0,
        offset.x or 0,
        offset.y or 0)
end

local function appendPartEntry(entries, item, selection, platform, slotPath, partId)
    local part = Gunsmith.Config.parts[partId]
    if part then
        local weapon = Core.WeaponConfig(item)
        local status = "available"
        if selection[slotPath] == partId then
            status = "installed"
        elseif not Core.IsPartCompatible(selection, platform, slotPath, partId, weapon) then
            status = "incompatible"
        elseif Inventory and not Inventory.HasPartItem(Inventory.ActorForItem(item), part) then
            status = "missing"
        end
        table.insert(entries, partId .. ":" .. part.name .. ":" .. status .. ":" .. Stats.Encode(Stats.PartStats(part), "~"))
    end
end

function UiSpec.Build(item, selection, platform, currentPath)
    local path = currentPath or ""
    local entries = {}

    for _, slot in ipairs(Core.SlotsForPath(selection, platform, path)) do
        local emptyStatus = "available"
        if Core.IsRequiredSlot(platform, slot.path) then
            emptyStatus = "disabled"
        elseif not selection[slot.path] then
            emptyStatus = "installed"
        end
        local partEntries = { Gunsmith.EmptyPartId .. ":[空]:" .. emptyStatus }
        for _, partId in ipairs(Core.GetPartsForSlot(slot.slot)) do
            appendPartEntry(partEntries, item, selection, platform, slot.path, partId)
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
    }, "|") .. "::" .. encodePreview(item, platform) .. "::" .. Stats.Encode(Stats.SumSelection(selection)) .. "::" .. table.concat(entries, ";")
end
