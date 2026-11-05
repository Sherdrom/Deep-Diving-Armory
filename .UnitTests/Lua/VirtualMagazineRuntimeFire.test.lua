-- Continue VirtualMagazineRuntime.test.lua in the same disposable editor test session.
local t = assert(DDA_RUNTIME_TEST)
local HUD = LuaUserData.CreateStatic('RemainedAmmo.RemainedAmmo')
local function log(s)
    t.lines[#t.lines + 1] = s
    File.Write('LocalMods/Deep-Diving-Armory/.UnitTests/runtime-magazine.log', table.concat(t.lines, '\n'))
    print('DDA_RUNTIME: ' .. s)
end
for _, c in pairs(t.items.gun.Components) do
    if LuaUserData.IsTargetType(c, 'SRW.SwitchableRangedWeapon') then t.weapon = c end
end
assert(t.weapon and t.weapon.FindProjectile(), 'SRW or projectile missing')
log('PASS HK416 actual SRW component, primary-slot projectile and HUD count = 30')
local aim = t.items.gun.RequireAimToUse
-- Exercise the real firing pipeline without requiring simultaneous mouse buttons.
t.items.gun.RequireAimToUse = false
local function fire(magazine, expected, done)
    local shots = 0
    local function step()
        local ok, err = pcall(function()
            local before = magazine.LoadedCount
            t.items.gun.Use(0.2, Character.Controlled, nil, nil, nil)
            assert(magazine.LoadedCount == before - 1, 'Shot failed or wrong consumption at ' .. shots .. ': ' .. before .. ' -> ' .. magazine.LoadedCount)
            shots = shots + 1
            assert(HUD.GetRemainedAmmo(0, t.items.gun, t.items.gun.OwnInventory.Container, 0.99) == magazine.LoadedCount, 'HUD disagrees with live magazine')
            if shots < expected then Timer.Wait(step, 250) else
                Timer.Wait(function()
                    local success, reason = pcall(function()
                        assert(magazine.LoadedCount == 0, 'Not empty after firing')
                        assert(not t.weapon.FindProjectile(), 'Empty magazine still provides a projectile')
                        t.items.gun.Use(0.2, Character.Controlled, nil, nil, nil)
                        assert(magazine.LoadedCount == 0, 'Empty magazine underflowed')
                        log('PASS fired ' .. expected .. ' real shots; one round per shot; HUD reaches 0; empty shot rejected')
                        done()
                    end)
                    if not success then t.items.gun.RequireAimToUse = aim; log('FAIL: ' .. tostring(reason)) end
                end, 250)
            end
        end)
        if not ok then t.items.gun.RequireAimToUse = aim; log('FAIL: ' .. tostring(err)) end
    end
    Timer.Wait(step, 2200)
end
fire(t.magazine, 30, function()
    t.items.mag.Drop(nil, false)
    assert(t.items.gun.OwnInventory.TryPutItem(t.items.drum, 0, false, false, nil, false), 'Drum swap failed')
    fire(t.drum, 60, function()
        t.items.gun.RequireAimToUse = aim
        log('PASS firing integration complete; original aim requirement restored')
    end)
end)
