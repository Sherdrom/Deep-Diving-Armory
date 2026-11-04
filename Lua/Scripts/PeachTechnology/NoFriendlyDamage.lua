local AH = AfflictionHelper

local DEBUG = false

local NO_FRIENDLY_FIRE_AFFLICTIONS = {
    { id = "friendly_fire", marker = Identifier("friendly_fire"), multiplier = 0.0 },
    { id = "deep_noff_reduce95",    multiplier = 0.05 },
    { id = "deep_noff_reduce75",    multiplier = 0.25 },
    { id = "deep_noff_reduce50",    multiplier = 0.50 },
}

local function dbg(message)
    if DEBUG then
        print("[NFD-DEBUG] " .. tostring(message))
    end
end

local function IsSameTeam(char1, char2)
    if char1 == nil or char2 == nil then
        return false
    end
    return (char1.TeamID == char2.TeamID) and (char1.TeamID >= 0)
end

local function FindActiveFFConfig(attacker)
    local bestMultiplier = nil
    local bestAfflictionId = nil
    local bestStrength = 0

    for i = 1, #NO_FRIENDLY_FIRE_AFFLICTIONS do
        local entry = NO_FRIENDLY_FIRE_AFFLICTIONS[i]
        local strength = entry.marker
            and attacker.Info
            and attacker.Info:GetSavedStatValue(StatTypes.None, entry.marker)
            or AH.GetAffStrength(attacker, entry.id)
        if strength > 0.5 and strength > bestStrength then
            bestMultiplier = entry.multiplier
            bestAfflictionId = entry.id
            bestStrength = strength
        end
    end

    return bestMultiplier, bestAfflictionId
end

local function ApplyDamageModification(attackResult, multiplier)
    local afflictions = attackResult.Afflictions
    if afflictions == nil then
        return false
    end

    local modifiedCount = 0
    for _, affliction in ipairs(afflictions) do
        if affliction ~= nil and not (affliction.Prefab and affliction.Prefab.IsBuff) then
            local original = affliction.Strength
            affliction.Strength = original * multiplier
            modifiedCount = modifiedCount + 1
            dbg(string.format("  modify: %s %.1f -> %.1f (x%.2f)",
                tostring(affliction.Prefab.Identifier),
                original, affliction.Strength, multiplier))
        end
    end

    return modifiedCount > 0
end

local NoFriendlyDamage = {
    stats = {
        totalChecks = 0,
        appliedModifications = 0,
        skippedAttacks = 0,
    },
}

-- DamageLimb is also used by medicines, so only arm the filter inside combat producers.
local attackStack = {}

local function RegisterAttackContext(identifier, className, methodName, getAttacker)
    Hook.Patch(
        "NFD_" .. identifier .. "_Before",
        className,
        methodName,
        function(instance, ptable)
            attackStack[#attackStack + 1] = getAttacker(instance, ptable) or false
        end,
        Hook.HookMethodType.Before
    )
    Hook.Patch(
        "NFD_" .. identifier .. "_After",
        className,
        methodName,
        function(instance, ptable)
            if #attackStack > 0 then
                attackStack[#attackStack] = nil
            end
        end,
        Hook.HookMethodType.After
    )
end

for _, methodName in ipairs({ "DoDamage", "DoDamageToLimb" }) do
    RegisterAttackContext(methodName, "Barotrauma.Attack", methodName, function(instance, ptable)
        return ptable["attacker"]
    end)
end

RegisterAttackContext("ApplyAttack", "Barotrauma.Character", "ApplyAttack", function(instance, ptable)
    return ptable["attacker"]
end)

RegisterAttackContext("Explosion", "Barotrauma.Explosion", "Explode", function(instance, ptable)
    return ptable["attacker"]
end)

RegisterAttackContext("Fire", "Barotrauma.FireSource", "DamageCharacters", function(instance, ptable)
    return instance.SourceCharacter
end)

Hook.Patch(
    "NFD_ApplyDamage",
    "Barotrauma.CharacterHealth",
    "ApplyDamage",
    function(instance, ptable)
        local attackResult = ptable["attackResult"]
        local character = instance.Character
        local attacker = attackStack[#attackStack]

        if attackResult == nil or character == nil or attacker == nil or attacker == false then
            return
        end

        if DEBUG then
            NoFriendlyDamage.stats.totalChecks = NoFriendlyDamage.stats.totalChecks + 1
        end

        if not attacker.IsHuman or attacker == character then
            return
        end

        local multiplier, afflictionId = FindActiveFFConfig(attacker)
        if multiplier == nil or not IsSameTeam(attacker, character) then
            if DEBUG then
                NoFriendlyDamage.stats.skippedAttacks = NoFriendlyDamage.stats.skippedAttacks + 1
            end
            return
        end

        dbg(string.format("apply damage modification: %s (%s, x%.2f)",
            tostring(character.Name), afflictionId, multiplier))

        local success = ApplyDamageModification(attackResult, multiplier)

        if success then
            if DEBUG then
                NoFriendlyDamage.stats.appliedModifications = NoFriendlyDamage.stats.appliedModifications + 1
            end
            dbg("modification succeeded")
        else
            dbg("modification failed or no afflictions")
        end
    end,
    Hook.HookMethodType.Before
)

function NoFriendlyDamage.GetStats()
    return {
        pendingCount = 0,
        totalChecks = NoFriendlyDamage.stats.totalChecks,
        appliedMods = NoFriendlyDamage.stats.appliedModifications,
        skipped = NoFriendlyDamage.stats.skippedAttacks,
    }
end

NoFriendlyDamage.IsSameTeam = IsSameTeam
NoFriendlyDamage.FindActiveFFConfig = FindActiveFFConfig

return NoFriendlyDamage
