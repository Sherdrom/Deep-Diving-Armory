-- NoKillDownedPlayer.lua
-- 功能: 当人类敌人身上有 deep_execute_detect 的 affliction 时，无视玩家昏迷状态继续攻击直到杀死

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

-- Patch 1: 阻止 CheckObjectiveState 在玩家仅昏迷时返回 true
-- 当返回 true 时战斗目标被标记为完成，敌人停止攻击
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

-- Patch 2: 防止 GetPriority 对昏迷玩家返回 0
-- 优先级为 0 会导致战斗目标被其他目标挤掉
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