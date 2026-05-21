Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Inventory = {}
Gunsmith.Inventory = Inventory

local parentInventory

local function currentCharacter(item)
    local inventory = parentInventory(item)
    if inventory and inventory.Owner then
        return inventory.Owner
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

local function inventoryOwner(inventory)
    if not inventory then return nil end
    return inventory.Owner
end

parentInventory = function(item)
    if not item then return nil end
    if not LuaUserData.IsTargetType(item, "Barotrauma.Item") then return nil end
    return item.ParentInventory
end

local function isSourceInventory(inventory, sourceItem)
    if not inventory or not sourceItem then return false end
    if sourceItem.OwnInventory and inventory == sourceItem.OwnInventory then return true end
    return inventoryOwner(inventory) == sourceItem
end

local function isInSourceItemInventory(item, sourceItem)
    if not item or not sourceItem then return false end
    if item == sourceItem then return true end

    local inventory = parentInventory(item)
    while inventory do
        if isSourceInventory(inventory, sourceItem) then return true end

        local owner = inventoryOwner(inventory)
        inventory = parentInventory(owner)
    end

    return false
end

local function findItemInInventory(inventory, identifier, sourceItem, visited)
    if not inventory or not inventory.slots then return nil end
    visited = visited or {}
    if visited[inventory] then return nil end
    visited[inventory] = true

    if isSourceInventory(inventory, sourceItem) then return nil end

    for _, slot in pairs(inventory.slots) do
        if slot and slot.items then
            for _, item in pairs(slot.items) do
                if item and not item.removed and not isInSourceItemInventory(item, sourceItem) then
                    if Core.ItemIdentifier(item) == identifier then
                        return item
                    end

                    local nested = findItemInInventory(item.OwnInventory, identifier, sourceItem, visited)
                    if nested then return nested end
                end
            end
        end
    end

    return nil
end

function Inventory.ActorForItem(item)
    return currentCharacter(item)
end

function Inventory.ItemIdentifierForPart(part)
    if not part then return nil end
    if not part.item then return nil end
    return part.item.identifier
end

function Inventory.FindPartItem(character, identifier, sourceItem)
    local inventory = characterInventory(character)
    if not inventory or not identifier or identifier == "" then return nil end

    return findItemInInventory(inventory, identifier, sourceItem, {})
end

function Inventory.HasPartItem(character, part, sourceItem)
    local identifier = Inventory.ItemIdentifierForPart(part)
    if not identifier then return true end
    return Inventory.FindPartItem(character, identifier, sourceItem) ~= nil
end

function Inventory.ConsumePartItem(character, part, sourceItem)
    local identifier = Inventory.ItemIdentifierForPart(part)
    if not identifier then return true end

    local item = Inventory.FindPartItem(character, identifier, sourceItem)
    if not item then return false end

    if Entity and Entity.Spawner and Entity.Spawner.AddItemToRemoveQueue then
        Entity.Spawner.AddItemToRemoveQueue(item)
    else
        local parent = parentInventory(item)
        if parent and parent.RemoveItem then
            parent.RemoveItem(item)
        end
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
