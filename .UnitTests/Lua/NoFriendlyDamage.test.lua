local patches = {}

Identifier = function(value)
    return value
end

StatTypes = { None = "None" }

AfflictionHelper = {
    GetAffStrength = function(character, identifier)
        return character.afflictions[identifier] or 0
    end,
}

Hook = {
    HookMethodType = {
        Before = "Before",
        After = "After",
    },
}

function Hook.Patch(identifier, className, methodName, callback, hookType)
    patches[identifier] = {
        className = className,
        methodName = methodName,
        callback = callback,
        hookType = hookType,
    }
end

local function makeCharacter(teamId, friendlyFireStrength)
    local character = {
        TeamID = teamId,
        IsHuman = true,
        afflictions = {},
    }
    character.Info = {
        GetSavedStatValue = function(self, statType, identifier)
            if identifier == "friendly_fire" then
                return friendlyFireStrength or 0
            end
            return 0
        end,
    }
    return character
end

local function makeAffliction(strength, isBuff)
    return {
        Strength = strength,
        Prefab = {
            Identifier = isBuff and "testbuff" or "testdamage",
            IsBuff = isBuff,
        },
    }
end

local function applyDamage(target, afflictions)
    patches.NFD_ApplyDamage.callback(
        { Character = target },
        { attackResult = { Afflictions = afflictions } }
    )
end

local function beginAttack(identifier, attacker, instance)
    patches["NFD_" .. identifier .. "_Before"].callback(instance, { attacker = attacker })
end

local function endAttack(identifier)
    patches["NFD_" .. identifier .. "_After"].callback(nil, {})
end

local NoFriendlyDamage = dofile("Lua/Scripts/PeachTechnology/NoFriendlyDamage.lua")

assert(patches.NFD_DoDamage_Before.className == "Barotrauma.Attack")
assert(patches.NFD_DoDamage_After.hookType == Hook.HookMethodType.After)
assert(patches.NFD_DoDamageToLimb_Before.methodName == "DoDamageToLimb")
assert(patches.NFD_ApplyAttack_Before.className == "Barotrauma.Character")
assert(patches.NFD_Explosion_Before.className == "Barotrauma.Explosion")
assert(patches.NFD_Fire_Before.methodName == "DamageCharacters")
assert(patches.NFD_ApplyDamage.hookType == Hook.HookMethodType.Before)

local attacker = makeCharacter(1, 1)
local teammate = makeCharacter(1, 0)
local enemy = makeCharacter(2, 0)

local directDamage = makeAffliction(100, false)
local attackBuff = makeAffliction(20, true)
beginAttack("DoDamage", attacker)
beginAttack("ApplyAttack", attacker)
applyDamage(teammate, { directDamage, attackBuff })
endAttack("ApplyAttack")
assert(directDamage.Strength == 0, "friendly weapon damage should be blocked")
assert(attackBuff.Strength == 20, "friendly attack buffs should be preserved")

local attachedDamage = makeAffliction(40, false)
applyDamage(teammate, { attachedDamage })
assert(attachedDamage.Strength == 0, "attack status effects should remain inside the attack context")
endAttack("DoDamage")

local directApplyAttackDamage = makeAffliction(25, false)
beginAttack("ApplyAttack", attacker)
applyDamage(teammate, { directApplyAttackDamage })
endAttack("ApplyAttack")
assert(directApplyAttackDamage.Strength == 0, "direct Character.ApplyAttack damage should be blocked")

local medicineEffect = makeAffliction(30, false)
applyDamage(teammate, { medicineEffect })
assert(medicineEffect.Strength == 30, "medicine outside an Attack call must not be modified")

local limbDamage = makeAffliction(50, false)
beginAttack("DoDamageToLimb", attacker)
applyDamage(teammate, { limbDamage })
endAttack("DoDamageToLimb")
assert(limbDamage.Strength == 0, "limb attacks should be blocked")

local explosionDamage = makeAffliction(50, false)
beginAttack("Explosion", attacker)
applyDamage(teammate, { explosionDamage })
endAttack("Explosion")
assert(explosionDamage.Strength == 0, "friendly explosion damage should be blocked")

local fireDamage = makeAffliction(50, false)
beginAttack("Fire", nil, { SourceCharacter = attacker })
applyDamage(teammate, { fireDamage })
endAttack("Fire")
assert(fireDamage.Strength == 0, "friendly fire-source damage should be blocked")

local enemyDamage = makeAffliction(60, false)
beginAttack("DoDamage", attacker)
applyDamage(enemy, { enemyDamage })
endAttack("DoDamage")
assert(enemyDamage.Strength == 60, "enemy damage should not be modified")

local selfDamage = makeAffliction(70, false)
beginAttack("DoDamage", attacker)
applyDamage(attacker, { selfDamage })
endAttack("DoDamage")
assert(selfDamage.Strength == 70, "self damage should not be treated as friendly fire")

local unprotectedAttacker = makeCharacter(1, 0)
local unprotectedDamage = makeAffliction(80, false)
beginAttack("DoDamage", unprotectedAttacker)
applyDamage(teammate, { unprotectedDamage })
endAttack("DoDamage")
assert(unprotectedDamage.Strength == 80, "attacks without a friendship marker should be unchanged")

assert(NoFriendlyDamage.IsSameTeam(attacker, teammate))
assert(not NoFriendlyDamage.IsSameTeam(attacker, enemy))

local chips = dofile("Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config/WeaponChips.lua")
assert(chips.chip_friendly_fire.talentMarkers[1] == "friendly_fire", "friendship chip marker mapping changed")

print("NoFriendlyDamage state check OK")
