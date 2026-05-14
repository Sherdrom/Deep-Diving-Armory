local AimWobbleBuffs = { "deep_calm_buff", "deep_stable_shooting", "deep_contract_harsh_training_detect" }
local MovePenaltyBuffs = { "deep_calm_buff", "deep_contract_harsh_training_detect" }

local function HasAnyBuff(character, buffs, minamount)
	if character == nil or character.CharacterHealth == nil then
		return false
	end
	for _, id in ipairs(buffs) do
		local aff = character.CharacterHealth.GetAffliction(id)
		if aff ~= nil and aff.Strength >= (minamount or 1) then
			return true
		end
	end
	return false
end

Hook.Patch("Barotrauma.AnimController", "GetAimWobble", function(instance, ptable)
	if HasAnyBuff(instance.Character, AimWobbleBuffs, 1) then
		ptable.PreventExecution = true
		return 0
	end
end, Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.Character", "CalculateMovementPenalty", function(instance, ptable)
	if HasAnyBuff(instance, MovePenaltyBuffs, 1) then
		ptable.PreventExecution = true
		return 0
	end
end, Hook.HookMethodType.Before)