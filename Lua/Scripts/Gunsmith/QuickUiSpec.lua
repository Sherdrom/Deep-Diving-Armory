Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Inventory = Gunsmith.Inventory
local Stats = Gunsmith.Stats
local QuickUiSpec = {}
Gunsmith.QuickUiSpec = QuickUiSpec

local function encodePreview(item, platform)
    local weapon = Core.WeaponConfig(item) or {}
    local preview = weapon.preview or {}
    local offset = preview.offset or { x = 0, y = 0 }
    return string.format(
        "padding=%.4f,scale=%.4f,offsetX=%.4f,offsetY=%.4f",
        preview.padding or 12,
        preview.scale or 1.0,
        offset.x or 0,
        offset.y or 0)
end

local function appendPartEntry(entries, item, selection, platform, slotPath, partId)
    local part = Gunsmith.Config.parts[partId]
    if not part then return end

    local status = "available"
    if selection[slotPath] == partId then
        status = "installed"
    elseif not Core.IsPartCompatible(selection, platform, slotPath, partId) then
        status = "incompatible"
    elseif Inventory and not Inventory.HasPartItem(Inventory.ActorForItem(item), part, item) then
        status = "missing"
    end

    table.insert(entries, partId .. ":" .. part.nameKey .. ":" .. status .. ":" .. Stats.Encode(Stats.PartStats(part), "~"))
end

local function quickSlotsForWeapon(weapon)
    if not weapon or type(weapon.quickSlots) ~= "table" then return {} end
    local slots = {}
    for _, quickSlot in ipairs(weapon.quickSlots) do
        if quickSlot.path and quickSlot.slot then
            table.insert(slots, quickSlot)
        end
    end
    return slots
end

function QuickUiSpec.Build(item, selection, platform)
    local weapon = Core.WeaponConfig(item)
    local entries = {}

    for _, quickSlot in ipairs(quickSlotsForWeapon(weapon)) do
        if Core.IsValidPath(selection, platform, quickSlot.path) then
            local partType = Core.PartTypeForPath(selection, quickSlot.path)
            local emptyStatus = "available"
            if Core.IsRequiredSlot(platform, quickSlot.path) then
                emptyStatus = "disabled"
            elseif not selection[quickSlot.path] then
                emptyStatus = "installed"
            end

            local partEntries = { Gunsmith.EmptyPartId .. ":deep.gunsmith.ui.empty_part:" .. emptyStatus }
            for _, partId in ipairs(Core.GetPartsForType(partType)) do
                appendPartEntry(partEntries, item, selection, platform, quickSlot.path, partId)
            end

            table.insert(entries, table.concat({
                quickSlot.path,
                quickSlot.nameKey or Core.PathNameKey(platform, quickSlot.path),
                tostring(selection[quickSlot.path] or ""),
                "0",
                table.concat(partEntries, ",")
            }, "|"))
        end
    end

    return table.concat({
        "",
        "deep.gunsmith.ui.quick_root",
        ""
    }, "|") .. "::" .. encodePreview(item, platform) .. "::" .. Stats.Encode(Stats.SumSelection(selection)) .. "::" .. table.concat(entries, ";")
end
