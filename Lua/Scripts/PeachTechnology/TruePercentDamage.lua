local DEADLY_IDS = {
	"deep_headshot_deadly",
	"deep_headshot_deadly_irresistible",
}

local deadlyCache = setmetatable({}, { __mode = "k" })

local function isDeadlyAffliction(affliction)
	local identifier = tostring(affliction.Identifier)
	for i = 1, #DEADLY_IDS do
		if identifier == DEADLY_IDS[i] then return true end
	end
	return false
end

local function hasDeadlyAffliction(charHealth)
	if deadlyCache[charHealth] ~= nil then return deadlyCache[charHealth] end
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

Hook.Add("afflictionUpdate", "VCE_TruePercentDamage_Update", function(affliction, charHealth, limb)
	if charHealth == nil or affliction == nil then return end
	if isDeadlyAffliction(affliction) then
		deadlyCache[charHealth] = nil
		return
	end
	if affliction.Strength > 0
		and isHealing(affliction, charHealth)
		and hasDeadlyAffliction(charHealth) then
		affliction.Strength = 0
	end
end)

Hook.Add("character.applyAffliction", "VCE_TruePercentDamage_Block", function(charHealth, limbHealth, newAffliction, allowStacking)
	if charHealth == nil or newAffliction == nil then return end
	if isDeadlyAffliction(newAffliction) then
		deadlyCache[charHealth] = nil
		return
	end
	if not isHealing(newAffliction, charHealth) or not hasDeadlyAffliction(charHealth) then return end
	newAffliction.Strength = 0
	return true
end)
