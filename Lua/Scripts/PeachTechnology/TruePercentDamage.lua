local DEADLY_IDS = {
	"deep_headshot_deadly",
	"deep_headshot_deadly_irresistible",
}

local deadlyCache = {}
setmetatable(deadlyCache, { __mode = "k" })

local function hasDeadlyAffliction(charHealth)
	if deadlyCache[charHealth] ~= nil then
		return deadlyCache[charHealth]
	end
	for i = 1, #DEADLY_IDS do
		if charHealth:GetAfflictionStrengthByIdentifier(DEADLY_IDS[i]) > 0 then
			deadlyCache[charHealth] = true
			return true
		end
	end
	deadlyCache[charHealth] = false
	return false
end

local function isHealing(affliction, charHealth)
	if charHealth == nil then
		return false
	end
	return affliction:GetVitalityDecrease(charHealth) < 0
end

Hook.Add("afflictionUpdate", "VCE_TruePercentDamage_Cache", function(affliction, characterHealth, limb)
	if characterHealth == nil then
		return
	end
	local affId = tostring(affliction.Identifier)
	for i = 1, #DEADLY_IDS do
		if affId == DEADLY_IDS[i] then
			deadlyCache[characterHealth] = nil
			return
		end
	end
end)

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

Hook.Add("character.applyAffliction", "VCE_TruePercentDamage_Cache", function(charHealth, limbHealth, newAffliction)
	if charHealth == nil then
		return
	end
	local affId = tostring(newAffliction.Identifier)
	for i = 1, #DEADLY_IDS do
		if affId == DEADLY_IDS[i] then
			deadlyCache[charHealth] = nil
			return
		end
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