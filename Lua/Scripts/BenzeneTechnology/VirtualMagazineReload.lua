if SERVER then return end

local virtualType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
LuaUserData.RegisterType(virtualType)

local function magazineOf(item)
    if not item or not item.HasTag("556mag") then return end
    local container = item.OwnInventory and item.OwnInventory.Container
    if container and LuaUserData.IsTargetType(container, virtualType) then return container end
end

Hook.Add("pressrtoreload.reload", "DDA.VirtualMagazine.Reload", function(request)
    if request.handled then return end
    local character, weapon, inventory = request.character, request.weapon, request.inventory
    local reference = ItemPrefab.GetItemPrefab("deep_5.56x45")
    if not character or not weapon or not inventory or not reference
        or weapon.Prefab.ContentPackage ~= reference.ContentPackage then return end

    local container = inventory.Container
    local slot = math.max(container.ContainedStateIndicatorSlot, 0)
    if not container.CanBeContained(reference, slot) then return end
    local current = inventory.GetItemAt(slot)
    if current and not magazineOf(current) then return end

    -- A failed swap must not fall through to Press R's automatic ammo merging.
    request.handled = true
    -- shortcut: VCE does not synchronize its ammo stack yet; enable multiplayer after upstream support.
    if Game.IsMultiplayer or not character.CanAccessInventory(inventory) then return end

    local candidates, visited = {}, {}
    local function collect(source)
        if visited[source] or not character.CanAccessInventory(source) then return end
        visited[source] = true
        for _, item in pairs(source.AllItemsMod) do
            if not item.Removed and item ~= weapon and item ~= request.otherWeapon and not item.HasTag("weapon") then
                local magazine = magazineOf(item)
                if magazine and item ~= current and magazine.LoadedCount > 0
                    and item.IsInteractable(character) and container.CanBeContained(item, slot) then
                    candidates[#candidates + 1] = { item = item, count = magazine.LoadedCount }
                elseif not magazine and item.OwnInventory then
                    collect(item.OwnInventory)
                end
            end
        end
    end
    collect(character.Inventory)
    table.sort(candidates, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.item.ID < b.item.ID
    end)
    for _, candidate in ipairs(candidates) do
        -- Native swapping stows the old magazine and rolls back if it cannot fit; never Combine.
        if inventory.TryPutItem(candidate.item, slot, true, false, character, true, false) then return end
    end
end)
