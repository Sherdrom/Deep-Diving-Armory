-- DeepGun InWater Detect Modifier Script
-- 当生物身上有 deepgun_inwater_detect 的 Affliction 时，
-- 该生物攻击另一个生物，会有水中阻力效果，导致只能造成最终伤害的 40%
-- 触发条件：攻击者不在水中攻击水中的目标 / 攻击者在水中攻击水外的目标 / 双方都在水中

Hook.Add("character.applyDamage", "DeepGun_InWaterDetect", function(characterHealth, attackResult, hitLimb, allowStacking)
    local targetCharacter = characterHealth.Character
    if targetCharacter == nil then return end

    local attacker = targetCharacter.LastAttacker
    if attacker == nil then return end

    local vceAffliction = attacker.CharacterHealth.GetAffliction("deepgun_inwater_detect")
    if vceAffliction == nil or vceAffliction.Strength <= 0.1 then return end

    local attackerInWater = attacker.InWater
    local targetInWater = targetCharacter.InWater

    if attackerInWater or targetInWater then
        if attackResult.Afflictions ~= nil then
            for _, affliction in ipairs(attackResult.Afflictions) do
                if affliction.Strength ~= nil and affliction.SetStrength ~= nil then
                    affliction:SetStrength(affliction.Strength * 0.4)
                end
            end
        end
    end
end)
