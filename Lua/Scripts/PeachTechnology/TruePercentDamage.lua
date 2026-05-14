local DEADLY_IDS = {
	"deep_headshot_deadly",
	"deep_headshot_deadly_irresistible",
}

local function hasDeadlyAffliction(charHealth)
	for i = 1, #DEADLY_IDS do
		if charHealth:GetAfflictionStrengthByIdentifier(DEADLY_IDS[i]) > 0 then
			return true
		end
	end
	return false
end

local function isHealing(affliction, charHealth)
	if charHealth == nil then
		return false
	end
	return affliction:GetVitalityDecrease(charHealth) < 0
end

Hook.Add("afflictionUpdate", "VCE_TruePercentDamage_Update", function(affliction, characterHealth, limb)
	if characterHealth == nil then
		return
	end
	if not hasDeadlyAffliction(characterHealth) then
		return
	end
	if not isHealing(affliction, characterHealth) then
		return
	end

	if affliction.Strength > 0 then
		affliction.Strength = 0
	end
end)

Hook.Add("character.applyAffliction", "VCE_TruePercentDamage_Block", function(charHealth, limbHealth, newAffliction, allowStacking)
	if charHealth == nil then
		return
	end
	if not hasDeadlyAffliction(charHealth) then
		return
	end
	if not isHealing(newAffliction, charHealth) then
		return
	end

	return true
end)