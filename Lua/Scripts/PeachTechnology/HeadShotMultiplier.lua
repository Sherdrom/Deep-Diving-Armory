local CONFIG = {
	bypassResistance = false,  -- 是否绕过抗性：当抗性极高(divisor<=0.001)时，启用则直接无视抗性，关闭则正常受抗性影响
}

local DEBUG = false

local function log(...)
	if DEBUG then
		print("[HeadShotMultiplier]", ...)
	end
end

local function parseHeadshotMultipliers(tagsStr)
	if tagsStr == nil or tagsStr == "" then
		return nil
	end
	local multipliers = {}
	for tagStr in string.gmatch(tagsStr, "[^,]+") do
		tagStr = string.gsub(tagStr, "^%s*(.-)%s*$", "%1")
		local affType, multStr = string.match(tagStr, "^deep_headshot_(.+)_([%d%.]+)$")
		if affType and multStr then
			local mult = tonumber(multStr)
			if mult and mult > 0 then
				multipliers[affType] = mult
				log("Parsed tag:", tagStr, "->", affType, "x" .. mult)
			end
		end
	end
	if next(multipliers) == nil then
		return nil
	end
	return multipliers
end

local multiplierCache = {}

local function getHeadshotMultipliers(item)
	local tags = item.Tags
	local cached = multiplierCache[tags]
	if cached ~= nil then
		return cached
	end
	local result = parseHeadshotMultipliers(tags)
	multiplierCache[tags] = result
	return result
end

local pendingHeadshot = {}

Hook.Patch("Barotrauma.Character", "ApplyAttack",
{
	"Barotrauma.Character",
	"Microsoft.Xna.Framework.Vector2",
	"Barotrauma.Attack",
	"System.Single",
	"Microsoft.Xna.Framework.Vector2",
	"System.Boolean",
	"Barotrauma.Limb",
	"System.Single"
},
function(instance, p)
	pendingHeadshot[instance] = nil

	local targetLimb = p["targetLimb"]
	if targetLimb == nil or targetLimb.type ~= LimbType.Head then
		return
	end

	log("=== ApplyAttack head hit ===")

	local attack = p["attack"]
	local sourceItem = attack.SourceItem
	log("SourceItem:", sourceItem ~= nil and tostring(sourceItem) or "nil")

	if sourceItem == nil then
		log("-> no SourceItem, skip")
		return
	end

	local multipliers = getHeadshotMultipliers(sourceItem)
	if multipliers == nil then
		log("-> weapon has no deep_headshot_* tags, skip")
		return
	end

	local copy = {}
	for k, v in pairs(multipliers) do
		copy[k] = v
	end
	pendingHeadshot[instance] = copy
	log("-> multipliers recorded")
end, Hook.HookMethodType.Before)

local bypassResistanceId = nil

Hook.Patch("Barotrauma.CharacterHealth", "AddLimbAffliction",
{
	"Barotrauma.Limb",
	"Barotrauma.Affliction",
	"System.Boolean",
	"System.Boolean"
},
function(instance, p)
	local character = instance.Character
	local multipliers = pendingHeadshot[character]
	if multipliers == nil then
		return
	end

	local limb = p["limb"]
	if limb == nil then
		return
	end

	local affliction = p["newAffliction"]
	local affId = tostring(affliction.Prefab.Identifier)
	log("AddLimbAffliction: " .. affId .. " strength=" .. tostring(affliction.Strength))

	local mult = multipliers[affId]
	if mult == nil then
		log("-> this affliction has no multiplier, skip")
		return
	end

	multipliers[affId] = nil
	if next(multipliers) == nil then
		pendingHeadshot[character] = nil
	end

	local resistance = instance:GetResistance(affliction.Prefab, limb.type)
	local divisor = 1 - resistance
	log("Resistance:" .. tostring(resistance) .. " divisor:" .. tostring(divisor))

	local oldStrength = affliction.Strength

	if divisor > 0.001 then
		affliction.Strength = oldStrength * mult / divisor
		log(">>> Multiplier applied (compensation)! " .. affId .. " x" .. mult
			.. " old:" .. tostring(oldStrength)
			.. " new:" .. tostring(affliction.Strength)
			.. " resistance:" .. tostring(resistance))
	else
		if CONFIG.bypassResistance then
			bypassResistanceId = affId
		end
		affliction.Strength = oldStrength * mult
		log(">>> Multiplier applied (resistance bypass)! " .. affId .. " x" .. mult
			.. " old:" .. tostring(oldStrength)
			.. " new:" .. tostring(affliction.Strength)
			.. (CONFIG.bypassResistance and "" or " (bypass disabled)"))
	end
end, Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.CharacterHealth", "GetResistance",
{
	"Barotrauma.AfflictionPrefab",
	"Barotrauma.LimbType"
},
function(instance, p)
	if bypassResistanceId ~= nil then
		local prefab = p["afflictionPrefab"]
		local prefabId = tostring(prefab.Identifier)
		log("GetResistance called: prefab=" .. prefabId .. " bypassId=" .. bypassResistanceId)
		if prefabId == bypassResistanceId then
			bypassResistanceId = nil
			log("-> bypass resistance: return 0")
			p.PreventExecution = true
			return 0
		end
	end
end, Hook.HookMethodType.Before)