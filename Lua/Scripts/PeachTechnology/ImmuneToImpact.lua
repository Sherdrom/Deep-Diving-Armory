local DEBUG = false

local function dbg(message)
	if DEBUG then
		print("[ImmuneToImpact] " .. tostring(message))
	end
end

local IMPACT_AFFLICTIONS = {
	{ id = "deep_immunetoimpact_0",   retainFactor = 1.0 },
	{ id = "deep_immunetoimpact_25",  retainFactor = 0.75 },
	{ id = "deep_immunetoimpact_50",  retainFactor = 0.5 },
	{ id = "deep_immunetoimpact_75",  retainFactor = 0.25 },
	{ id = "deep_immunetoimpact_90",  retainFactor = 0.1 },
	{ id = "deep_immunetoimpact_95",  retainFactor = 0.05 },
	{ id = "deep_immunetoimpact_100", retainFactor = 0.0 },
}

local function GetAfflictionStrength(character, identifier)
	if character == nil or character.CharacterHealth == nil then
		return 0
	end
	return character.CharacterHealth.GetAfflictionStrengthByIdentifier(identifier)
end

local function FindActiveImpactReduction(character)
	local bestEntry = nil
	local bestStrength = 0

	for i = 1, #IMPACT_AFFLICTIONS do
		local entry = IMPACT_AFFLICTIONS[i]
		local strength = GetAfflictionStrength(character, entry.id)
		if strength > 0.5 and strength > bestStrength then
			bestEntry = entry
			bestStrength = strength
			dbg("FindActiveImpactReduction: candidate - " .. entry.id
				.. " (strength: " .. tostring(strength) .. ")")
		end
	end

	if bestEntry then
		dbg("FindActiveImpactReduction: best match - " .. bestEntry.id
			.. " (retainFactor: " .. tostring(bestEntry.retainFactor) .. ")")
	else
		dbg("FindActiveImpactReduction: no impact reduction affliction found")
	end

	return bestEntry
end

local pendingRestorations = {}

local attackDescriptor = LuaUserData.RegisterType("Barotrauma.Attack")
LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetForce")
LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetImpulse")
LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetForceWorld")
LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetImpulseWorld")
LuaUserData.MakePropertyAccessible(attackDescriptor, "ImpactMultiplier")

Hook.Patch(
	"ImmuneToImpact_Before",
	"Barotrauma.Character",
	"ApplyAttack",
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
	function(instance, ptable)
		dbg("--- [BEFORE] ApplyAttack ---")

		if not instance.IsPlayer then
			dbg("[BEFORE] not a player, skip")
			return
		end

		local impactConfig = FindActiveImpactReduction(instance)
		if impactConfig == nil then
			dbg("[BEFORE] no impact reduction affliction, skip")
			return
		end

		local reductionFactor = impactConfig.retainFactor
		dbg("[BEFORE] active: " .. impactConfig.id .. " (factor x" .. tostring(reductionFactor) .. ")")

		local attack = ptable["attack"]
		if attack == nil then
			dbg("[BEFORE] attack is nil, skip")
			return
		end

		local originalValues = {
			TargetForce = attack.TargetForce,
			TargetImpulse = attack.TargetImpulse,
			TargetForceWorld = attack.TargetForceWorld,
			TargetImpulseWorld = attack.TargetImpulseWorld,
			ImpulseDirection = ptable["impulseDirection"],
			ReductionFactor = reductionFactor,
		}
		pendingRestorations[tostring(attack)] = originalValues

		dbg("[BEFORE] saved - TargetForce: " .. tostring(originalValues.TargetForce)
			.. " TargetImpulse: " .. tostring(originalValues.TargetImpulse))

		attack.TargetForce = originalValues.TargetForce * reductionFactor
		attack.TargetImpulse = originalValues.TargetImpulse * reductionFactor
		attack.TargetForceWorld = originalValues.TargetForceWorld * reductionFactor
		attack.TargetImpulseWorld = originalValues.TargetImpulseWorld * reductionFactor

		if originalValues.ImpulseDirection ~= nil then
			ptable["impulseDirection"] = originalValues.ImpulseDirection * reductionFactor
		end

		dbg("[BEFORE] modified - TargetForce: " .. tostring(attack.TargetForce)
			.. " (x" .. tostring(reductionFactor) .. ")")
	end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"ImmuneToImpact_After",
	"Barotrauma.Character",
	"ApplyAttack",
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
	function(instance, ptable)
		local attack = ptable["attack"]
		if attack == nil then
			return
		end

		local attackKey = tostring(attack)
		local originalValues = pendingRestorations[attackKey]
		if originalValues == nil then
			return
		end

		attack.TargetForce = originalValues.TargetForce
		attack.TargetImpulse = originalValues.TargetImpulse
		attack.TargetForceWorld = originalValues.TargetForceWorld
		attack.TargetImpulseWorld = originalValues.TargetImpulseWorld

		if originalValues.ImpulseDirection ~= nil then
			ptable["impulseDirection"] = originalValues.ImpulseDirection
		end

		pendingRestorations[attackKey] = nil

		dbg("[AFTER] restored - TargetForce: " .. tostring(originalValues.TargetForce))
	end,
	Hook.HookMethodType.After
)