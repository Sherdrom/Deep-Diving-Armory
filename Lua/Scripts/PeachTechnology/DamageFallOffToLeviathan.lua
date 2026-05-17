-- 当攻击者携带 deepgun_inwater_detect affliction 时，
-- 对 Mass >= 3000 的生物造成的基础伤害仅剩 8%
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

    local aff = attacker.CharacterHealth.GetAffliction(AFFLICTION_NAME)
    if aff == nil or aff.Strength <= 0.1 then return end

    if targetCharacter.Mass < MASS_THRESHOLD then return end

    local afflictions = attackResult.Afflictions
    if afflictions == nil then return end

    for _, a in ipairs(afflictions) do
        if a ~= nil then
            a.Strength = a.Strength * MULTIPLIER
        end
    end
end)