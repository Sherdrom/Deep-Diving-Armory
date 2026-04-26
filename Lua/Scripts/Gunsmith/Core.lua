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

function Core.PathName(platform, path)
    if platform.pathNames and platform.pathNames[path] then
        return platform.pathNames[path]
    end
    return path
end

function Core.JoinPath(parentPath, path)
    if not parentPath or parentPath == "" then return path end
    return parentPath .. "/" .. path
end

function Core.ParentPath(path)
    if not path or path == "" then return "" end
    local parent = string.match(path, "^(.*)/[^/]+$")
    return parent or ""
end

function Core.LeafPath(path)
    if not path or path == "" then return "" end
    return string.match(path, "([^/]+)$") or path
end

function Core.RootSlotDefs(platform)
    local result = {}
    if not platform then return result end
    if type(platform.rootSlots) == "table" then
        for _, entry in ipairs(platform.rootSlots) do
            if type(entry) == "table" and type(entry.path) == "string" then
                table.insert(result, entry)
            end
        end
    end
    return result
end

function Core.RootSlotDef(platform, path)
    for _, entry in ipairs(Core.RootSlotDefs(platform)) do
        if entry.path == path then return entry end
    end
    return nil
end

local function partProvidesAccepted(part, accepts)
    if type(part) ~= "table" or type(part.provides) ~= "table" or type(accepts) ~= "table" then return false end
    for _, provided in ipairs(part.provides) do
        for _, accepted in ipairs(accepts) do
            if provided == accepted then return true end
        end
    end
    return false
end

function Core.DefaultChildMount(parentPart, childPath)
    if not parentPart or type(parentPart.mounts) ~= "table" then return nil end
    for _, mount in ipairs(parentPart.mounts) do
        if mount.path == childPath then return mount end
    end
    return nil
end

function Core.ApplyMountDefaultsForPath(selection, path, visited, depth)
    if not selection or not path or path == "" then return end
    if depth and depth > 32 then return end
    visited = visited or {}

    local parentPart = Core.GetInstalledPart(selection, path)
    if not parentPart or type(parentPart.mounts) ~= "table" then return end

    for _, mount in ipairs(parentPart.mounts) do
        local childPathSegment = mount.path
        local partId = mount.defaultPart
        local childPath = Core.JoinPath(path, childPathSegment)
        local visitKey = childPath .. ":" .. tostring(partId)
        if type(partId) == "string" and partId ~= "" and not visited[visitKey] then
            visited[visitKey] = true
            local childPart = Core.GetPart(partId)
            if childPart and mount and childPart.type == (mount.partType or childPathSegment) and partProvidesAccepted(childPart, mount.accepts) then
                if not selection[childPath] then
                    selection[childPath] = partId
                end
                Core.ApplyMountDefaultsForPath(selection, childPath, visited, (depth or 0) + 1)
            end
        end
    end
end

function Core.BuildDefaultSelection(platform, weapon)
    local selection = {}
    if not platform or not weapon or type(weapon.rootParts) ~= "table" then return selection end

    for _, root in ipairs(Core.RootSlotDefs(platform)) do
        local path = root.path
        local partId = weapon.rootParts[path]
        local part = Core.GetPart(partId)
        if part and part.type == path then
            selection[path] = partId
            Core.ApplyMountDefaultsForPath(selection, path, {}, 0)
        end
    end
    return selection
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

function Core.GetPartsForType(partType)
    local parts = {}
    for partId, part in pairs(Gunsmith.Config.parts) do
        if part.type == partType then
            table.insert(parts, partId)
        end
    end
    table.sort(parts)
    return parts
end

function Core.PartTypeForPath(selection, path)
    local mount = Core.MountForPath(selection, path)
    return mount and mount.partType or Core.LeafPath(path)
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

function Core.AcceptsForPath(selection, platform, path)
    if not platform or not path or path == "" then return nil end
    if Core.IsRootSlot(platform, path) then
        return nil
    end

    local mount = Core.MountForPath(selection, path)
    return mount and mount.accepts or nil
end

