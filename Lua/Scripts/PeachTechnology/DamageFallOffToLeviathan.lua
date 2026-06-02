local AH = AfflictionHelper

local MULTIPLIER = 0.08
local MASS_THRESHOLD = 3000
local AFFLICTION_NAME = "deepgun_inwater_detect"

Hook.Add("character.applyDamage", "DeepVCEDamageModifier",
function(characterHealth, attackResult, hitLimb, allowStacking)
    local targetCharacter = characterHealth.Character
    if targetCharacter == nil then return end

    local attacker = targetCharacter.LastAttacker
    if attacker == nil then return end

    if not attacker.IsHuman then return end

    if AH.GetAffStrength(attacker, AFFLICTION_NAME) <= 0.1 then return end

    if targetCharacter.Mass < MASS_THRESHOLD then return end

    local afflictions = attackResult.Afflictions
    if afflictions == nil then return end

    for _, a in ipairs(afflictions) do
        if a ~= nil then
            a.Strength = a.Strength * MULTIPLIER
        end
    end
end)