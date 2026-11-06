-- After the UI test loads five rounds: equip the empty spare, carry the magazine,
-- press R twice (second press has no loaded spare), then run this in the same scene.
local t = assert(DDA_RUNTIME_TEST)
local c = assert(Character.Controlled)
assert(not Game.IsMultiplayer)
assert(t.items.gun.OwnInventory.GetItemAt(0) == t.items.mag, 'R did not insert the spare magazine')
assert(t.items.spare.ParentInventory == c.Inventory, 'R did not stow the old spare')
assert(t.magazine.LoadedCount == 5 and t.spare.LoadedCount == 0, 'R changed ammunition counts')
local function log(s)
    t.lines[#t.lines + 1] = s
    File.Write('LocalMods/Deep-Diving-Armory/.UnitTests/runtime-magazine.log', table.concat(t.lines, '\n'))
    print('DDA_RUNTIME: ' .. s)
end
log('PASS actual R key: whole-magazine swap, old spare stowed; no loaded spare leaves state unchanged')

local Id = LuaUserData.CreateStatic('Barotrauma.Identifier')
local rounds = {}
for i = 1, 10 do
    rounds[i] = Id(i % 2 == 0 and '556x45round_M995' or '5.56x45round')
end
t.spare.PushAmmoArray(rounds)
local savedSpare, savedMag = t.spare.LoadedAmmoIdentifiersString, t.magazine.LoadedAmmoIdentifiersString
local pending = 0
for i = 0, c.Inventory.Capacity - 1 do
    -- Some characters expose hidden Any slots that reject ordinary items.
    if c.Inventory.SlotTypes[i] == InvSlotType.Any and not c.Inventory.GetItemAt(i)
        and c.Inventory.CanBePutInSlot(t.items.mag, i) then
        local slot = i
        pending = pending + 1
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab('wrench'), c.Position, c.Submarine, nil, nil, function(item)
            assert(c.Inventory.TryPutItem(item, slot, false, false, c, false), 'Could not fill inventory slot')
            pending = pending - 1
        end)
    end
end

-- Close the console, wait for the inventory to fill, press R once, then call this.
function t.checkFullInventoryReload()
    assert(pending == 0, 'Inventory fixture is still spawning')
    for i = 0, c.Inventory.Capacity - 1 do
        if c.Inventory.SlotTypes[i] == InvSlotType.Any and not c.Inventory.GetItemAt(i) then
            assert(not c.Inventory.CanBePutInSlot(t.items.mag, i), 'Inventory is not full')
        end
    end
    assert(t.items.gun.OwnInventory.GetItemAt(0) == t.items.spare, 'Full-inventory swap failed')
    assert(t.items.mag.ParentInventory == c.Inventory, 'Old magazine was not stowed')
    assert(t.magazine.LoadedCount == 5 and t.spare.LoadedCount == 10, 'Swap merged or lost ammunition')
    assert(t.spare.LoadedAmmoIdentifiersString == savedSpare and t.magazine.LoadedAmmoIdentifiersString == savedMag,
        'Swap changed mixed ammunition order')
    log('PASS actual R with full inventory: 10-round mixed spare inserted; old five-round magazine stowed; both sequences unchanged')
end
print('Full-inventory fixture queued; close console, press R once after slots fill, then run DDA_RUNTIME_TEST.checkFullInventoryReload()')
