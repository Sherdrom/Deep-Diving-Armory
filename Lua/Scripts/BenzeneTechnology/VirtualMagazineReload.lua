if SERVER then return end

local virtualType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
LuaUserData.RegisterType(virtualType)

local function magazineOf(item)
    local container = item and item.OwnInventory and item.OwnInventory.Container
    if container and LuaUserData.IsTargetType(container, virtualType) then return container end
end

Hook.Add("pressrtoreload.reload", "DDA.VirtualMagazine.Reload", function(request)
    if request.handled then return end
    local character, weapon, inventory = request.character, request.weapon, request.inventory
    local package = weapon and weapon.Prefab.ContentPackage
    if not character or not inventory or not package or package.Name ~= "Deep-Diving-Armory" then return end

    local container = inventory.Container
    local slot = math.max(container.ContainedStateIndicatorSlot, 0)
    local current = inventory.GetItemAt(slot)
    if current and not magazineOf(current) then return end

    local candidates, visited = {}, {}
    local function collect(source)
        if visited[source] or not character.CanAccessInventory(source) then return end
        visited[source] = true
        for item in source.AllItemsMod do
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
    -- Empty weapons with only legacy magazines still use Press R's original reload.
    if not current and #candidates == 0 then return end
    -- A failed virtual swap must not fall through to automatic ammo merging.
    request.handled = true
    if not character.CanAccessInventory(inventory) then return end
    table.sort(candidates, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.item.ID < b.item.ID
    end)
    for _, candidate in ipairs(candidates) do
        -- Native swapping stows the old magazine and rolls back if it cannot fit; never Combine.
        if inventory.TryPutItem(candidate.item, slot, true, false, character, true, false) then return end
    end
end)
