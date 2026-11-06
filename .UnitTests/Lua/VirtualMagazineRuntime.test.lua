-- Manual integration test in a disposable single-player editor test session.
-- Run: cl_lua load(File.Read('LocalMods/Deep-Diving-Armory/.UnitTests/Lua/VirtualMagazineRuntime.test.lua'))()
assert(not Game.IsMultiplayer and Character.Controlled, 'Requires a single-player test character')
assert(not DDA_RUNTIME_TEST or (DDA_RUNTIME_TEST.items.gun and DDA_RUNTIME_TEST.items.gun.Removed),
    'Already started; use a fresh test session to rerun')
LuaUserData.RegisterType('VCE_VirtualizedMagazine.VirtualizedMagazine')
LuaUserData.RegisterType('VCE_SRW.SwitchableRangedWeapon')
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
    local magazine, spare = t.items.mag.OwnInventory.Container, t.items.spare.OwnInventory.Container
    t.magazine, t.spare = magazine, spare
    assert(magazine.MaxSize == 30 and magazine.LoadedCount == 0, '30-round magazine must spawn empty')
    assert(spare.MaxSize == 30 and spare.LoadedCount == 0, '30-round spare must spawn empty')
    assert(t.items.mag.OwnInventory.GetItemAt(0), 'Virtual projectile missing')
    log('PASS initial empty magazines: 0/30 and 0/30; virtual projectile placeholder spawned')
    magazine.PushAmmoArray({Id('5.56x45round'), Id('556x45round_M995')})
    assert(magazine.LoadedCount == 2 and top(magazine) == '556x45round_m995', 'Mixed stack setup')
    t.before = t.items.box.Condition
    put(t.items.press, t.items.box, 0)
    put(t.items.press, t.items.mag, 6)
    put(t.items.press, t.items.spare, 7)
    local interface = t.items.press.GetComponentString('CustomInterface')
    assert(interface, 'Press controls missing')
    interface.Signals = '1;1;0;1;1'
    Hook.Call('dda.magpress.start', nil, 0, t.items.press)
    later(3500, function()
        assert(magazine.LoadedCount == 30 and spare.LoadedCount == 0, 'Press did not honor selected magazine')
        interface.Signals = '1;2;0;1;1'
        Hook.Call('dda.magpress.start', nil, 0, t.items.press)
    end)
    later(7000, function()
        assert(magazine.LoadedCount == 30 and spare.LoadedCount == 30, 'Press did not fill both magazines')
        assert(top(magazine) == '5.56x45round_tit' and top(spare) == '5.56x45round_tit', 'Box type not used')
        local spent = t.before - t.items.box.Condition
        assert(math.abs(spent - 58 * 1.5625 / 30) < 0.001, 'Incorrect resource charge: ' .. spent)
        t.items.mag.Drop(nil, false)
        t.items.spare.Drop(nil, false)
        log(string.format('PASS real press: 28 + 30 titanium rounds; box cost %.6f', spent))
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
        for component in t.items.gun.Components do
            if LuaUserData.IsTargetType(component, 'VCE_SRW.SwitchableRangedWeapon') then t.weapon = component end
        end
        assert(t.weapon and t.weapon.FindProjectile(), 'Weapon cannot find virtual projectile')
        log('PASS HK416 primary slot and live HUD count = 30; ready for firing')
    end)
end
local pending = 5
for key, id in pairs({press='ammoreload_machine', mag='deep_556x45_virtual_30', spare='deep_556x45_virtual_30', box='ammobox_7.62', gun='deep_hk416'}) do
    local prefab = ItemPrefab.GetItemPrefab(id)
    assert(prefab, 'Missing prefab: ' .. id)
    Entity.Spawner.AddItemToSpawnQueue(prefab, Character.Controlled.Position, Character.Controlled.Submarine, nil, nil, function(item)
        t.items[key] = item
        pending = pending - 1
        if pending == 0 then later(1000, begin) end
    end)
end
log('START queued five disposable test items')
