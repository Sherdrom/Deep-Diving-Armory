-- Manual integration test in a disposable single-player editor test session.
-- Run: cl_lua dofile('LocalMods/Deep-Diving-Armory/.UnitTests/Lua/VirtualMagazineRuntime.test.lua')
assert(not Game.IsMultiplayer and Character.Controlled, 'Requires a single-player test character')
assert(not DDA_RUNTIME_TEST, 'Already started; use a fresh test session to rerun')
LuaUserData.RegisterType('VCE_VirtualizedMagazine.VirtualizedMagazine')
LuaUserData.RegisterType('SRW.SwitchableRangedWeapon')
LuaUserData.RegisterType('RemainedAmmo.RemainedAmmo')
local Id = LuaUserData.CreateStatic('Barotrauma.Identifier')
local HUD = LuaUserData.CreateStatic('RemainedAmmo.RemainedAmmo')
local t = { items = {}, lines = {} }
DDA_RUNTIME_TEST = t
local function log(s)
    t.lines[#t.lines + 1] = s
    File.Write('LocalMods/Deep-Diving-Armory/.UnitTests/runtime-magazine.log', table.concat(t.lines, '\n'))
    print('DDA_RUNTIME: ' .. s)
end
local function later(ms, fn)
    Timer.Wait(function()
        local ok, err = pcall(fn)
        if not ok then log('FAIL: ' .. tostring(err)) end
    end, ms)
end
local function put(container, item, slot)
    assert(container.OwnInventory.TryPutItem(item, slot, false, false, nil, false), 'Insertion rejected: ' .. tostring(item.Prefab.Identifier))
end
local function empty(mag)
    local count = mag.LoadedCount
    for i = 1, count do mag.Use(1, nil) end
    assert(mag.LoadedCount == 0, 'Emptying failed')
end
local function top(mag) return string.lower(tostring(mag.TopIdentifier)) end
local function begin()
    local magazine, drum = t.items.mag.OwnInventory.Container, t.items.drum.OwnInventory.Container
    t.magazine, t.drum = magazine, drum
    assert(magazine.MaxSize == 30 and magazine.LoadedCount == 30, '30-round initial capacity')
    assert(drum.MaxSize == 60 and drum.LoadedCount == 60, '60-round initial capacity')
    assert(t.items.mag.OwnInventory.GetItemAt(0), 'Virtual projectile missing')
    log('PASS initial magazines: 30/30 and 60/60; virtual projectile spawned')
    empty(magazine)
    empty(drum)
    magazine.PushAmmoArray({Id('5.56x45round'), Id('556x45round_M995')})
    assert(magazine.LoadedCount == 2 and top(magazine) == '556x45round_m995', 'Mixed stack setup')
    t.before = t.items.box.Condition
    put(t.items.press, t.items.box, 0)
    put(t.items.press, t.items.mag, 6)
    put(t.items.press, t.items.drum, 7)
    later(3500, function()
        assert(magazine.LoadedCount == 30 and drum.LoadedCount == 60, 'Press did not fill both magazines')
        assert(top(magazine) == '5.56x45round_tit' and top(drum) == '5.56x45round_tit', 'Box type not used')
        local spent = t.before - t.items.box.Condition
        assert(math.abs(spent - 88 * 1.5625 / 30) < 0.001, 'Incorrect resource charge: ' .. spent)
        t.items.mag.Drop(nil, false)
        t.items.drum.Drop(nil, false)
        log(string.format('PASS real press: 28 + 60 titanium rounds; box cost %.6f', spent))
        for i = 1, 28 do
            assert(top(magazine) == '5.56x45round_tit', 'New rounds not first')
            magazine.Use(1, nil)
        end
        assert(magazine.LoadedCount == 2 and top(magazine) == '556x45round_m995', 'Original M995 lost')
        magazine.Use(1, nil)
        assert(magazine.LoadedCount == 1 and top(magazine) == '5.56x45round', 'Original standard round lost')
        log('PASS mixed order: new titanium rounds, then original M995, then original standard')
        empty(magazine)
        local rounds = {}
        for i = 1, 30 do rounds[i] = Id('5.56x45round') end
        magazine.PushAmmoArray(rounds)
        put(t.items.gun, t.items.mag, 0)
        local container = t.items.gun.OwnInventory.Container
        assert(HUD.GetRemainedAmmo(0, t.items.gun, container, 0.99) == 30, 'Live HUD count')
        for _, component in pairs(t.items.gun.Components) do
            if LuaUserData.IsTargetType(component, 'SRW.SwitchableRangedWeapon') then t.weapon = component end
        end
        assert(t.weapon and t.weapon.FindProjectile(), 'Weapon cannot find virtual projectile')
        log('PASS HK416 primary slot and live HUD count = 30; ready for firing')
    end)
end
local pending = 5
for key, id in pairs({press='ammoreload_machine', mag='deep_5.56x45', drum='deep_5.56x45_expansion', box='ammobox_7.62', gun='deep_hk416'}) do
    local prefab = ItemPrefab.GetItemPrefab(id)
    assert(prefab, 'Missing prefab: ' .. id)
    Entity.Spawner.AddItemToSpawnQueue(prefab, Character.Controlled.WorldPosition, nil, nil, function(item)
        t.items[key] = item
        pending = pending - 1
        if pending == 0 then later(1000, begin) end
    end)
end
log('START queued five disposable test items')
