local HumanAIIgnoreEnemyAIPatchMod = {
    DebugMode = false,
}

local function log(...)
    if HumanAIIgnoreEnemyAIPatchMod.DebugMode then
        print("[HumanAIIgnoreEnemyAI]", ...)
    end
end

-- Patch 1: AIObjectiveFightIntruders.IsValidTarget (After/Postfix)
-- 原方法判定目标有效后，若目标带 IgnoredByEnemyAI 标记则强制返回 false
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
        local result = ptable.ReturnValue

        if result and target ~= nil then
            if target:HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI) then
                log("IsValidTarget: 忽略标记目标 " .. tostring(target.Name))
                return false
            end
        end

        return result
    end,
    Hook.HookMethodType.After
)

-- Patch 2: HumanAIController.RespondToAttack (Before/Prefix)
-- 若攻击者带 IgnoredByEnemyAI 标记则跳过响应
Hook.Patch(
    "Barotrauma.HumanAIController",
    "RespondToAttack",
    {
        "Barotrauma.Character",
        "Barotrauma.AttackResult"
    },
    function(instance, ptable)
        local attacker = ptable["attacker"]

        if attacker ~= nil and attacker:HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI) then
            log("RespondToAttack: 忽略标记攻击者 " .. tostring(attacker.Name))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

-- Patch 3: HumanAIController.AddCombatObjective (Before/Prefix)
-- 若战斗目标带 IgnoredByEnemyAI 标记则跳过添加战斗任务
Hook.Patch(
    "Barotrauma.HumanAIController",
    "AddCombatObjective",
    function(instance, ptable)
        local target = ptable["target"]

        if target ~= nil and target:HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI) then
            log("AddCombatObjective: 忽略标记目标 " .. tostring(target.Name))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)
