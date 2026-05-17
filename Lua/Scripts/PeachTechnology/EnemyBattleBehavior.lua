local function HasAffliction(character, identifier, minamount)
	if character == nil or character.CharacterHealth == nil then
		return false
	end

	local aff = character.CharacterHealth.GetAffliction(identifier)
	if aff ~= nil then
		return aff.Strength >= (minamount or 0.5)
	end
	return false
end

local LimbType_Head = 11
local LimbType_Torso = 12
local LimbType_RightThigh = 15
local LimbType_LeftThigh = 16
local LimbType_LeftLeg = 7
local LimbType_RightLeg = 8
local LimbType_Legs = 14

local function SetAimTarget(target, limb)
	if target == nil or limb == nil then
		return false
	end

	target.CursorPosition = limb.WorldPosition

	if target.Submarine ~= nil then
		target.CursorPosition = target.CursorPosition - target.Submarine.Position
	end

	return true
end

Hook.Patch("Barotrauma.HumanAIController", "Update", function(instance)
	if instance.AnimController.Crouching then
		if HasAffliction(instance.Character, "deep_no_crouching_detect", 1) then
			instance.AnimController.Crouching = false
		end
	end
end, Hook.HookMethodType.After)

Hook.Patch("Barotrauma.AIObjectiveCombat", "Attack", {"System.Single"}, function(instance)
	local enemy = instance.Enemy
	local target = instance.character

	if enemy == nil or target == nil then
		return
	end

	local animController = enemy.AnimController
	if animController == nil then
		return
	end

	local targetLimb = nil

	if HasAffliction(instance.character, "deep_aim_head_detect", 1) then
		targetLimb = animController.GetLimb(LimbType_Head)
	elseif HasAffliction(instance.character, "deep_aim_thigh_detect", 1) then
		targetLimb = animController.GetLimb(LimbType_RightThigh)
		if targetLimb == nil then
			targetLimb = animController.GetLimb(LimbType_LeftThigh)
		end
		if targetLimb == nil then
			targetLimb = animController.GetLimb(LimbType_Legs)
		end
	elseif HasAffliction(instance.character, "deep_aim_legs_detect", 1) then
		targetLimb = animController.GetLimb(LimbType_RightLeg)
		if targetLimb == nil then
			targetLimb = animController.GetLimb(LimbType_LeftLeg)
		end
		if targetLimb == nil then
			targetLimb = animController.GetLimb(LimbType_Legs)
		end
	else
		targetLimb = animController.GetLimb(LimbType_Torso)
	end

	SetAimTarget(target, targetLimb)
end, Hook.HookMethodType.After)

local TARGET_AFFLICTION_CANCEL = "deep_cancel_order_detect"
local TARGET_AFFLICTION_HUNTING = "deep_hunting_order_detect"
local CHECK_INTERVAL = 1
local lastCheckTime = 0

local DismissalOrderPrefab = OrderPrefab.Dismissal
local FightIntrudersOrderPrefab = OrderPrefab.Prefabs["fightintruders"]

Hook.Add("think", "EnemyBattleBehaviorOrders", function()
	local currentTime = Timer.GetTime()

	if currentTime - lastCheckTime < CHECK_INTERVAL then
		return
	end

	lastCheckTime = currentTime

	for _, character in pairs(Character.CharacterList) do
		if character.IsHuman then
			local cancelStrength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(TARGET_AFFLICTION_CANCEL)

			if cancelStrength > 0.5 then
				local dismissalOrder = DismissalOrderPrefab.CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
				character.SetOrder(dismissalOrder, true, false)
			end

			local huntingStrength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(TARGET_AFFLICTION_HUNTING)

			if huntingStrength > 0.5 and FightIntrudersOrderPrefab then
				local fightOrder = FightIntrudersOrderPrefab.CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
				character.SetOrder(fightOrder, true, false, true)

				if character.AIController then
					character.AIController.SetForcedOrder(fightOrder)
				end
			end
		end
	end
end)

local AFFLICTION_ID = "deep_execute_detect"

local AIObjectiveDescriptor = LuaUserData.RegisterType("Barotrauma.AIObjective")
LuaUserData.MakePropertyAccessible(AIObjectiveDescriptor, "Priority")

local function HasRequiredAffliction(character)
	if character == nil or character.CharacterHealth == nil then
		return false
	end
	local strength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(AFFLICTION_ID)
	return strength ~= nil and strength > 0
end

Hook.Patch(
	"Barotrauma.AIObjectiveCombat",
	"CheckObjectiveState",
	function(instance, ptable)
		local enemy = instance.Enemy
		if enemy == nil then return end
		if not enemy.IsPlayer then return end
		if enemy.IsDead then return end

		if not HasRequiredAffliction(instance.character) then return end

		ptable.PreventExecution = true
		return false
	end,
	Hook.HookMethodType.Before
)

Hook.Patch(
	"Barotrauma.AIObjectiveCombat",
	"GetPriority",
	function(instance, ptable)
		local enemy = instance.Enemy
		if enemy == nil then return end
		if not enemy.IsPlayer then return end
		if enemy.IsDead then return end

		if not HasRequiredAffliction(instance.character) then return end

		if ptable.ReturnValue ~= nil and ptable.ReturnValue <= 0 then
			instance.Priority = 91
			return 91
		end
	end,
	Hook.HookMethodType.After
)