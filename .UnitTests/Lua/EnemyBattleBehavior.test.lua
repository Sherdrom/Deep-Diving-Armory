Game = { IsMultiplayer = false }
local strength = 0
AfflictionHelper = { GetAffStrength = function() return strength end }
OrderPrefab = { Prefabs = {} }
LuaUserData = { RegisterType = function() end, MakePropertyAccessible = function() end }
local update
Hook = {
    HookMethodType = { Before = 0, After = 1 },
    Add = function() end,
    Patch = function(typeName, method, callback)
        if typeName == "Barotrauma.HumanAIController" and method == "Update" then
            update = callback
        end
    end,
}
dofile("Lua/Scripts/PeachTechnology/EnemyBattleBehavior.lua")
assert(type(update) == "function")
local anim = { Crouching = true }
local controller = setmetatable({ Character = { AnimController = anim } }, {
    __index = function(_, key) error("unsupported AI controller member: " .. key) end,
})
update(controller)
assert(anim.Crouching, "ordinary crew crouching was changed")
strength = 0.2
update(controller)
assert(not anim.Crouching, "resistant enemy did not stand up")
update(controller)
assert(not anim.Crouching)
print("Enemy battle crouching compatibility check OK")
