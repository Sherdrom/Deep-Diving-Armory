local AH = AfflictionHelper

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
        if AH.GetAffStrength(instance.Character, "deep_enemy_affliction_resistance") > 0.1 then
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

    if AH.GetAffStrength(instance.character, "deep_aim_head_detect") > 0.1 then
        targetLimb = animController.GetLimb(LimbType_Head)
    elseif AH.GetAffStrength(instance.character, "deep_aim_thigh_detect") > 0.1 then
        targetLimb = animController.GetLimb(LimbType_RightThigh)
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_LeftThigh)
        end
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_Legs)
        end
    elseif AH.GetAffStrength(instance.character, "deep_aim_legs_detect") > 0.1 then
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
            if AH.GetAffStrength(character, TARGET_AFFLICTION_CANCEL) > 0.5 then
                local dismissalOrder = DismissalOrderPrefab.CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
                character.SetOrder(dismissalOrder, true, false)
            end

            if AH.GetAffStrength(character, TARGET_AFFLICTION_HUNTING) > 0.5 and FightIntrudersOrderPrefab then
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

Hook.Patch(
    "Barotrauma.AIObjectiveCombat",
    "CheckObjectiveState",
    function(instance, ptable)
        local enemy = instance.Enemy
        if enemy == nil then return end
        if not enemy.IsPlayer then return end
        if enemy.IsDead then return end

        if AH.GetAffStrength(instance.character, AFFLICTION_ID) <= 0 then return end

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

        if AH.GetAffStrength(instance.character, AFFLICTION_ID) <= 0 then return end

        if ptable.ReturnValue ~= nil and ptable.ReturnValue <= 0 then
            instance.Priority = 91
            return 91
        end
    end,
    Hook.HookMethodType.After
)

-- ============================================================
-- Deep Diver AI Attack Distance Limiter (NFF-Compatible)
-- Patch target: AIObjectiveCombat.UseWeapon
-- Both original Attack() and NFF's copied Attack() eventually call UseWeapon(),
-- so patching here ensures compatibility regardless of NFF installation.
-- ============================================================

local JOB_CONFIGS = {
    ["deep_securityofficer_enemy"] = {
        AttackDistanceLimit = 1200,
        CanReport = false,
        BlockedByAffliction = {
            Identifier = "deep_enemy_attacked_result",
            MinStrength = 0.1,
        },
    },
    ["deep_medicaldoctor_enemy"] = {
        AttackDistanceLimit = 1200,
        CanReport = false,
        BlockedByAffliction = {
            Identifier = "deep_enemy_attacked_result",
            MinStrength = 0.1,
        },
    },
}

-- Precompute squared distances to avoid sqrt per-frame cost
for _, config in pairs(JOB_CONFIGS) do
    if config.AttackDistanceLimit ~= nil then
        config.AttackDistanceLimitSqr = config.AttackDistanceLimit * config.AttackDistanceLimit
    end
end

-- ------------------------------------------------------------
-- GetJobConfig: match character to config, check affliction block
-- ------------------------------------------------------------
local function GetJobConfig(character)
    if character == nil or not character.IsHuman then
        return nil
    end
    for jobId, config in pairs(JOB_CONFIGS) do
        if character:HasJob(jobId) then
            local block = config.BlockedByAffliction
            if block ~= nil then
                local affliction = character.CharacterHealth:GetAffliction(block.Identifier)
                if affliction ~= nil and affliction.Strength > block.MinStrength then
                    return nil
                end
            end
            return config
        end
    end
    return nil
end

-- ------------------------------------------------------------
-- [PATCH 1] Attack Distance Limiter
-- Target: AIObjectiveCombat.UseWeapon(float deltaTime)
--
-- Why UseWeapon instead of Attack:
--   - Original AIObjectiveCombat.Attack() calls UseWeapon() to fire
--   - No Friendly Fire SIG copies Attack() logic into a Harmony Prefix,
--     which ALSO calls __instance.UseWeapon(deltaTime) internally
--   - Patching UseWeapon intercepts BOTH code paths uniformly
--   - Source: AIObjectiveCombat.cs line 1548, private void UseWeapon(float deltaTime)
-- ------------------------------------------------------------

Hook.Patch(
    "AttackDistanceLimit_UseWeapon",
    "Barotrauma.AIObjectiveCombat",
    "UseWeapon",
    { "System.Single" },
    function(instance, ptable)
        -- instance = AIObjectiveCombat instance
        -- Accessible fields (verified against source):
        --   instance.character       : Character (private field, LuaCs exposes via reflection)
        --   instance.Enemy           : Character (public property)
        --   instance.Weapon          : Item      (public field)
        --   instance.WeaponComponent : ItemComponent (public property)

        local character = instance.character
        local config = GetJobConfig(character)
        if config == nil then
            return
        end

        local limitSqr = config.AttackDistanceLimitSqr
        if limitSqr == nil then
            return
        end

        local enemy = instance.Enemy
        if enemy == nil or enemy.Removed then
            return
        end

        local weapon = instance.Weapon
        if weapon == nil then
            return
        end

        -- Only apply distance limit to ranged weapons.
        -- Melee weapons have engine-level collision constraints and do not need this check.
        local rc = weapon:GetComponentString("RangedWeapon")
            or weapon:GetComponentString("SwitchableRangedWeapon")
        if rc == nil then
            return
        end

        -- Squared distance comparison (avoids math.sqrt overhead)
        local charPos = character.WorldPosition
        local enemyPos = enemy.WorldPosition
        local dx = charPos.X - enemyPos.X
        local dy = charPos.Y - enemyPos.Y

        if dx * dx + dy * dy > limitSqr then
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

-- ------------------------------------------------------------
-- [PATCH 2] Disable Attack Reporting + Force Immediate Counterattack
-- Target: HumanAIController.RespondToAttack(Character, AttackResult)
-- Not affected by NFF (NFF does not patch RespondToAttack)
-- ------------------------------------------------------------

Hook.Patch(
    "AttackDistanceLimit_NoReport",
    "Barotrauma.HumanAIController",
    "RespondToAttack",
    { "Barotrauma.Character", "Barotrauma.AttackResult" },
    function(instance, ptable)
        local config = GetJobConfig(instance.Character)
        if config == nil then
            return
        end

        if config.CanReport ~= false then
            return
        end

        local attacker = ptable["attacker"]
        if attacker ~= nil and instance:IsFriendly(attacker) then
            return
        end

        ptable.PreventExecution = true

        if instance.Character.IsBot and attacker ~= nil then
            instance:AddCombatObjective(CombatMode.Offensive, attacker, 0)
        end
    end,
    Hook.HookMethodType.Before
)