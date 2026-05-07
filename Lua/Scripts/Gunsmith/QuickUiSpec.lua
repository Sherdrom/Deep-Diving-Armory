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

local function encodeText(value)
    return tostring(value or "")
        :gsub("%%", "%%25")
        :gsub(":", "%%3A")
        :gsub("|", "%%7C")
        :gsub(",", "%%2C")
        :gsub(";", "%%3B")
        :gsub("~", "%%7E")
        :gsub("=", "%%3D")
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

    local visual = part.visual or {}
    local source = visual.source or {}
    table.insert(entries, table.concat({
        partId,
        part.nameKey,
        status,
        Stats.Encode(Stats.PartStats(part), "~"),
        encodeText(part.item and part.item.identifier or ""),
        encodeText(visual.texture or ""),
        encodeText(string.format("%d,%d,%d,%d", source.x or 0, source.y or 0, source.w or 0, source.h or 0))
    }, ":"))
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

local function visualScale(visual)
    if type(visual) == "table" and type(visual.scale) == "number" and visual.scale > 0 then
        return visual.scale
    end
    return 1.0
end

local resolveDrawOffset

local function resolveMountAnchor(selection, platform, weapon, path)
    local mount = Core.MountForPath(selection, path)
    local anchor = mount and mount.anchor or nil
    if not anchor then return nil end

    local parentPath = Core.ParentPath(path)
    local parentPart = Core.GetInstalledPart(selection, parentPath)
    local parentVisual = Core.PartVisual(parentPart)
    if parentVisual then
        local parentOffset = resolveDrawOffset(selection, platform, weapon, parentPath, parentVisual)
        if parentOffset then
            local parentAttachPoint = parentVisual.attachPoint or { x = 0, y = 0 }
            local parentScale = visualScale(parentVisual)
            return {
                x = parentOffset.x + (parentAttachPoint.x + anchor.x) * parentScale,
                y = parentOffset.y + (parentAttachPoint.y + anchor.y) * parentScale
            }
        end
    end

    local parentAnchor = nil
    if Core.IsRootSlot(platform, parentPath) then
        parentAnchor = weapon and weapon.rootSockets and weapon.rootSockets[parentPath] or nil
    else
        parentAnchor = resolveMountAnchor(selection, platform, weapon, parentPath)
    end

    if parentAnchor then
        return {
            x = parentAnchor.x + anchor.x,
            y = parentAnchor.y + anchor.y
        }
    end

    return nil
end

resolveDrawOffset = function(selection, platform, weapon, path, visual)
    local anchor = nil
    if Core.IsRootSlot(platform, path) then
        local rootPath = Core.LeafPath(path)
        anchor = weapon and weapon.rootSockets and weapon.rootSockets[rootPath] or nil
    else
        anchor = resolveMountAnchor(selection, platform, weapon, path)
    end

    if anchor and visual.attachPoint then
        local scale = visualScale(visual)
        return {
            x = anchor.x - visual.attachPoint.x * scale,
            y = anchor.y - visual.attachPoint.y * scale
        }
    end

    if anchor and visual.relativeOffset then
        return {
            x = anchor.x + visual.relativeOffset.x,
            y = anchor.y + visual.relativeOffset.y
        }
    end

    return nil
end

local function compatibleItemIdentifiers(selection, platform, slotPath)
    local identifiers = {}
    local seen = {}
    local partType = Core.PartTypeForPath(selection, slotPath)
    for _, partId in ipairs(Core.GetPartsForType(partType)) do
        local part = Gunsmith.Config.parts[partId]
        local identifier = part and part.item and part.item.identifier or nil
        if identifier and identifier ~= "" and not seen[identifier] and Core.IsPartCompatible(selection, platform, slotPath, partId) then
            seen[identifier] = true
            table.insert(identifiers, identifier)
        end
    end
    return table.concat(identifiers, "~")
end

local function quickMeta(selection, platform, weapon, quickSlot)
    local anchor = resolveMountAnchor(selection, platform, weapon, quickSlot.path)
    local valid = anchor and "1" or "0"
    anchor = anchor or { x = 0, y = 0 }
    return string.format(
        "slot=%d,anchorX=%.4f,anchorY=%.4f,anchorValid=%s,items=%s",
        quickSlot.slot,
        anchor.x or 0,
        anchor.y or 0,
        valid,
        compatibleItemIdentifiers(selection, platform, quickSlot.path))
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
                table.concat(partEntries, ","),
                quickMeta(selection, platform, weapon, quickSlot)
            }, "|"))
        end
    end

    return table.concat({
        "",
        "deep.gunsmith.ui.quick_root",
        ""
    }, "|") .. "::" .. encodePreview(item, platform) .. "::" .. Stats.Encode(Stats.SumSelection(selection)) .. "::" .. table.concat(entries, ";")
end
