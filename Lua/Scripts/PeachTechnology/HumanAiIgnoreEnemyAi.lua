local DEBUG = false

local function log(...)
	if DEBUG then
		print("[HumanAIIgnoreEnemyAI]", ...)
	end
end

local IGNORED_FLAG = AbilityFlags.IgnoredByEnemyAI

Hook.Patch(
	"Barotrauma.AIObjectiveFightIntruders",
	"IsValidTarget",
	{
		"Barotrauma.Character",
		"Barotrauma.Character",
		"System.Boolean"
	},
	function(instance, ptable)
		local target = ptable["target"]

		if target ~= nil and target:HasAbilityFlag(IGNORED_FLAG) then
			log("IsValidTarget: ignored flagged target " .. target.Name)
			ptable.PreventExecution = true
			return false
		end
	end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"Barotrauma.HumanAIController",
	"RespondToAttack",
	{
		"Barotrauma.Character",
		"Barotrauma.AttackResult"
	},
	function(instance, ptable)
		local attacker = ptable["attacker"]

		if attacker ~= nil and attacker:HasAbilityFlag(IGNORED_FLAG) then
			log("RespondToAttack: ignored flagged attacker " .. attacker.Name)
			ptable.PreventExecution = true
		end
	end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"Barotrauma.HumanAIController",
	"AddCombatObjective",
	function(instance, ptable)
		local target = ptable["target"]

		if target ~= nil and target:HasAbilityFlag(IGNORED_FLAG) then
			log("AddCombatObjective: ignored flagged target " .. target.Name)
			ptable.PreventExecution = true
		end
	end,
	Hook.HookMethodType.Before
)
