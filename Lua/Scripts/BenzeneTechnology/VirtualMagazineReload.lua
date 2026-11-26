if SERVER then return end

local isVirtualMagazine = Deep_Lua.HF.IsVirtualMagazine

local function stackEmptyMagazine(character, magazine)
    if magazine.Removed or magazine.Condition ~= 0 or not magazine.IsInteractable(character) then return end

    local function tryStackIn(destination)
        if not character.CanAccessInventory(destination) then return end
        local currentSlot = destination == magazine.ParentInventory and destination.FindIndex(magazine)
        for slot = 0, destination.Capacity - 1 do
            local other = destination.GetItemAt(slot)
            if slot ~= currentSlot and other and not other.Removed and other.Condition == 0
                and other.Prefab.Identifier.Equals(magazine.Prefab.Identifier)
                and destination.CanBePutInSlot(magazine, slot)
                and destination.TryPutItem(magazine, slot, false, false, character, true, false) then
                return true
            end
        end
    end

    if tryStackIn(character.Inventory) then return true end
    for item in character.Inventory.AllItemsMod do
        if not item.Removed and not item.HasTag("weapon") and not isVirtualMagazine(item)
            and item.OwnInventory and tryStackIn(item.OwnInventory) then
            return true
        end
    end
end

local function retryStackEmptyMagazine(character, magazine)
    local stowedIn = magazine.ParentInventory
    if not stowedIn then return end
    local function retry(remaining)
        if character.Removed or magazine.Removed or magazine.Condition ~= 0 or magazine.ParentInventory ~= stowedIn
            or magazine.GetRootInventoryOwner() ~= character or not character.CanAccessInventory(stowedIn) then return end
        if not stackEmptyMagazine(character, magazine) and Game.IsMultiplayer and remaining > 0 then
            Timer.Wait(function() retry(remaining - 1) end, 300)
        end
    end
    retry(3)
end

local function unloadEmptyMagazine(character, magazine)
    if magazine.Removed or magazine.Condition ~= 0 or not magazine.IsInteractable(character) then return end
    if stackEmptyMagazine(character, magazine) then return end

    local inventory = character.Inventory
    if character.CanAccessInventory(inventory) then
        for _, slot in ipairs({ InvSlotType.Bag, InvSlotType.OuterClothes, InvSlotType.InnerClothes }) do
            local gear = inventory.GetItemInLimbSlot(slot)
            local destination = gear and gear.OwnInventory
            if destination and character.CanAccessInventory(destination) and destination.TryPutItem(magazine, character) then
                retryStackEmptyMagazine(character, magazine)
                return
            end
        end
        if character.TryPutItemInAnySlot(magazine) then
            retryStackEmptyMagazine(character, magazine)
            return
        end
    end
    magazine.Drop(character, true, true)
end

Hook.Add("pressrtoreload.reload", "DDA.VirtualMagazine.Reload", function(request)
    if request.handled then return end
    local character, weapon, inventory = request.character, request.weapon, request.inventory
    local package = weapon and weapon.Prefab.ContentPackage
    if not character or not inventory or not package or package.Name ~= "Deep-Diving-Armory" then return end

    local container = inventory.Container
    local slot = math.max(container.ContainedStateIndicatorSlot, 0)
    local current = inventory.GetItemAt(slot)
    if current and not isVirtualMagazine(current) then return end
    -- VCE uses the integer MaxCondition as its round capacity.
    if current and current.Condition >= math.floor(current.MaxCondition) then
        request.handled = true
        return
    end

    local candidates, visited = {}, {}
    local function collect(source)
        if visited[source] or not character.CanAccessInventory(source) then return end
        visited[source] = true
        for item in source.AllItemsMod do
            if not item.Removed and item ~= weapon and item ~= request.otherWeapon and not item.HasTag("weapon") then
                local virtual = isVirtualMagazine(item)
                -- VCE mirrors the round count to the item's Condition.
                if virtual and item ~= current and item.Condition > 0
                    and item.IsInteractable(character) and container.CanBeContained(item, slot) then
                    candidates[#candidates + 1] = { item = item, count = item.Condition }
                elseif not virtual and item.OwnInventory then
                    collect(item.OwnInventory)
                end
            end
        end
    end
    collect(character.Inventory)
    -- Empty weapons with only legacy magazines still use Press R's original reload.
    if not current and #candidates == 0 then return end
    -- A failed virtual swap must not fall through to automatic ammo merging.
    request.handled = true
    if not character.CanAccessInventory(inventory) then return end
    if #candidates == 0 then
        unloadEmptyMagazine(character, current)
        return
    end
    table.sort(candidates, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.item.ID < b.item.ID
    end)
    -- Stacking first also makes room when the spare comes from a full inventory stack.
    local stacked = current and stackEmptyMagazine(character, current)
    for _, candidate in ipairs(candidates) do
        if inventory.TryPutItem(candidate.item, slot, not stacked, false, character, true, false) then
            if not stacked and current and current.Condition == 0 and current.ParentInventory ~= inventory then
                retryStackEmptyMagazine(character, current)
            end
            return
        end
    end
    if stacked then
        inventory.TryPutItem(current, slot, false, false, character, true, false, false)
    end
end)
