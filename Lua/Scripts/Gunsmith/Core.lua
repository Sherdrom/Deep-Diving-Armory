Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = {}
Gunsmith.Core = Core

function Core.ItemIdentifier(item)
    if not item or not item.Prefab then return nil end
    return item.Prefab.Identifier.Value
end

function Core.ItemKey(item)
    if not item then return nil end
    return tostring(item.ID)
end

function Core.WeaponConfig(item)
    local config = Gunsmith.Config
    local identifier = Core.ItemIdentifier(item)
    if not config or not identifier then return nil end
    return config.weapons[identifier]
end

function Core.PlatformConfig(item)
    local config = Gunsmith.Config
    local weapon = Core.WeaponConfig(item)
    if not config or not weapon then return nil end
    return config.platforms[weapon.platform]
end

function Core.WeaponScale(item)
    local weapon = Core.WeaponConfig(item)
    if not weapon or type(weapon.scale) ~= "number" or weapon.scale <= 0 then return 1.0 end
    return weapon.scale
end

function Core.SlotName(platform, slot)
    if platform.slotNames and platform.slotNames[slot] then
        return platform.slotNames[slot]
    end
    return slot
end

function Core.JoinPath(parentPath, slot)
    if not parentPath or parentPath == "" then return slot end
    return parentPath .. "/" .. slot
end

function Core.ParentPath(path)
    if not path or path == "" then return "" end
    local parent = string.match(path, "^(.*)/[^/]+$")
    return parent or ""
end

function Core.LeafSlot(path)
    if not path or path == "" then return "" end
    return string.match(path, "([^/]+)$") or path
end

function Core.CopyDefaults(platform, weapon)
    local result = {}
    if platform and type(platform.defaults) == "table" then
        for slot, partId in pairs(platform.defaults) do
            result[slot] = partId
        end
    end
    if weapon and type(weapon.defaults) == "table" then
        for slot, partId in pairs(weapon.defaults) do
            result[slot] = partId
        end
    end
    return result
end

function Core.GetPart(partId)
    if not partId or partId == "" or partId == Gunsmith.EmptyPartId then return nil end
    return Gunsmith.Config.parts[partId]
end

function Core.GetInstalledPart(selection, path)
    return Core.GetPart(selection[path])
end

function Core.PartVisual(part)
    if not part then return nil end
    return part.visual
end

function Core.PartProvides(part)
    if not part or type(part.provides) ~= "table" then return {} end
    return part.provides
end

function Core.GetPartsForSlot(slot)
    local parts = {}
    for partId, part in pairs(Gunsmith.Config.parts) do
        if part.slot == slot then
            table.insert(parts, partId)
        end
    end
    table.sort(parts)
    return parts
end

function Core.PartSlotForPath(selection, slotPath)
    local mount = Core.MountForPath(selection, slotPath)
    return mount and mount.partSlot or Core.LeafSlot(slotPath)
end

local function contains(values, target)
    if type(values) ~= "table" then return false end
    for _, value in ipairs(values) do
        if value == target then return true end
    end
    return false
end

