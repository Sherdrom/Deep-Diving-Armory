local AH = AfflictionHelper

local AimWobbleBuffs = { "deep_calm_buff", "deep_contract_harsh_training_detect" }
local MovePenaltyBuffs = { "deep_calm_buff", "deep_contract_harsh_training_detect" }
local STABLE_SHOOTING_MARKER = Identifier("deep_stable_shooting")

local function HasAnyBuff(character, buffs)
    if character == nil or character.CharacterHealth == nil then
        return false
    end
    for _, id in ipairs(buffs) do
        if AH.GetAffStrength(character, id) > 0 then
            return true
        end
    end
    return false
end

Hook.Patch("Barotrauma.AnimController", "GetAimWobble", function(instance, ptable)
    local character = instance.Character
    local hasStableShooting = character and character.Info
        and character.Info:GetSavedStatValue(StatTypes.None, STABLE_SHOOTING_MARKER) > 0
    if hasStableShooting or HasAnyBuff(character, AimWobbleBuffs) then
        ptable.PreventExecution = true
        return 0
    end
end, Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.Character", "CalculateMovementPenalty", function(instance, ptable)
    if HasAnyBuff(instance, MovePenaltyBuffs) then
        ptable.PreventExecution = true
        return 0
    end
end, Hook.HookMethodType.Before)