local registeredHooks = {}
local registeredPatches = {}
local afflictionQueries = {}

Hook = {
    HookMethodType = { Before = "Before" },
    Add = function(name, id, callback)
        registeredHooks[name] = registeredHooks[name] or {}
        registeredHooks[name][id] = callback
    end,
    Patch = function(_, method, callback)
        registeredPatches[method] = callback
    end,
}

AfflictionHelper = {
    GetAffStrength = function(character, identifier)
        afflictionQueries[identifier] = (afflictionQueries[identifier] or 0) + 1
        return (character._afflictionStrengths or {})[identifier] or 0
    end,
}
LuaUserData = { HasMember = function() return false end }

dofile("Lua/Scripts/PeachTechnology/DamageFallOffAll.lua")

local onDamageLimb = registeredHooks["character.damageLimb"]["DamageFallOffAll.OnDamageLimb"]
local applyDamage = registeredPatches["ApplyDamage"]
local deepGunModifiers = registeredHooks["character.applyDamage"]["DamageFallOffAll.DeepGunModifiers"]

local function callDamageLimb(target, attacker)
    return onDamageLimb(target, nil, nil, nil, nil, nil, nil, attacker, nil, nil, nil, nil)
end

local function noWorldPosition(values, reads)
    values.WorldPosition = nil
    return setmetatable(values, {
        __index = function(_, key)
            if key == "WorldPosition" then
                reads.count = reads.count + 1
                error("WorldPosition was read")
            end
        end,
    })
end

local attackerReads = { count = 0 }
local removedAttacker = noWorldPosition({ Removed = true }, attackerReads)
local target = { Removed = false, WorldPosition = { X = 0, Y = 0 } }
assert(pcall(callDamageLimb, target, removedAttacker))
assert(attackerReads.count == 0)

local targetReads = { count = 0 }
local removedTarget = noWorldPosition({ Removed = true }, targetReads)
local attacker = { Removed = false, WorldPosition = { X = 0, Y = 0 }, CharacterHealth = {} }
assert(pcall(callDamageLimb, removedTarget, attacker))
assert(targetReads.count == 0)

local attackerReadsNoProfile = { count = 0 }
local targetReadsNoProfile = { count = 0 }
local noProfileAttacker = noWorldPosition({ Removed = false, CharacterHealth = {} }, attackerReadsNoProfile)
local noProfileTarget = noWorldPosition({ Removed = false, ID = 1 }, targetReadsNoProfile)
assert(pcall(callDamageLimb, noProfileTarget, noProfileAttacker))
assert(attackerReadsNoProfile.count == 0 and targetReadsNoProfile.count == 0)

local falloffAttacker = {
    Removed = false,
    CharacterHealth = {},
    WorldPosition = { X = 0, Y = 0 },
    _afflictionStrengths = { deep_damage_fall_off_600_1200_detect = 100 },
}
local falloffTarget = { Removed = false, ID = 2, WorldPosition = { X = 900, Y = 0 } }
local falloffAffliction = { Strength = 100 }
afflictionQueries = {}
assert(pcall(callDamageLimb, falloffTarget, falloffAttacker))
assert(afflictionQueries.deep_damage_fall_off_600_1200_detect == 1)
assert((afflictionQueries.deep_damage_fall_off_1500_2300_detect or 0) <= 1)
applyDamage({ Character = falloffTarget }, { attackResult = { Afflictions = { falloffAffliction } } })
assert(math.abs(falloffAffliction.Strength - 52.5) < 0.000001)

local deepGunAttacker = {
    Removed = false,
    Inventory = {},
    HasEquippedItem = function() return true end,
    InWater = true,
    IsHuman = true,
}
local leviathan = {
    Removed = false,
    LastAttacker = deepGunAttacker,
    InWater = false,
    Mass = 5000,
}
local combinedAffliction = { Strength = 100 }
deepGunModifiers({ Character = leviathan }, { Afflictions = { combinedAffliction } }, nil, false)
assert(math.abs(combinedAffliction.Strength - 5) < 0.000001)

leviathan.Mass = 2999
local waterAffliction = { Strength = 100 }
deepGunModifiers({ Character = leviathan }, { Afflictions = { waterAffliction } }, nil, false)
assert(math.abs(waterAffliction.Strength - 50) < 0.000001)

deepGunAttacker.InWater = false
leviathan.Mass = 5000
local leviathanAffliction = { Strength = 100 }
deepGunModifiers({ Character = leviathan }, { Afflictions = { leviathanAffliction } }, nil, false)
assert(math.abs(leviathanAffliction.Strength - 10) < 0.000001)

local dryAttacker = {
    Removed = false,
    Inventory = {},
    HasEquippedItem = function() return true end,
    InWater = false,
    IsHuman = true,
}
local smallTarget = {
    Removed = false,
    LastAttacker = dryAttacker,
    InWater = false,
    Mass = 2999,
}
local unchangedAffliction = { Strength = 100 }
deepGunModifiers({ Character = smallTarget }, { Afflictions = { unchangedAffliction } }, nil, false)
assert(unchangedAffliction.Strength == 100)

print("DamageFallOffAll tests passed")
