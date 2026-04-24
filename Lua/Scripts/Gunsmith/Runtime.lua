Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Persistence = Gunsmith.Persistence
local UiSpec = Gunsmith.UiSpec
local Inventory = Gunsmith.Inventory
local Runtime = {}

Gunsmith.Runtime = Runtime
Gunsmith.EmptyPartId = "__empty"
Gunsmith.State = Gunsmith.State or {
    selections = {},
    appliedSignatures = {},
    uiPaths = {},
    loadedStates = {},
    lastScanTime = 0
}

local State = Gunsmith.State

function Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    if not platform then return nil end

    local key = Core.ItemKey(item)
    if not State.selections[key] then
        State.selections[key] = Core.CopyDefaults(platform)
        if not State.loadedStates[key] then
            State.loadedStates[key] = true
            Persistence.Request(item)
        end
    end
    return State.selections[key]
end

function Runtime.GetCurrentUiPath(item)
    local key = Core.ItemKey(item)
    if not key then return "" end
    return State.uiPaths[key] or ""
end

function Runtime.SetCurrentUiPath(item, path)
    local key = Core.ItemKey(item)
    if not key then return end
    State.uiPaths[key] = path or ""
end

local function buildSignature(selection, platform)
    Core.PruneInvalidSelections(selection, platform)
    local values = {}
    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        table.insert(values, path .. ":" .. tostring(selection[path] or ""))
    end
    return table.concat(values, ",")
end

local function buildLayerSpec(selection, platform)
    Core.PruneInvalidSelections(selection, platform)
    local layers = {}
    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        local part = Core.GetPart(selection[path])
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

function Runtime.Apply(item)
    if SERVER then return end
    if not item or item.removed then return end

    local platform = Core.PlatformConfig(item)
    if not platform then return end

    local selection = Runtime.GetSelection(item)
    local signature = buildSignature(selection, platform)
    if State.appliedSignatures[item] == signature then return end

    local layerSpec = buildLayerSpec(selection, platform)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithApply", item, signature, layerSpec, platform.canvas.w, platform.canvas.h)
        State.appliedSignatures[item] = signature
    else
        print("[Gunsmith] Hook.Call is unavailable; cannot apply composed sprite.")
    end
end

function Runtime.CyclePart(item, slotPath)
    local selection = Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    if not selection or not platform or not Core.IsValidPath(selection, platform, slotPath) then return end

    local parts = Core.GetPartsForSlot(Core.LeafSlot(slotPath))
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
    Core.ClearDescendants(selection, slotPath)
    Core.PruneInvalidSelections(selection, platform)
    Persistence.Save(item)
    State.appliedSignatures[item] = nil
    Runtime.Apply(item)
end

local function selectionSubtreePaths(selection, slotPath)
    local paths = {}
    local prefix = slotPath .. "/"
    for path, _ in pairs(selection) do
        if path == slotPath or string.sub(path, 1, #prefix) == prefix then
            table.insert(paths, path)
        end
    end
    table.sort(paths, function(left, right)
        local _, leftDepth = string.gsub(left, "/", "")
        local _, rightDepth = string.gsub(right, "/", "")
        if leftDepth == rightDepth then return left > right end
        return leftDepth > rightDepth
    end)
    return paths
end

local function returnSelectionSubtree(character, selection, slotPath, onAllReturned)
    if not Inventory then return 0 end
    local parts = {}
    for _, path in ipairs(selectionSubtreePaths(selection, slotPath)) do
        local part = Core.GetPart(selection[path])
        if part and Inventory.ItemIdentifierForPart(part) then
            table.insert(parts, part)
        end
    end

    local pending = #parts
    if pending == 0 then return 0 end

    local completed = 0
    local function onReturned()
        completed = completed + 1
        if completed >= pending and onAllReturned then
            onAllReturned()
        end
    end

    for _, part in ipairs(parts) do
        if not Inventory.ReturnPartItem(character, part, onReturned) then
            pending = pending - 1
        end
    end

    if pending == 0 then return 0 end
    return pending
end

function Runtime.SetPart(item, slotPath, partId)
    local selection = Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    if not selection or not platform or not Core.IsValidPath(selection, platform, slotPath) then return end

    local character = Inventory and Inventory.ActorForItem(item) or nil
    local returnedParts = 0
    local refreshWhenReturned = function()
        if item and not item.removed then
            Runtime.Open(item)
        end
    end

    if partId == Gunsmith.EmptyPartId then
        if Core.IsRequiredSlot(platform, slotPath) then return end
        returnedParts = returnSelectionSubtree(character, selection, slotPath, refreshWhenReturned)
        selection[slotPath] = nil
    else
        local part = Gunsmith.Config.parts[partId]
        if not part or part.slot ~= Core.LeafSlot(slotPath) then return end
        if selection[slotPath] == partId then return end
        if Inventory and not Inventory.ConsumePartItem(character, part) then
            print("[Gunsmith] Missing part item for " .. tostring(partId))
            return
        end
        returnedParts = returnSelectionSubtree(character, selection, slotPath, refreshWhenReturned)
        selection[slotPath] = partId
    end

    Core.ClearDescendants(selection, slotPath)
    Core.PruneInvalidSelections(selection, platform)
    Persistence.Save(item)
    State.appliedSignatures[item] = nil
    Runtime.Apply(item)
    if returnedParts and returnedParts > 0 then
        return false
    end
    return true
end

function Runtime.SelectedHandWeapon(character)
    if not character or not character.Inventory then return nil end
    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    if Core.WeaponConfig(rightHand) then return rightHand end
    if Core.WeaponConfig(leftHand) then return leftHand end
    return nil
end

function Runtime.Open(item)
    if SERVER then return end
    if not item or not Core.PlatformConfig(item) then return end

    local ok, err = pcall(function()
        local platform = Core.PlatformConfig(item)
        local selection = Runtime.GetSelection(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot open C# gunsmith UI.")
            return
        end

        local currentPath = Runtime.GetCurrentUiPath(item)
        if currentPath ~= "" and #Core.SlotsForPath(selection, platform, currentPath) == 0 then
            currentPath = Core.ParentPath(currentPath)
            Runtime.SetCurrentUiPath(item, currentPath)
        end

        Hook.Call("DeepGunsmithOpen", item, "改装: " .. Core.ItemIdentifier(item), UiSpec.Build(item, selection, platform, currentPath))
    end)

    if not ok then
        print("[Gunsmith] Failed to open v0.2 nested UI: " .. tostring(err))
    end
end

function Runtime.Cleanup(item)
    local key = Core.ItemKey(item)
    if not key then return end
    State.selections[key] = nil
    State.uiPaths[key] = nil
    State.loadedStates[key] = nil
    State.appliedSignatures[item] = nil
end

Gunsmith.Apply = Runtime.Apply
Gunsmith.Open = Runtime.Open
