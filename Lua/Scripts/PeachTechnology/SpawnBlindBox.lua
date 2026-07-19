-- SpawnBlindBox.lua
-- When a StatusEffect triggers a configured <LuaHook name="..." />, this script
-- rolls a weighted "blind box" and spawns the selected item into the
-- target character's inventory (or equips it if configured).
-- Supports multiple hooks, each with an independent item pool.

local MOD_NAME = "SpawnBlindBox"

-- ==================== Configuration ====================
-- debug          : true to print diagnostic logs, false for silent operation
-- hooks          : array of hook configs. Each hook has its own independent item pool.
--   hookName     : string  - must match the name attribute in <LuaHook name="..." />
--   items        : table   - blind box pool for this hook. weight is relative;
--                            higher weight = higher probability of being selected.
--     id         : string  - item prefab identifier
--     weight     : number  - relative probability weight
--     amount     (int)    - how many of this item to spawn per roll (default 1)
--     equip      (bool)   - try to equip to an allowed slot (default: hookConfig.equip)
--     forceEquip (bool)   - replace existing item in slot (default: hookConfig.forceEquip)
--     containIn  (string) - item id of a container already in the
--                            inventory; spawns inside its OwnInventory
--     contains   (table)  - items to spawn inside THIS item's OwnInventory
--                            after it is spawned (e.g. magazine into smg)
--     condition  (float)  - item condition (raw value, clamped to [0, MaxCondition])
--     quality    (int)    - item quality level
--   amount       : number  - blind box rolls per trigger (each roll picks 1 item)
--   equip        : bool    - default equip behavior (overridable per item)
--   forceEquip   : bool    - default force-equip behavior (overridable per item)
--   condition    (float)  - default condition for all items in this pool
--   quality      (int)    - default quality for all items in this pool

local CONFIG = {
    debug = false,

    hooks = {
        {
            hookName = "spawnexample",
            items = {
                {
                    id = "smg",
                    weight = 30,
                    quality = 2,
                    condition = 80,
                    contains = {
                        { id = "smgmagazine", amount = 1, condition = 50 },
                    },
                },
            },
            amount = 1,
            equip = false,
            forceEquip = false,
        },
        -- Example: a second hook with pool-level condition/quality defaults
        -- {
        --     hookName = "spawnarmor",
        --     items = {
        --         { id = "combatsuit",  weight = 40, equip = true },
        --         { id = "divingsuit",  weight = 60, equip = true },
        --     },
        --     amount = 1,
        --     equip = true,
        --     forceEquip = false,
        --     condition = 60,
        --     quality = 1,
        -- },
    },
}

-- ==================== Logging ====================

local function Log(msg)
    if CONFIG.debug then
        print("[" .. MOD_NAME .. "] " .. tostring(msg))
    end
end

local function LogError(msg)
    print("[" .. MOD_NAME .. "][ERROR] " .. tostring(msg))
end

-- ==================== Entity Resolution ====================

-- Resolve the target Character from the entity passed to the LuaHook.
-- StatusEffect may target a Character directly, or an Item held by a Character.
-- Uses LuaUserData.IsTargetType for reliable CLR type checking
-- (entity:GetType().Name is unreliable in MoonSharp; type() returns "userdata").
local function GetCharacterFromEntity(entity)
    if entity == nil then return nil end

    if LuaUserData.IsTargetType(entity, "Barotrauma.Character") then
        return entity
    end

    if LuaUserData.IsTargetType(entity, "Barotrauma.Item") then
        local parentInventory = entity.ParentInventory
        if parentInventory == nil then return nil end
        local owner = parentInventory.Owner
        if owner ~= nil and LuaUserData.IsTargetType(owner, "Barotrauma.Character") then
            return owner
        end
        return nil
    end

    return nil
end

-- ==================== Weighted Random Selection ====================

-- Precompute total weight for each hook config at load time.
for _, hookCfg in ipairs(CONFIG.hooks) do
    local tw = 0
    for _, entry in ipairs(hookCfg.items) do
        local w = entry.weight or 0
        if w < 0 then w = 0 end
        tw = tw + w
    end
    hookCfg.totalWeight = tw

    if tw <= 0 then
        LogError("Hook '" .. tostring(hookCfg.hookName)
            .. "' has empty pool or all weights are zero.")
    end
end