function Core.MountForPath(selection, path)
    if not selection or not path or path == "" then return nil end
    local parent = Core.ParentPath(path)
    local childPath = Core.LeafPath(path)
    local parentPart = Core.GetInstalledPart(selection, parent)
    if not parentPart or not parentPart.mounts then return nil end

    for _, mount in ipairs(parentPart.mounts) do
        if mount.path == childPath then
            return mount
        end
    end
    return nil
end

function Core.IsPartCompatible(selection, platform, path, partId)
    local part = Core.GetPart(partId)
    if not part or not platform or not path or path == "" then return false end
    if part.type ~= Core.PartTypeForPath(selection, path) then return false end
    if Core.IsRootSlot(platform, path) then return true end

    local accepts = Core.AcceptsForPath(selection, platform, path)
    if type(accepts) ~= "table" then return false end
    return intersects(accepts, Core.PartProvides(part))
end

function Core.IsRequiredSlot(platform, path)
    if not platform or not path or path == "" then return false end
    if platform.requiredSlots and platform.requiredSlots[path] ~= nil then
        return platform.requiredSlots[path] == true
    end
    if not string.find(path, "/", 1, true) then
        local root = Core.RootSlotDef(platform, path)
        return root and root.required == true
    end
    return false
end

function Core.IsHiddenRootSlot(platform, path)
    local root = Core.RootSlotDef(platform, path)
    return root and root.hidden == true
end

function Core.RootSlots(platform)
    local slots = {}
    for _, root in ipairs(Core.RootSlotDefs(platform)) do
        local path = root.path
        if not Core.IsHiddenRootSlot(platform, path) then
            table.insert(slots, { path = path, partType = path, name = Core.PathName(platform, path) })
        end
    end
    return slots
end

function Core.ChildSlots(selection, platform, path)
    local parentPart = Core.GetInstalledPart(selection, path)
    local slots = {}
    if not parentPart or not parentPart.mounts then return slots end

    for _, mount in ipairs(parentPart.mounts) do
        table.insert(slots, {
            path = Core.JoinPath(path, mount.path),
            partType = mount.partType or mount.path,
            name = mount.name or Core.PathName(platform, mount.path)
        })
    end
    return slots
end

function Core.SlotsForPath(selection, platform, path)
    if not path or path == "" then
        local slots = Core.RootSlots(platform)
        for _, root in ipairs(Core.RootSlotDefs(platform)) do
            local rootPath = root.path
            if Core.IsHiddenRootSlot(platform, rootPath) then
                for _, childPath in ipairs(Core.ChildSlots(selection, platform, rootPath)) do
                    table.insert(slots, childPath)
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
    return Core.RootSlotDef(platform, path) ~= nil
end

function Core.IsValidPath(selection, platform, path)
    if Core.IsRootSlot(platform, path) then return true end
    local parent = Core.ParentPath(path)
    local childPath = Core.LeafPath(path)
    local parentPart = Core.GetInstalledPart(selection, parent)
    if not parentPart or not parentPart.mounts then return false end

    for _, mount in ipairs(parentPart.mounts) do
        if mount.path == childPath then return true end
    end
    return false
end

function Core.PruneInvalidSelections(selection, platform, weapon)
    local defaults = Core.BuildDefaultSelection(platform, weapon)
    local changed = true
    while changed do
        changed = false
        for path, partId in pairs(selection) do
            if not Core.IsValidPath(selection, platform, path) or not Core.IsPartCompatible(selection, platform, path, partId) then
                local defaultPartId = defaults[path]
                if defaultPartId and partId ~= defaultPartId and Core.IsPartCompatible(selection, platform, path, defaultPartId) then
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
        local mountName = Core.PathName(platform, segment)
        local parent = Core.ParentPath(current)
        local parentPart = parent ~= "" and Core.GetInstalledPart(selection, parent) or nil
        if parentPart and parentPart.mounts then
            for _, mount in ipairs(parentPart.mounts) do
                if mount.path == segment then
                    mountName = mount.name or mountName
                    break
                end
            end
        end
        table.insert(names, mountName)
    end
    return table.concat(names, " > ")
end
