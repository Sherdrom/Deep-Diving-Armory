local DEBUG = false
local MARKER_EXPIRY_TIME = 2.0
local CLEANUP_INTERVAL = 5.0

local NO_FRIENDLY_FIRE_AFFLICTIONS = {
	{ id = "friendly_fire",         multiplier = 0.0 },
	{ id = "deep_noff_reduce95",    multiplier = 0.05 },
	{ id = "deep_noff_reduce75",    multiplier = 0.25 },
	{ id = "deep_noff_reduce50",    multiplier = 0.50 },
}

local function dbg(message)
	if DEBUG then
		print("[NFD-DEBUG] " .. tostring(message))
	end
end

local function GetAfflictionStrength(character, identifier)
	if character == nil or character.CharacterHealth == nil then
		return 0
	end
	return character.CharacterHealth.GetAfflictionStrengthByIdentifier(identifier)
end

local function IsSameTeam(char1, char2)
	if char1 == nil or char2 == nil then
		return false
	end
	return (char1.TeamID == char2.TeamID) and (char1.TeamID >= 0)
end

local function FindActiveFFConfig(attacker)
	local bestMultiplier = nil
	local bestAfflictionId = nil
	local bestStrength = 0

	for i = 1, #NO_FRIENDLY_FIRE_AFFLICTIONS do
		local entry = NO_FRIENDLY_FIRE_AFFLICTIONS[i]
		local strength = GetAfflictionStrength(attacker, entry.id)
		if strength > 0.5 and strength > bestStrength then
			bestMultiplier = entry.multiplier
			bestAfflictionId = entry.id
			bestStrength = strength
			dbg("candidate: " .. entry.id .. " strength:" .. string.format("%.1f", strength))
		end
	end

	return bestMultiplier, bestAfflictionId
end

local function ApplyDamageModification(attackResult, multiplier)
	local afflictions = attackResult.Afflictions
	if afflictions == nil then
		return false
	end

	local modifiedCount = 0
	for _, affliction in ipairs(afflictions) do
		if affliction ~= nil then
			local original = affliction.Strength
			affliction.Strength = original * multiplier
			modifiedCount = modifiedCount + 1
			dbg(string.format("  modify: %s %.1f -> %.1f (x%.2f)",
				tostring(affliction.Prefab.Identifier),
				original, affliction.Strength, multiplier))
		end
	end

	return modifiedCount > 0
end

local NoFriendlyDamage = {
	pendingDamages = {},
	lastCleanupTime = 0,
	stats = {
		totalChecks = 0,
		appliedModifications = 0,
		skippedAttacks = 0,
	},
}

Hook.Add("character.damageLimb", "NFD.OnDamageLimb", function(
	character, worldPosition, hitLimb, afflictions, stun,
	playSound, attackImpulse, attacker, damageMultiplier,
	allowStacking, penetration, shouldImplode)

	if DEBUG then
		NoFriendlyDamage.stats.totalChecks = NoFriendlyDamage.stats.totalChecks + 1
	end

	if attacker == nil or character == nil then
		return nil
	end

	if not attacker.IsHuman then
		return nil
	end

	local multiplier, afflictionId = FindActiveFFConfig(attacker)
	if not multiplier then
		if DEBUG then
			NoFriendlyDamage.stats.skippedAttacks = NoFriendlyDamage.stats.skippedAttacks + 1
		end
		return nil
	end

	if not IsSameTeam(attacker, character) then
		if DEBUG then
			NoFriendlyDamage.stats.skippedAttacks = NoFriendlyDamage.stats.skippedAttacks + 1
		end
		dbg("skip: different team - " .. attacker.Name .. " -> " .. character.Name)
		return nil
	end

	local charId = tostring(character.ID or "unknown")

	NoFriendlyDamage.pendingDamages[charId] = {
		time = Timer.GetTime(),
		multiplier = multiplier,
		sourceAffliction = afflictionId,
	}

	dbg(string.format("mark pending: %s -> %s (%s, x%.2f)",
		tostring(attacker.Name), tostring(character.Name),
		afflictionId, multiplier))

	return nil
end)

Hook.Patch(
	"NFD_ApplyDamage",
	"Barotrauma.CharacterHealth",
	"ApplyDamage",
	function(instance, ptable)
		local attackResult = ptable["attackResult"]
		local character = instance.Character

		if attackResult == nil or character == nil then
			return
		end

		local charId = tostring(character.ID or "unknown")
		local pendingData = NoFriendlyDamage.pendingDamages[charId]

		if pendingData == nil then
			return
		end

		local currentTime = Timer.GetTime()
		if currentTime - pendingData.time > MARKER_EXPIRY_TIME then
			NoFriendlyDamage.pendingDamages[charId] = nil
			dbg("marker expired: " .. charId)
			return
		end

		dbg(string.format("apply damage modification: %s (%s, x%.2f)",
			tostring(character.Name), pendingData.sourceAffliction, pendingData.multiplier))

		local success = ApplyDamageModification(attackResult, pendingData.multiplier)

		if success then
			if DEBUG then
				NoFriendlyDamage.stats.appliedModifications = NoFriendlyDamage.stats.appliedModifications + 1
			end
			dbg("modification succeeded")
		else
			dbg("modification failed or no afflictions")
		end

		NoFriendlyDamage.pendingDamages[charId] = nil
	end,
	Hook.HookMethodType.Before
)

Hook.Add("think", "NFD.Cleanup", function()
	local currentTime = Timer.GetTime()

	if currentTime - NoFriendlyDamage.lastCleanupTime < CLEANUP_INTERVAL then
		return
	end

	NoFriendlyDamage.lastCleanupTime = currentTime

	local count = 0
	for charId, data in pairs(NoFriendlyDamage.pendingDamages) do
		if currentTime - data.time > MARKER_EXPIRY_TIME * 2 then
			NoFriendlyDamage.pendingDamages[charId] = nil
			count = count + 1
		end
	end

	if count > 0 then
		dbg("cleaned " .. count .. " expired entries")
	end
end)

function NoFriendlyDamage.GetStats()
	return {
		pendingCount = 0,
		totalChecks = NoFriendlyDamage.stats.totalChecks,
		appliedMods = NoFriendlyDamage.stats.appliedModifications,
		skipped = NoFriendlyDamage.stats.skippedAttacks,
	}
end

NoFriendlyDamage.IsSameTeam = IsSameTeam
NoFriendlyDamage.FindActiveFFConfig = FindActiveFFConfig

return NoFriendlyDamage