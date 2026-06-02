local AH = AfflictionHelper

local MULTIPLIER = 0.4
local STRENGTH_THRESHOLD = 0.1
local AFFLICTION_NAME = "deepgun_inwater_detect"

Hook.Add("character.applyDamage", "DeepGun_InWaterDetect",
function(characterHealth, attackResult, hitLimb, allowStacking)
    local targetCharacter = characterHealth.Character
    if targetCharacter == nil then return end

    local attacker = targetCharacter.LastAttacker
    if attacker == nil then return end

    if AH.GetAffStrength(attacker, AFFLICTION_NAME) <= STRENGTH_THRESHOLD then return end

    if not (attacker.InWater or targetCharacter.InWater) then return end

    local afflictions = attackResult.Afflictions
    if afflictions == nil then return end

    for _, a in ipairs(afflictions) do
        if a ~= nil then
            a.Strength = a.Strength * MULTIPLIER
        end
    end
end)