local callbacks = {}
Hook = {
    HookMethodType = { Before = "before", After = "after" },
    Patch = function(...)
        local args = { ... }
        local class, method = args[1], args[2]
        if type(args[3]) == "string" then class, method = args[2], args[3] end
        for _, value in ipairs(args) do
            if type(value) == "function" then
                callbacks[class .. "." .. method] = value
                if type(args[3]) == "string" then callbacks[args[1]] = value end
            end
        end
    end,
}
Identifier = tostring
InvSlotType = { LeftHand = 1, RightHand = 2 }
StatTypes = { None = 0 }
LimbType = { RightHand = 1, LeftHand = 2, RightForearm = 3, LeftForearm = 4, LeftArm = 5, RightArm = 6 }
Timer = { Time = 1 }
LuaUserData = { HasMember = function(value, name) return value[name] ~= nil end }
assert(loadfile("Lua/Scripts/PeachTechnology/FriendlyFireProjectile.lua"))()
assert(loadfile("Lua/Scripts/PeachTechnology/IgnoreArmLimbs.lua"))()

local vanilla = "Barotrauma.Items.Components.Projectile"
local virtual = "VCE_VirtualizedMagazine.VirtualizedProjectile"
local shooter = { IsHuman = true, Info = { GetSavedStatValue = function() return 1 end } }
for _, class in ipairs({ vanilla, virtual }) do
    local projectile = { FriendlyFire = true, User = shooter }
    callbacks[class .. ".Shoot"](projectile, { user = shooter })
    assert(not projectile.FriendlyFire, class .. " ignored the shooter friendly-fire chip")
    local target = { IsFriendly = function() return true end, Info = shooter.Info }
    local parameters = { character = target }
    assert(callbacks[class .. ".ShouldIgnoreCharacterCollision"](projectile, parameters) == true)
    assert(parameters.PreventExecution, class .. " ignored the target passthrough chip")
end
assert(callbacks[virtual .. ".HandleProjectileCollision"] == callbacks[vanilla .. ".HandleProjectileCollision"],
    "virtual and vanilla arm-hit rules diverged")

SERVER = false
Game = { IsMultiplayer = false }
LuaUserData.RegisterType = function() return {} end
LuaUserData.MakePropertyAccessible = function() end
LuaUserData.IsTargetType = function(value, name) return value.__type == name end
assert(loadfile("Lua/Scripts/PeachTechnology/NoProjectileConsume.lua"))()
local owner = {}
local weapon = { Prefab = { Identifier = "deep_hk416", ContentPackage = { Name = "Deep-Diving-Armory" } } }
local bullet = { Container = owner }
local projectile = { __type = virtual, Item = bullet }
bullet.GetComponentString = function() return projectile end
callbacks["NoProjectileConsume.FindProj"]({ Item = weapon, CurrentSelected = 0 }, { ReturnValue = projectile })
local remove = { contained = bullet }
callbacks["NoProjectileConsume.RemoveContained"](weapon, remove)
assert(remove.PreventExecution, "SRW detached the virtual projectile after the first shot")
remove = { contained = bullet }
callbacks["NoProjectileConsume.RemoveContained"](owner, remove)
assert(not remove.PreventExecution, "real magazine cleanup was blocked")
remove = { contained = bullet }
callbacks["NoProjectileConsume.RemoveContained"]({ Prefab = { Identifier = "othergun", ContentPackage = { Name = "Other" } } }, remove)
assert(not remove.PreventExecution, "DDA virtual-projectile guard affected another package")
local drop = {}
callbacks["NoProjectileConsume.Drop"](bullet, drop)
assert(not drop.PreventExecution, "virtual projectile entered legacy tracking")

projectile.__type = vanilla
callbacks["NoProjectileConsume.FindProj"]({ Item = weapon, CurrentSelected = 0 }, { ReturnValue = projectile })
remove = { contained = bullet }
callbacks["NoProjectileConsume.RemoveContained"](weapon, remove)
assert(remove.PreventExecution, "legacy projectile protection was lost")
print("ok: virtual projectile lifetime, legacy tracking, friendly-fire and arm-hit rules")
