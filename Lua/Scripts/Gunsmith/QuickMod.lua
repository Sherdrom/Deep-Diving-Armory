Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local QuickMod = {}
Gunsmith.QuickMod = QuickMod

local itemIdentifierToPartIds = nil

local function itemIdentifier(item)
    if not item or not item.Prefab then return nil end
    return item.Prefab.Identifier.Value
end

local function quickSlotsForItem(item)
    local weapon = Core.WeaponConfig(item)
    if not weapon or type(weapon.quickSlots) ~= "table" then return nil end
    return weapon.quickSlots
end

local function rebuildItemIndex()
    itemIdentifierToPartIds = {}
    for partId, part in pairs(Gunsmith.Config.parts) do
        local identifier = part and part.item and part.item.identifier or nil
        if identifier and identifier ~= "" then
            itemIdentifierToPartIds[identifier] = itemIdentifierToPartIds[identifier] or {}
            table.insert(itemIdentifierToPartIds[identifier], partId)
        end
    end
end

local function partIdsForItemIdentifier(identifier)
    if not itemIdentifierToPartIds then
        rebuildItemIndex()
    end
    return itemIdentifierToPartIds[identifier] or {}
end

local function slotItem(item, slotIndex)
    if not item or not item.OwnInventory or not item.OwnInventory.slots then return nil end
    local slot = item.OwnInventory.slots[slotIndex + 1]
    if not slot or not slot.items then return nil end
    for _, contained in pairs(slot.items) do
        if contained and not contained.removed then
            return contained
        end
    end
    return nil
end

local function findCompatiblePartId(selection, platform, path, identifier)
    for _, partId in ipairs(partIdsForItemIdentifier(identifier)) do
        if Core.IsValidPath(selection, platform, path) and Core.IsPartCompatible(selection, platform, path, partId) then
            return partId
        end
    end
    return nil
end

function QuickMod.PartIdForItem(selection, platform, path, item)
    return findCompatiblePartId(selection, platform, path, itemIdentifier(item))
end

local function beginQuickSlotMutation(item)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithBeginQuickSlotMutation", item)
    end
end

local function endQuickSlotMutation(item)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithEndQuickSlotMutation", item)
    end
end

function QuickMod.IsQuickPath(item, path)
    local quickSlots = quickSlotsForItem(item)
    if not quickSlots or not path then return false end
    for _, quickSlot in ipairs(quickSlots) do
        if quickSlot.path == path then return true end
    end
    return false
end

function QuickMod.IsQuickItem(item)
    local quickSlots = quickSlotsForItem(item)
    return quickSlots ~= nil and #quickSlots > 0
end

function QuickMod.SlotForPath(item, path)
    local quickSlots = quickSlotsForItem(item)
    if not quickSlots or not path then return nil end
    for _, quickSlot in ipairs(quickSlots) do
        if quickSlot.path == path then return quickSlot.slot end
    end
    return nil
end

function QuickMod.CanSlotAcceptItemIdentifier(item, slotIndex, identifier)
    if not item or not item.OwnInventory or slotIndex == nil or not identifier or identifier == "" then return false end
    if not ItemPrefab or not ItemPrefab.GetItemPrefab then return true end

    local prefab = ItemPrefab.GetItemPrefab(identifier)
    if not prefab then return false end

    local ok, result = pcall(function()
        return item.OwnInventory.CanBePutInSlot(prefab, slotIndex, nil)
    end)
    if not ok then
        ok, result = pcall(function()
            return item.OwnInventory.CanBePutInSlot(prefab, slotIndex, 100)
        end)
    end
    return ok and result == true
end

function QuickMod.CanSlotAcceptItem(item, slotIndex, partItem)
    if not item or not item.OwnInventory or slotIndex == nil or not partItem then return false end

    local ok, result = pcall(function()
        return item.OwnInventory.CanBePutInSlot(partItem, slotIndex)
    end)
    return ok and result == true
end

function QuickMod.SyncFromContainer(item, selection, platform)
    if SERVER then return false end
    local quickSlots = quickSlotsForItem(item)
    if not quickSlots or not selection or not platform then return false end

    local changed = false
    for _, quickSlot in ipairs(quickSlots) do
        local path = quickSlot.path
        local contained = slotItem(item, quickSlot.slot)
        local newPartId = nil
        if contained then
            newPartId = findCompatiblePartId(selection, platform, path, itemIdentifier(contained))
        end

        if newPartId then
            if selection[path] ~= newPartId then
                selection[path] = newPartId
                changed = true
            end
        elseif selection[path] ~= nil and not Core.IsRequiredSlot(platform, path) then
            selection[path] = nil
            changed = true
        end
    end

    return changed
end

function QuickMod.InstallPartItem(item, character, part, slotIndex)
    if SERVER then return false end
    if not item or not item.OwnInventory or not part or not part.item or not part.item.identifier then return false end
    local Inventory = Gunsmith.Inventory
    if not Inventory then return false end

    local partItem = Inventory.FindPartItem(character, part.item.identifier, item)
    if not partItem then return false end

    beginQuickSlotMutation(item)
    local ok, result = pcall(function()
        return item.OwnInventory.TryPutItem(partItem, slotIndex, true, false, character, true, false)
    end)
    endQuickSlotMutation(item)
    return ok and result == true
end

function QuickMod.InstallSpecificPartItem(item, character, partItem, slotIndex)
    if SERVER then return false end
    if not item or not item.OwnInventory or not partItem then return false end

    beginQuickSlotMutation(item)
    local ok, result = pcall(function()
        return item.OwnInventory.TryPutItem(partItem, slotIndex, true, false, character, true, false)
    end)
    endQuickSlotMutation(item)
    return ok and result == true
end

function QuickMod.ClearSlot(item, character, slotIndex, onReturned)
    if SERVER then return false end
    local contained = slotItem(item, slotIndex)
    if not contained then return true end

    local identifier = itemIdentifier(contained)
    local prefab = identifier and ItemPrefab and ItemPrefab.GetItemPrefab(identifier) or nil
    local inventory = character and character.Inventory or nil
    local returnQueued = false

    local function notifyReturned(spawned)
        if onReturned then
            onReturned(spawned)
        end
    end

    if prefab and Entity and Entity.Spawner then
        if inventory then
            Entity.Spawner.AddItemToSpawnQueue(prefab, inventory, nil, nil, notifyReturned)
            returnQueued = true
        elseif character and character.WorldPosition then
            Entity.Spawner.AddItemToSpawnQueue(prefab, character.WorldPosition, nil, nil, notifyReturned)
            returnQueued = true
        elseif item.WorldPosition then
            Entity.Spawner.AddItemToSpawnQueue(prefab, item.WorldPosition, nil, nil, notifyReturned)
            returnQueued = true
        end
    end

    if item.OwnInventory and item.OwnInventory.RemoveItem then
        beginQuickSlotMutation(item)
        item.OwnInventory.RemoveItem(contained)
        endQuickSlotMutation(item)
    end
    if Entity and Entity.Spawner and Entity.Spawner.AddItemToRemoveQueue then
        Entity.Spawner.AddItemToRemoveQueue(contained)
    end

    if not returnQueued then
        notifyReturned(nil)
    end

    return true

end
