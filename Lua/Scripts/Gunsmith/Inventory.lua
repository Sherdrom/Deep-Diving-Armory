Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Inventory = {}
Gunsmith.Inventory = Inventory

local function currentCharacter(item)
    if item and item.ParentInventory and item.ParentInventory.Owner then
        return item.ParentInventory.Owner
    end
    if Character and Character.Controlled then
        return Character.Controlled
    end
    return nil
end

local function characterInventory(character)
    if character and character.Inventory then
        return character.Inventory
    end
    return nil
end

local function itemIdentifier(item)
    if not item or not item.Prefab then return nil end
    return item.Prefab.Identifier.Value
end

function Inventory.ActorForItem(item)
    return currentCharacter(item)
end

function Inventory.ItemIdentifierForPart(part)
    if not part then return nil end
    if not part.item then return nil end
    return part.item.identifier
end

function Inventory.IsVirtualPart(part)
    return part and part.item and part.item.virtual == true
end

function Inventory.FindPartItem(character, identifier)
    local inventory = characterInventory(character)
    if not inventory or not identifier or identifier == "" then return nil end

    local ok, found = pcall(function()
        return inventory.FindItemByIdentifier(identifier, true)
    end)
    if ok and found then return found end

    if not inventory.slots then return nil end
    for _, slot in pairs(inventory.slots) do
        if slot and slot.items then
            for _, item in pairs(slot.items) do
                if itemIdentifier(item) == identifier then
                    return item
                end
            end
        end
    end
    return nil
end

function Inventory.HasPartItem(character, part)
    local identifier = Inventory.ItemIdentifierForPart(part)
    if not identifier then return true end
    return Inventory.FindPartItem(character, identifier) ~= nil
end

function Inventory.ConsumePartItem(character, part)
    local identifier = Inventory.ItemIdentifierForPart(part)
    if not identifier then return true end

    local item = Inventory.FindPartItem(character, identifier)
    if not item then return false end

    if Entity and Entity.Spawner and Entity.Spawner.AddItemToRemoveQueue then
        Entity.Spawner.AddItemToRemoveQueue(item)
    elseif item.ParentInventory and item.ParentInventory.RemoveItem then
        item.ParentInventory.RemoveItem(item)
    end
    return true
end

function Inventory.ReturnPartItem(character, part, onReturned, sourceItem)
    local identifier = Inventory.ItemIdentifierForPart(part)
    if not identifier or not ItemPrefab or not Entity or not Entity.Spawner then return false end

    local prefab = ItemPrefab.GetItemPrefab(identifier)
    if not prefab then
        print("[Gunsmith] Cannot return missing part item prefab: " .. tostring(identifier))
        return false
    end

    local function notifyReturned(spawned)
        if onReturned then
            onReturned(spawned)
        end
    end

    local inventory = characterInventory(character)
    if inventory then
        Entity.Spawner.AddItemToSpawnQueue(prefab, inventory, nil, nil, notifyReturned)
        return true
    end

    if character and character.WorldPosition then
        Entity.Spawner.AddItemToSpawnQueue(prefab, character.WorldPosition, nil, nil, notifyReturned)
        return true
    end

    if sourceItem and sourceItem.WorldPosition then
        Entity.Spawner.AddItemToSpawnQueue(prefab, sourceItem.WorldPosition, nil, nil, notifyReturned)
        return true
    end

    return false
end
