Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Persistence = Gunsmith.Persistence
local UiSpec = Gunsmith.UiSpec
local QuickUiSpec = Gunsmith.QuickUiSpec
local Inventory = Gunsmith.Inventory
local Stats = Gunsmith.Stats
local QuickMod = Gunsmith.QuickMod
local Runtime = {}

Gunsmith.Runtime = Runtime
Gunsmith.EmptyPartId = "__empty"
Gunsmith.State = Gunsmith.State or {
    selections = {},
    appliedSignatures = {},
    uiPaths = {},
    loadedStates = {}
}

local State = Gunsmith.State
local finishQuickModChange

function Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    if not platform then return nil end

    local key = Core.ItemKey(item)
    if not State.selections[key] then
        State.selections[key] = Core.BuildDefaultSelection(platform, Core.WeaponConfig(item))
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
    State.uiPaths[key] = Core.NormalizeUiPath(Core.PlatformConfig(item), path or "")
end

function Runtime.SchedulePartsRefresh(item, delay)
    if SERVER then return end
    if not item or item.removed then return end
    Runtime.RefreshParts(item)
end

function Runtime.RefreshParts(item)
    if SERVER then return end
    if not item or not Core.PlatformConfig(item) then return end

    local ok, err = pcall(function()
        local platform = Core.PlatformConfig(item)
        local selection = Runtime.GetSelection(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot refresh C# gunsmith parts UI.")
            return
        end

        if QuickMod and QuickMod.SyncFromContainer(item, selection, platform) then
            State.appliedSignatures[item] = nil
            Persistence.Save(item)
        end

        local currentPath = Runtime.GetCurrentUiPath(item)
        if currentPath ~= "" and #Core.SlotsForPath(selection, platform, currentPath) == 0 then
            currentPath = Core.UiParentPath(platform, currentPath)
            Runtime.SetCurrentUiPath(item, currentPath)
        end

        Hook.Call("DeepGunsmithRefreshParts", item, UiSpec.Build(item, selection, platform, currentPath))
    end)

    if not ok then
        print("[Gunsmith] Failed to refresh parts UI: " .. tostring(err))
    end
end

function Runtime.RefreshQuick(item)
    if SERVER then return end
    if not item or not Core.PlatformConfig(item) then return end

    local ok, err = pcall(function()
        local platform = Core.PlatformConfig(item)
        local selection = Runtime.GetSelection(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot refresh C# gunsmith quick UI.")
            return
        end

        if QuickMod and QuickMod.SyncFromContainer(item, selection, platform) then
            State.appliedSignatures[item] = nil
            Persistence.Save(item)
        end

        Hook.Call("DeepGunsmithRefreshQuick", item, QuickUiSpec.Build(item, selection, platform))
    end)

    if not ok then
        print("[Gunsmith] Failed to refresh quick UI: " .. tostring(err))
    end
end

function Runtime.SyncQuickModContainerItem(item)
    if SERVER then return end
    if not QuickMod then return end
    if not item or item.removed then return end

    local platform = Core.PlatformConfig(item)
    if not platform then return end

    local selection = Runtime.GetSelection(item)
    if not selection then return end

    if QuickMod.SyncFromContainer(item, selection, platform) then
        finishQuickModChange(item, selection, platform, Core.WeaponConfig(item))
        Runtime.RefreshParts(item)
    end
end

finishQuickModChange = function(item, selection, platform, weapon)
    QuickMod.SyncFromContainer(item, selection, platform)
    Core.PruneInvalidSelections(selection, platform, weapon)
    Persistence.Save(item)
    State.appliedSignatures[item] = nil
    Runtime.Apply(item)
end

local function buildSignature(item, selection, platform)
    Core.PruneInvalidSelections(selection, platform, Core.WeaponConfig(item))
    local values = {}
    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        table.insert(values, path .. ":" .. tostring(selection[path] or ""))
    end
    return table.concat(values, ",")
end

local resolveDrawOffset

local function visualScale(visual)
    if type(visual) == "table" and type(visual.scale) == "number" and visual.scale > 0 then
        return visual.scale
    end
    return 1.0
end

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

local function buildLayerSpecForItem(item, selection, platform)
    local weapon = Core.WeaponConfig(item)
    Core.PruneInvalidSelections(selection, platform, weapon)
    local layers = {}
    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        local part = Core.GetPart(selection[path])
        local visual = Core.PartVisual(part)
        if visual and visual.texture and visual.source then
            local source = visual.source
            local drawOffset = resolveDrawOffset(selection, platform, weapon, path, visual)
            if drawOffset then
                local scale = visual.scale or 1.0
                local mount = Core.MountForPath(selection, path)
                local order = mount and mount.visualOrder or visual.order or 0
                table.insert(layers, table.concat({
                    path,
                    selection[path],
                    visual.texture,
                    string.format("%d,%d,%d,%d", source.x, source.y, source.w, source.h),
                    string.format("%.4f,%.4f", drawOffset.x, drawOffset.y),
                    tostring(order),
                    string.format("%.4f", scale)
                }, "|"))
            end
        end
    end
    return table.concat(layers, ";")
end

local function encodeInventorySettings(item)
    local weapon = Core.WeaponConfig(item) or {}
    local inventory = weapon.inventory or {}
    return string.format(
        "scale=%.4f,rotation=%.4f,padding=%.4f",
        inventory.scale or 1.0,
        inventory.rotation or 0.0,
        inventory.padding or 0.0)
end

local function encodeWorldSettings(item)
    local weapon = Core.WeaponConfig(item) or {}
    local world = weapon.world or {}
    local offset = world.offset or { x = 0, y = 0 }
    return string.format(
        "scale=%.4f,rotation=%.4f,padding=%.4f,offsetX=%.4f,offsetY=%.4f",
        world.scale or 1.0,
        world.rotation or 0.0,
        world.padding or 0.0,
        offset.x or 0.0,
        offset.y or 0.0)
end

local function encodeManagedItems(selection)
    return table.concat(Stats.ManagedItemIdentifiers(selection), ",")
end

function Runtime.Apply(item)
    if SERVER then return end
    if not item or item.removed then return end

    local platform = Core.PlatformConfig(item)
    if not platform then return end

    local selection = Runtime.GetSelection(item)
    if QuickMod and QuickMod.SyncFromContainer(item, selection, platform) then
        State.appliedSignatures[item] = nil
        Persistence.Save(item)
    end
    local inventorySpec = encodeInventorySettings(item)
    local worldSpec = encodeWorldSettings(item)
    local statsSpec = Stats.Encode(Stats.SumSelection(selection))
    local managedItemSpec = encodeManagedItems(selection)
    local signature = buildSignature(item, selection, platform) .. "|inventory:" .. inventorySpec .. "|world:" .. worldSpec .. "|stats:" .. statsSpec .. "|items:" .. managedItemSpec
    if State.appliedSignatures[item] == signature then return end

    local layerSpec = buildLayerSpecForItem(item, selection, platform)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithApply", item, signature, layerSpec, inventorySpec, worldSpec, statsSpec, managedItemSpec, platform.canvas.w, platform.canvas.h)
        State.appliedSignatures[item] = signature
    else
        print("[Gunsmith] Hook.Call is unavailable; cannot apply composed sprite.")
    end
end

function Runtime.CyclePart(item, slotPath)
    local selection = Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    local weapon = Core.WeaponConfig(item)
    if not selection or not platform or not Core.IsValidPath(selection, platform, slotPath) then return end

    local parts = {}
    for _, partId in ipairs(Core.GetPartsForType(Core.PartTypeForPath(selection, slotPath))) do
        if Core.IsPartCompatible(selection, platform, slotPath, partId) then
            table.insert(parts, partId)
        end
    end
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

    return Runtime.SetPart(item, slotPath, parts[nextIndex])
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

local function returnSelectionSubtree(character, sourceItem, selection, slotPath, onAllReturned)
    if not Inventory then return 0 end
    local parts = {}
    for _, path in ipairs(selectionSubtreePaths(selection, slotPath)) do
        local partId = selection[path]
        local part = Core.GetPart(partId)
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
        if not Inventory.ReturnPartItem(character, part, onReturned, sourceItem) then
            pending = pending - 1
        end
    end

    if pending == 0 then return 0 end
    return pending
end

function Runtime.SetPart(item, slotPath, partId, refreshMode)
    local selection = Runtime.GetSelection(item)
    local platform = Core.PlatformConfig(item)
    local weapon = Core.WeaponConfig(item)
    if not selection or not platform or not Core.IsValidPath(selection, platform, slotPath) then return end

    local character = Inventory and Inventory.ActorForItem(item) or nil

    if QuickMod and QuickMod.IsQuickPath(item, slotPath) then
        local refreshQuick = refreshMode == "quick"
        local slotIndex = QuickMod.SlotForPath(item, slotPath)
        if slotIndex == nil then return end
        local refreshAfterReturn = function()
            if refreshQuick then
                Runtime.RefreshQuick(item)
            else
                Runtime.SchedulePartsRefresh(item, 0)
            end
        end

        if partId == Gunsmith.EmptyPartId then
            if Core.IsRequiredSlot(platform, slotPath) then return end
            if not QuickMod.ClearSlot(item, character, slotIndex, refreshAfterReturn) then return end
        else
            local part = Gunsmith.Config.parts[partId]
            if not part or not Core.IsPartCompatible(selection, platform, slotPath, partId) then return end
            if selection[slotPath] == partId then return true end
            if not Inventory or not Inventory.FindPartItem(character, Inventory.ItemIdentifierForPart(part), item) then
                print("[Gunsmith] Missing quick-mod part item for " .. tostring(partId))
                return
            end
            if not QuickMod.ClearSlot(item, character, slotIndex, refreshAfterReturn) then return end
            if not QuickMod.InstallPartItem(item, character, part, slotIndex) then return end
        end

        finishQuickModChange(item, selection, platform, weapon)
        if refreshQuick then
            Runtime.RefreshQuick(item)
        else
            Runtime.SchedulePartsRefresh(item, 0)
        end
        return false
    end

    local returnedParts = 0
    local refreshWhenReturned = function()
        if item and not item.removed then
            Runtime.Open(item)
        end
    end

    if partId == Gunsmith.EmptyPartId then
        if Core.IsRequiredSlot(platform, slotPath) then return end
        returnedParts = returnSelectionSubtree(character, item, selection, slotPath, refreshWhenReturned)
        selection[slotPath] = nil
    else
        local part = Gunsmith.Config.parts[partId]
        if not part or not Core.IsPartCompatible(selection, platform, slotPath, partId) then return end
        if selection[slotPath] == partId then return end
        if Inventory and not Inventory.ConsumePartItem(character, part, item) then
            print("[Gunsmith] Missing part item for " .. tostring(partId))
            return
        end
        returnedParts = returnSelectionSubtree(character, item, selection, slotPath, refreshWhenReturned)
        selection[slotPath] = partId
    end

    Core.ClearDescendants(selection, slotPath)
    if partId ~= Gunsmith.EmptyPartId then
        Core.ApplyMountDefaultsForPath(selection, slotPath, {}, 0)
    end
    Core.PruneInvalidSelections(selection, platform, weapon)
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

        if QuickMod and QuickMod.SyncFromContainer(item, selection, platform) then
            State.appliedSignatures[item] = nil
            Persistence.Save(item)
        end

        local currentPath = Runtime.GetCurrentUiPath(item)
        if currentPath ~= "" and #Core.SlotsForPath(selection, platform, currentPath) == 0 then
            currentPath = Core.UiParentPath(platform, currentPath)
            Runtime.SetCurrentUiPath(item, currentPath)
        end

        Runtime.Apply(item)
        Hook.Call("DeepGunsmithOpen", item, "deep.gunsmith.ui.title", UiSpec.Build(item, selection, platform, currentPath))
    end)

    if not ok then
        print("[Gunsmith] Failed to open v0.2 nested UI: " .. tostring(err))
    end
end

function Runtime.OpenQuick(item)
    if SERVER then return end
    if not item or not Core.PlatformConfig(item) or not QuickMod or not QuickMod.IsQuickItem(item) then return end

    local ok, err = pcall(function()
        local platform = Core.PlatformConfig(item)
        local selection = Runtime.GetSelection(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot open C# gunsmith quick UI.")
            return
        end

        if QuickMod.SyncFromContainer(item, selection, platform) then
            State.appliedSignatures[item] = nil
            Persistence.Save(item)
        end

        Runtime.Apply(item)
        Hook.Call("DeepGunsmithOpenQuick", item, "deep.gunsmith.ui.quick_title", QuickUiSpec.Build(item, selection, platform))
    end)

    if not ok then
        print("[Gunsmith] Failed to open quick UI: " .. tostring(err))
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
Gunsmith.OpenQuick = Runtime.OpenQuick
