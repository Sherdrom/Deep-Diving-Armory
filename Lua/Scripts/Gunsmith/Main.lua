Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local config = Gunsmith.Config
local selections = {}
local appliedSignatures = {}
local uiPaths = {}
local lastScanTime = 0
local emptyPartId = "__empty"

local function itemIdentifier(item)
    if not item or not item.Prefab then return nil end
    return item.Prefab.Identifier.Value
end

local function itemKey(item)
    if not item then return nil end
    return tostring(item.ID)
end

local function weaponConfig(item)
    local identifier = itemIdentifier(item)
    if not identifier then return nil end
    return config.weapons[identifier]
end

local function platformConfig(item)
    local weapon = weaponConfig(item)
    if not weapon then return nil end
    return config.platforms[weapon.platform]
end

local function slotName(platform, slot)
    if platform.slotNames and platform.slotNames[slot] then
        return platform.slotNames[slot]
    end
    return slot
end

local function joinPath(parentPath, slot)
    if not parentPath or parentPath == "" then return slot end
    return parentPath .. "/" .. slot
end

local function parentPath(path)
    if not path or path == "" then return "" end
    local parent = string.match(path, "^(.*)/[^/]+$")
    return parent or ""
end

local function leafSlot(path)
    if not path or path == "" then return "" end
    return string.match(path, "([^/]+)$") or path
end

local function copyDefaults(platform)
    local result = {}
    for slot, partId in pairs(platform.defaults) do
        result[slot] = partId
    end
    return result
end

local function getSelection(item)
    local platform = platformConfig(item)
    if not platform then return nil end

    local key = itemKey(item)
    if not selections[key] then
        selections[key] = copyDefaults(platform)
    end
    return selections[key]
end

local function getCurrentUiPath(item)
    local key = itemKey(item)
    return uiPaths[key] or ""
end

local function setCurrentUiPath(item, path)
    local key = itemKey(item)
    uiPaths[key] = path or ""
end

local function getPart(partId)
    if not partId or partId == "" or partId == emptyPartId then return nil end
    return config.parts[partId]
end

local function getInstalledPart(selection, path)
    return getPart(selection[path])
end

local function getPartsForSlot(slot)
    local parts = {}
    for partId, part in pairs(config.parts) do
        if part.slot == slot then
            table.insert(parts, partId)
        end
    end
    table.sort(parts)
    return parts
end

local function rootSlots(platform)
    local slots = {}
    for _, slot in ipairs(platform.slots) do
        table.insert(slots, { path = slot, slot = slot, name = slotName(platform, slot) })
    end
    return slots
end

local function childSlots(selection, platform, path)
    local parentPart = getInstalledPart(selection, path)
    local slots = {}
    if not parentPart or not parentPart.mounts then return slots end

    for _, mount in ipairs(parentPart.mounts) do
        local slot = mount.slot
        table.insert(slots, {
            path = joinPath(path, slot),
            slot = slot,
            name = mount.name or slotName(platform, slot)
        })
    end
    return slots
end

local function slotsForPath(selection, platform, path)
    if not path or path == "" then
        return rootSlots(platform)
    end
    return childSlots(selection, platform, path)
end

local function hasChildSlots(selection, platform, path)
    return #childSlots(selection, platform, path) > 0
end

local function isRootSlot(platform, path)
    if not path or string.find(path, "/", 1, true) then return false end
    for _, slot in ipairs(platform.slots) do
        if slot == path then return true end
    end
    return false
end

local function isValidPath(selection, platform, path)
    if isRootSlot(platform, path) then return true end
    local parent = parentPath(path)
    local slot = leafSlot(path)
    local parentPart = getInstalledPart(selection, parent)
    if not parentPart or not parentPart.mounts then return false end

    for _, mount in ipairs(parentPart.mounts) do
        if mount.slot == slot then return true end
    end
    return false
end

local function pruneInvalidSelections(selection, platform)
    local changed = true
    while changed do
        changed = false
        for path, _ in pairs(selection) do
            if not isValidPath(selection, platform, path) then
                selection[path] = nil
                changed = true
            end
        end
    end
