-- 当攻击者携带 deepgun_inwater_detect affliction 时，攻击行为受到水中阻力，
-- 最终伤害降至 40%。触发条件：攻击者或目标任一在水中。
local MULTIPLIER = 0.4
local STRENGTH_THRESHOLD = 0.1
local AFFLICTION_NAME = "deepgun_inwater_detect"

Hook.Add("character.applyDamage", "DeepGun_InWaterDetect",
function(characterHealth, attackResult, hitLimb, allowStacking)
    local targetCharacter = characterHealth.Character
    if targetCharacter == nil then return end

    local attacker = targetCharacter.LastAttacker
    if attacker == nil then return end

    local aff = attacker.CharacterHealth.GetAffliction(AFFLICTION_NAME)
    if aff == nil or aff.Strength <= STRENGTH_THRESHOLD then return end

    if not (attacker.InWater or targetCharacter.InWater) then return end

    local afflictions = attackResult.Afflictions
    if afflictions == nil then return end

    for _, a in ipairs(afflictions) do
        if a ~= nil then
            a.Strength = a.Strength * MULTIPLIER
        end
    end
end)