-- Returns the selected item config table for the given hook, or nil if invalid.
local function SelectWeightedItem(hookCfg)
    if hookCfg.totalWeight <= 0 then return nil end

    local roll = math.random(1, hookCfg.totalWeight)
    local accumulated = 0

    for _, entry in ipairs(hookCfg.items) do
        local w = entry.weight or 0
        if w < 0 then w = 0 end
        accumulated = accumulated + w
        if roll <= accumulated then
            return entry
        end
    end

    -- Should never reach here if totalWeight is correct, but guard anyway.
    return hookCfg.items[#hookCfg.items]
end

-- ==================== Item Spawning ====================

-- Equipment slot types to try (excludes InvSlotType.Any).
-- Cannot iterate item.AllowedSlots directly because it returns an
-- IEnumerable<InvSlotType> (HashSet) which is userdata in Lua, not a table.
local EQUIP_SLOT_TYPES = {
    InvSlotType.RightHand,
    InvSlotType.LeftHand,
    InvSlotType.Head,
    InvSlotType.Face,
    InvSlotType.InnerClothes,
    InvSlotType.OuterClothes,
    InvSlotType.Headset,
    InvSlotType.Card,
    InvSlotType.Bag,
}

-- Try to equip an item to one of its allowed equipment slots.
-- Returns true if successfully equipped.
local function TryEquipToSlot(character, inventory, item, forceEquip)
    for _, slotType in ipairs(EQUIP_SLOT_TYPES) do
        local slotIndex = inventory.FindLimbSlot(slotType)
        if slotIndex >= 0 then
            if forceEquip then
                local existingItem = inventory.GetItemInLimbSlot(slotType)
                if existingItem ~= nil then
                    existingItem.Unequip(character)
                    inventory.RemoveItem(existingItem)

                    if inventory.TryPutItem(item, slotIndex, false, false, character, true, false, true) then
                        item.UnequipAutomatically = false
                        Entity.Spawner.AddItemToRemoveQueue(existingItem)
                        Log("Replaced: " .. tostring(existingItem.Prefab.Identifier.Value)
                            .. " with " .. tostring(item.Prefab.Identifier.Value)
                            .. " in slot " .. tostring(slotType))
                        return true
                    end

                    -- New item does not fit this slot, restore old item
                    inventory.ForceToSlot(existingItem, slotIndex)
                    existingItem.Equip(character)
                else
                    if inventory.TryPutItem(item, slotIndex, false, false, character, true, false, true) then
                        item.UnequipAutomatically = false
                        Log("Equipped: " .. tostring(item.Prefab.Identifier.Value)
                            .. " to slot " .. tostring(slotType))
                        return true
                    end
                end
            else
                if inventory.TryPutItem(item, slotIndex, false, false, character, true, false, true) then
                    item.UnequipAutomatically = false
                    Log("Equipped: " .. tostring(item.Prefab.Identifier.Value)
                        .. " to slot " .. tostring(slotType))
                    return true
                end
            end
        end
    end
    return false
end

-- Fallback: place item in the first available Any slot.
local function TryPlaceInAnySlot(character, inventory, item)
    for i = 0, inventory.Capacity - 1 do
        if inventory.IsSlotEmpty(i) then
            if inventory.TryPutItem(item, i, false, false, character, true, false, true) then
                Log("Placed in inventory: " .. tostring(item.Prefab.Identifier.Value))
                return true
            end
        end
    end
    return false
end

-- Spawn contained items inside a spawned item's OwnInventory.
-- Used by the "contains" config: e.g. spawn a magazine inside a just-spawned smg.
local function SpawnContainedItems(spawnedItem, containsConfig)
    if spawnedItem == nil then return end
    if containsConfig == nil or #containsConfig == 0 then return end

    local ownInventory = spawnedItem.OwnInventory
    if ownInventory == nil then
        LogError("Item has no OwnInventory for contains: "
            .. tostring(spawnedItem.Prefab.Identifier.Value))
        return
    end

    for _, subCfg in ipairs(containsConfig) do
        local subPrefab = ItemPrefab.GetItemPrefab(subCfg.id)
        if subPrefab == nil then
            LogError("Contained item prefab not found: " .. tostring(subCfg.id))
        else
            local subAmount = subCfg.amount or 1
            for _ = 1, subAmount do
                Entity.Spawner.AddItemToSpawnQueue(subPrefab, ownInventory,
                    subCfg.condition, subCfg.quality,
                    function(innerItem)
                        if innerItem ~= nil then
                            Log("Spawned contained: " .. tostring(subCfg.id)
                                .. " into " .. tostring(spawnedItem.Prefab.Identifier.Value))
                        end
                    end,
                    true, false, InvSlotType.None)
            end
        end
    end
end

-- Spawn a single item config for a character.
-- hookCfg provides default equip/forceEquip values.
local function SpawnItemForCharacter(character, itemCfg, hookCfg)
    local prefab = ItemPrefab.GetItemPrefab(itemCfg.id)
    if prefab == nil then
        LogError("Item prefab not found: " .. tostring(itemCfg.id))
        return
    end

    local amount = itemCfg.amount or 1
    local equip = itemCfg.equip
    if equip == nil then equip = hookCfg.equip end
    local forceEquip = itemCfg.forceEquip
    if forceEquip == nil then forceEquip = hookCfg.forceEquip end
    local condition = itemCfg.condition
    if condition == nil then condition = hookCfg.condition end
    local quality = itemCfg.quality
    if quality == nil then quality = hookCfg.quality end
    local inventory = character.Inventory

    if inventory == nil then
        LogError("Character inventory is nil for: " .. tostring(character.Name))
        return
    end

    -- containIn: spawn inside another item's OwnInventory
    if itemCfg.containIn ~= nil then
        local containerItem = inventory.FindItemByIdentifier(itemCfg.containIn, true)
        if containerItem == nil then
            LogError("Container not found: " .. tostring(itemCfg.containIn)
                .. ", falling back to character inventory for: " .. tostring(itemCfg.id))
            for _ = 1, amount do
                Entity.Spawner.AddItemToSpawnQueue(prefab, inventory,
                    condition, quality,
                    function(spawnedItem)
                        if spawnedItem ~= nil then
                            Log("Spawned (fallback): " .. tostring(itemCfg.id))
                        end
                    end,
                    true, false, InvSlotType.None)
            end
            return
        end

        if containerItem.OwnInventory == nil then
            LogError("Container has no OwnInventory: " .. tostring(itemCfg.containIn))
            return
        end

        for _ = 1, amount do
            Entity.Spawner.AddItemToSpawnQueue(prefab, containerItem.OwnInventory,
                condition, quality,
                function(spawnedItem)
                    if spawnedItem ~= nil then
                        Log("Spawned: " .. tostring(itemCfg.id)
                            .. " into " .. tostring(itemCfg.containIn))
                    end
                end,
                true, false, InvSlotType.None)
        end
        return
    end

    for _ = 1, amount do
        if equip then
            -- Equip path: spawn at position, then manually equip via slot index.
            Entity.Spawner.AddItemToSpawnQueue(prefab, character.WorldPosition,
                condition, quality,
                function(spawnedItem)
                    if spawnedItem == nil then return end
                    if character.Removed or character.IsDead then
                        Entity.Spawner.AddItemToRemoveQueue(spawnedItem)
                        return
                    end

                    if not TryEquipToSlot(character, inventory, spawnedItem, forceEquip) then
                        if not TryPlaceInAnySlot(character, inventory, spawnedItem) then
                            LogError("Could not place item: " .. tostring(itemCfg.id))
                        end
                    end

                    SpawnContainedItems(spawnedItem, itemCfg.contains)
                end)
        else
            -- Inventory path: spawn directly into inventory.
            Entity.Spawner.AddItemToSpawnQueue(prefab, inventory,
                condition, quality,
                function(spawnedItem)
                    if spawnedItem ~= nil then
                        Log("Spawned: " .. tostring(itemCfg.id) .. " (inventory)")
                        SpawnContainedItems(spawnedItem, itemCfg.contains)
                    end
                end,
                true, false, InvSlotType.None)
        end
    end
end

-- ==================== Hook Registration ====================

-- Note: Do NOT use the SERVER compile-time constant here.
-- On the client build (single-player, hosting), SERVER is always false.
-- EntitySpawner.AddItemToSpawnQueue already checks GameMain.NetworkMember.IsClient
-- internally and returns early on remote clients, preventing item duplication.

for _, hookCfg in ipairs(CONFIG.hooks) do
    Hook.Add(hookCfg.hookName, MOD_NAME .. ".OnTrigger." .. hookCfg.hookName,
        function(effect, deltaTime, entity, targets, worldPosition, element)
            local character = GetCharacterFromEntity(entity)
            if character == nil then
                Log("[" .. hookCfg.hookName .. "] Could not resolve character from entity, skipping.")
                return
            end
            if character.Removed or character.IsDead then return end
            if character.Inventory == nil then return end

            for _ = 1, hookCfg.amount do
                local selected = SelectWeightedItem(hookCfg)
                if selected == nil then
                    LogError("[" .. hookCfg.hookName .. "] No item selected from pool (check weight config).")
                    return
                end

                Log("[" .. hookCfg.hookName .. "] Blind box rolled: " .. tostring(selected.id)
                    .. " (weight " .. tostring(selected.weight) .. ")")
                SpawnItemForCharacter(character, selected, hookCfg)
            end
        end)
end

-- ==================== Load Log ====================

local hookNames = {}
for _, hookCfg in ipairs(CONFIG.hooks) do
    hookNames[#hookNames + 1] = hookCfg.hookName
end

Log("Loaded. Hooks: " .. table.concat(hookNames, ", ")
    .. ", hook count: " .. #CONFIG.hooks)