end

local function clearDescendants(selection, slotPath)
    local prefix = slotPath .. "/"
    for path, _ in pairs(selection) do
        if string.sub(path, 1, #prefix) == prefix then
            selection[path] = nil
        end
    end
end

local function pathLabel(selection, platform, path)
    if not path or path == "" then return "枪械" end

    local names = { "枪械" }
    local current = ""
    for segment in string.gmatch(path, "[^/]+") do
        current = joinPath(current, segment)
        local mountName = slotName(platform, segment)
        local parent = parentPath(current)
        local parentPart = parent ~= "" and getInstalledPart(selection, parent) or nil
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

local function appendPartEntry(entries, partId)
    local part = config.parts[partId]
    if part then
        table.insert(entries, partId .. ":" .. part.name)
    end
end

local function buildUiSpec(selection, platform, currentPath)
    local path = currentPath or ""
    local entries = {}

    for _, slot in ipairs(slotsForPath(selection, platform, path)) do
        local partEntries = { emptyPartId .. ":[空]" }
        for _, partId in ipairs(getPartsForSlot(slot.slot)) do
            appendPartEntry(partEntries, partId)
        end

        local slotPath = slot.path
        local currentPartId = tostring(selection[slotPath] or "")
        local canEnter = hasChildSlots(selection, platform, slotPath) and "1" or "0"
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
        pathLabel(selection, platform, path),
        parentPath(path)
    }, "|") .. "::" .. table.concat(entries, ";")
end

local function sortedSelectionPaths(selection)
    local paths = {}
    for path, _ in pairs(selection) do
        table.insert(paths, path)
    end
    table.sort(paths)
    return paths
end

local function buildSignature(selection, platform)
    pruneInvalidSelections(selection, platform)
    local values = {}
    for _, path in ipairs(sortedSelectionPaths(selection)) do
        table.insert(values, path .. ":" .. tostring(selection[path] or ""))
    end
    return table.concat(values, ",")
end

local function buildLayerSpec(selection, platform)
    pruneInvalidSelections(selection, platform)
    local layers = {}
    for _, path in ipairs(sortedSelectionPaths(selection)) do
        local part = getPart(selection[path])
        if part and part.texture and part.source and part.offset then
            local source = part.source
            local offset = part.offset
            table.insert(layers, table.concat({
                selection[path],
                part.texture,
                string.format("%d,%d,%d,%d", source.x, source.y, source.w, source.h),
                string.format("%d,%d", offset.x, offset.y),
                tostring(part.order or 0)
            }, "|"))
        end
    end
    return table.concat(layers, ";")
end

function Gunsmith.Apply(item)
    if SERVER then return end
    if not item or item.removed then return end

    local platform = platformConfig(item)
    if not platform then return end

    local selection = getSelection(item)
    local signature = buildSignature(selection, platform)
    if appliedSignatures[item] == signature then return end

    local layerSpec = buildLayerSpec(selection, platform)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithApply", item, signature, layerSpec, platform.canvas.w, platform.canvas.h)
        appliedSignatures[item] = signature
    else
        print("[Gunsmith] Hook.Call is unavailable; cannot apply composed sprite.")
    end
end

local function cyclePart(item, slotPath)
    local selection = getSelection(item)
    local platform = platformConfig(item)
    if not selection or not platform or not isValidPath(selection, platform, slotPath) then return end

    local parts = getPartsForSlot(leafSlot(slotPath))
    if #parts == 0 then return end

    local current = selection[slotPath]
    local nextIndex = 1
    for index, partId in ipairs(parts) do
        if partId == current then
            nextIndex = index + 1
            break
        end
    end
    if nextIndex > #parts then nextIndex = 1 end

    selection[slotPath] = parts[nextIndex]
    clearDescendants(selection, slotPath)
    pruneInvalidSelections(selection, platform)
    appliedSignatures[item] = nil
    Gunsmith.Apply(item)
end

