-- DamageFallOffToLeviathan Modifier Script
-- 当玩家身上有 deepgun_inwater_detect78 的 Affliction 时，
-- 攻击 mass >= 3000 的生物时，最终造成的伤害只有 8%

Hook.Add("character.applyDamage", "DeepVCEDamageModifier", function(characterHealth, attackResult, hitLimb, allowStacking)
    -- 获取被攻击的角色
    local targetCharacter = characterHealth.Character
    if targetCharacter == nil then return end
    
    -- 获取攻击者（从目标的 LastAttacker 属性获取）
    local attacker = targetCharacter.LastAttacker
    if attacker == nil then return end
    
    -- 检查攻击者是否是人类玩家
    if not attacker.IsHuman then return end
    
    -- 检查攻击者是否有 deepgun_inwater_detect Affliction
    local vceAffliction = attacker.CharacterHealth.GetAffliction("deepgun_inwater_detect")
    if vceAffliction == nil or vceAffliction.Strength <= 0.1 then return end
    
    -- 检查目标生物的 mass 是否 >= 3000
    local targetMass = targetCharacter.Mass
    if targetMass < 3000 then return end
    
    -- 所有条件满足！将伤害降低到 8%
    -- 遍历所有 afflictions 并将其强度乘以 0.08
    if attackResult.Afflictions ~= nil then
        for _, affliction in ipairs(attackResult.Afflictions) do
            if affliction.Strength ~= nil and affliction.SetStrength ~= nil then
                affliction:SetStrength(affliction.Strength * 0.08)
            end
        end
    end
    
    -- 可选：打印调试信息
    -- print(string.format("[DeepVCE] %s 攻击 %s (mass=%.1f), 伤害降低至 5%%", 
    --     attacker.Name, targetCharacter.Name, targetMass))
end)
