local turretType = "Barotrauma.Items.Components.Turret"
Descriptors = { [turretType] = turretType }
LuaUserData = {
    MakeFieldAccessible = function(_, name) assert(name == "targetRotation") end,
    MakePropertyAccessible = function(_, name) assert(name == "BarrelRotation") end,
    MakeMethodAccessible = function(_, name) assert(name == "Launch") end,
}
local launch
Hook = {
    HookMethodType = { Before = 0 },
    Add = function() end,
    Patch = function(typeName, method, callback)
        if typeName == turretType and method == "Launch" then launch = callback end
    end,
}
Vector2 = function(x, y) return { X = x, Y = y } end
Timer = { Wait = function(callback) callback() end }
Deep_Lua = { MissileConfigs = { missile = { IS_AUTO_GUIDED = false } } }
dofile("Lua/Scripts/AliceTechnology/missileframework.lua")
assert(type(launch) == "function", "missile startup did not finish")

local turret = {
    item = { RotationRad = 0.75, HasTag = function(tag) return tag == "vls" end },
    BarrelRotation = 0,
}
setmetatable(turret, { __index = function(_, key)
    if key == "Rotation" or key == "set_Rotation" then error("obsolete turret API") end
end })
local missile = { Prefab = { Identifier = { Value = "missile" } },
    HasTag = function(tag) return tag == "saclosmsl" end }
launch(turret, { projectile = missile })
assert(math.abs(turret.BarrelRotation - (0.75 - math.pi * 0.5)) < 1e-6)
assert(turret.RotationLimits.X == 0 and turret.RotationLimits.Y == 360)

turret.BarrelRotation = 0.2
launch(turret, { projectile = { HasTag = function() return false end } })
assert(turret.BarrelRotation == 0.2, "ordinary projectiles changed turret rotation")
print("Missile framework startup and vertical launch check OK")