local function setPart(item, slotPath, partId)
    local selection = getSelection(item)
    local platform = platformConfig(item)
    if not selection or not platform or not isValidPath(selection, platform, slotPath) then return end

    if partId == emptyPartId then
        selection[slotPath] = nil
    else
        local part = config.parts[partId]
        if not part or part.slot ~= leafSlot(slotPath) then return end
        selection[slotPath] = partId
    end

    clearDescendants(selection, slotPath)
    pruneInvalidSelections(selection, platform)
    appliedSignatures[item] = nil
    Gunsmith.Apply(item)
end

local function selectedHandWeapon(character)
    if not character or not character.Inventory then return nil end
    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    if weaponConfig(rightHand) then return rightHand end
    if weaponConfig(leftHand) then return leftHand end
    return nil
end

function Gunsmith.Open(item)
    if SERVER then return end
    if not item or not platformConfig(item) then return end

    local ok, err = pcall(function()
        local platform = platformConfig(item)
        local selection = getSelection(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot open C# gunsmith UI.")
            return
        end

        local currentPath = getCurrentUiPath(item)
        if currentPath ~= "" and #slotsForPath(selection, platform, currentPath) == 0 then
            currentPath = parentPath(currentPath)
            setCurrentUiPath(item, currentPath)
        end

        Hook.Call("DeepGunsmithOpen", item, "改装: " .. itemIdentifier(item), buildUiSpec(selection, platform, currentPath))
    end)

    if not ok then
        print("[Gunsmith] Failed to open v0.2 nested UI: " .. tostring(err))
    end
end

if CLIENT then
    Hook.Add("DeepGunsmithCycle", "DeepGunsmithCycle", function(...)
        local args = { ... }
        local item = nil
        local slotPath = nil

        for _, value in ipairs(args) do
            if LuaUserData.IsTargetType(value, "Barotrauma.Item") then
                item = value
            elseif type(value) == "string" then
                slotPath = value
            end
        end

        if item and slotPath then
            cyclePart(item, slotPath)
            Gunsmith.Open(item)
        end
    end)

    Hook.Add("DeepGunsmithSetPart", "DeepGunsmithSetPart", function(...)
        local args = { ... }
        local item = nil
        local slotPath = nil
        local partId = nil

        for _, value in ipairs(args) do
            if LuaUserData.IsTargetType(value, "Barotrauma.Item") then
                item = value
            elseif type(value) == "string" and not slotPath then
                slotPath = value
            elseif type(value) == "string" then
                partId = value
            end
        end

        if item and slotPath and partId then
            setPart(item, slotPath, partId)
            Gunsmith.Open(item)
        end
    end)

    Hook.Add("DeepGunsmithEnterPath", "DeepGunsmithEnterPath", function(...)
        local args = { ... }
        local item = nil
        local path = nil

        for _, value in ipairs(args) do
            if LuaUserData.IsTargetType(value, "Barotrauma.Item") then
                item = value
            elseif type(value) == "string" then
                path = value
            end
        end

        if item and path then
            setCurrentUiPath(item, path)
            Gunsmith.Open(item)
        end
    end)
end

if CLIENT then
    Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
        if not PlayerInput or not Keys then return end
        local keyOk, keyHit = pcall(function() return PlayerInput.KeyHit(Keys.G) end)
        if not keyOk or not keyHit then return end

        local item = selectedHandWeapon(instance)
        if item then
            setCurrentUiPath(item, getCurrentUiPath(item))
            Gunsmith.Open(item)
        end
    end, Hook.HookMethodType.After)

    Hook.Add("think", "DeepGunsmithApplyDefaults", function()
        local currentTime = Timer.GetTime()
        if currentTime - lastScanTime < 1.0 then return end
        lastScanTime = currentTime

        if not Item or not Item.ItemList then return end
        for item in Item.ItemList do
            if weaponConfig(item) then
                Gunsmith.Apply(item)
            end
        end
    end)

    Hook.Add("item.removed", "DeepGunsmithCleanup", function(item)
        local key = itemKey(item)
        selections[key] = nil
        uiPaths[key] = nil
        appliedSignatures[item] = nil
    end)
end