local function intersects(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for _, value in ipairs(left) do
        if contains(right, value) then return true end
    end
    return false
end

function Core.AcceptsForPath(selection, platform, slotPath, weapon)
    if not platform or not slotPath or slotPath == "" then return nil end
    if Core.IsRootSlot(platform, slotPath) then
        if weapon and type(weapon.rootAccepts) == "table" and weapon.rootAccepts[slotPath] ~= nil then
            return weapon.rootAccepts[slotPath]
        end
        return platform.rootAccepts and platform.rootAccepts[slotPath] or nil
    end

    local mount = Core.MountForPath(selection, slotPath)
    return mount and mount.accepts or nil
end

function Core.MountForPath(selection, slotPath)
    if not selection or not slotPath or slotPath == "" then return nil end
    local parent = Core.ParentPath(slotPath)
    local slot = Core.LeafSlot(slotPath)
    local parentPart = Core.GetInstalledPart(selection, parent)
    if not parentPart or not parentPart.mounts then return nil end

    for _, mount in ipairs(parentPart.mounts) do
        if mount.slot == slot then
            return mount
        end
    end
    return nil
end

function Core.IsPartCompatible(selection, platform, slotPath, partId, weapon)
    local part = Core.GetPart(partId)
    if not part or not platform or not slotPath or slotPath == "" then return false end
    if part.slot ~= Core.PartSlotForPath(selection, slotPath) then return false end

    local accepts = Core.AcceptsForPath(selection, platform, slotPath, weapon)
    if type(accepts) ~= "table" then return false end
    return intersects(accepts, Core.PartProvides(part))
end

function Core.IsRequiredSlot(platform, path)
    if not platform or not path or path == "" then return false end
    if platform.requiredSlots and platform.requiredSlots[path] ~= nil then
        return platform.requiredSlots[path] == true
    end
    if not string.find(path, "/", 1, true) and platform.requiredRootSlots ~= false then
        return true
    end
    return false
end

function Core.IsHiddenRootSlot(platform, slot)
    return platform and platform.hiddenRootSlots and platform.hiddenRootSlots[slot] == true
end

function Core.RootSlots(platform)
    local slots = {}
    for _, slot in ipairs(platform.slots) do
        if not Core.IsHiddenRootSlot(platform, slot) then
            table.insert(slots, { path = slot, slot = slot, name = Core.SlotName(platform, slot) })
        end
    end
    return slots
end

function Core.ChildSlots(selection, platform, path)
    local parentPart = Core.GetInstalledPart(selection, path)
    local slots = {}
    if not parentPart or not parentPart.mounts then return slots end

    for _, mount in ipairs(parentPart.mounts) do
        local slot = mount.slot
        table.insert(slots, {
            path = Core.JoinPath(path, slot),
            slot = slot,
            partSlot = mount.partSlot or slot,
            name = mount.name or Core.SlotName(platform, slot)
        })
    end
    return slots
end

function Core.SlotsForPath(selection, platform, path)
    if not path or path == "" then
        local slots = Core.RootSlots(platform)
        for _, rootSlot in ipairs(platform.slots or {}) do
            if Core.IsHiddenRootSlot(platform, rootSlot) then
                for _, childSlot in ipairs(Core.ChildSlots(selection, platform, rootSlot)) do
                    table.insert(slots, childSlot)
                end
            end
        end
        return slots
    end
    return Core.ChildSlots(selection, platform, path)
end

function Core.HasChildSlots(selection, platform, path)
    return #Core.ChildSlots(selection, platform, path) > 0
end

function Core.IsRootSlot(platform, path)
    if not path or string.find(path, "/", 1, true) then return false end
    for _, slot in ipairs(platform.slots) do
        if slot == path then return true end
    end
    return false
end

function Core.IsValidPath(selection, platform, path)
    if Core.IsRootSlot(platform, path) then return true end
    local parent = Core.ParentPath(path)
    local slot = Core.LeafSlot(path)
    local parentPart = Core.GetInstalledPart(selection, parent)
    if not parentPart or not parentPart.mounts then return false end

    for _, mount in ipairs(parentPart.mounts) do
        if mount.slot == slot then return true end
    end
    return false
end

function Core.PruneInvalidSelections(selection, platform, weapon)
    local defaults = Core.CopyDefaults(platform, weapon)
    local changed = true
    while changed do
        changed = false
        for path, partId in pairs(selection) do
            if not Core.IsValidPath(selection, platform, path) or not Core.IsPartCompatible(selection, platform, path, partId, weapon) then
                local defaultPartId = defaults[path]
                if defaultPartId and partId ~= defaultPartId and Core.IsPartCompatible(selection, platform, path, defaultPartId, weapon) then
                    selection[path] = defaultPartId
                else
                    selection[path] = nil
                end
                changed = true
            end
        end
    end
end

function Core.ClearDescendants(selection, slotPath)
    local prefix = slotPath .. "/"
    for path, _ in pairs(selection) do
        if string.sub(path, 1, #prefix) == prefix then
            selection[path] = nil
        end
    end
end

function Core.SortedSelectionPaths(selection)
    local paths = {}
    for path, _ in pairs(selection) do
        table.insert(paths, path)
    end
    table.sort(paths)
    return paths
end

function Core.PathLabel(selection, platform, path)
    if not path or path == "" then return "枪械" end

    local names = { "枪械" }
    local current = ""
    for segment in string.gmatch(path, "[^/]+") do
        current = Core.JoinPath(current, segment)
        local mountName = Core.SlotName(platform, segment)
        local parent = Core.ParentPath(current)
        local parentPart = parent ~= "" and Core.GetInstalledPart(selection, parent) or nil
        if parentPart and parentPart.mounts then
            for _, mount in ipairs(parentPart.mounts) do
                if mount.slot == segment then
                    mountName = mount.name or mountName
                    break
                end
            end
        end
        table.insert(names, mountName)
    end
    return table.concat(names, " > ")
end
