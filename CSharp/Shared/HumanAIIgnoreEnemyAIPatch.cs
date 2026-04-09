using HarmonyLib;
using System;

namespace Barotrauma
{
    [HarmonyPatch]
    public class HumanAIIgnoreEnemyAIPatch
    {
        // 补丁AIObjectiveFightIntruders.IsValidTarget方法，确保它正确检查IgnoredByEnemyAI标志
        [HarmonyPatch(typeof(AIObjectiveFightIntruders), nameof(AIObjectiveFightIntruders.IsValidTarget), new Type[] { typeof(Character), typeof(Character), typeof(bool) })]
        [HarmonyPostfix]
        public static void Postfix(Character target, ref bool __result)
        {
            // 如果目标已经无效，直接返回
            if (!__result) return;

            // 检查目标是否有IgnoredByEnemyAI标志
            if (target.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                __result = false;
            }
        }

        // 补丁HumanAIController.RespondToAttack方法，确保被攻击时也会检查IgnoredByEnemyAI标志
        [HarmonyPatch(typeof(HumanAIController), nameof(HumanAIController.RespondToAttack))]
        [HarmonyPrefix]
        public static bool Prefix(HumanAIController __instance, Character attacker)
        {
            // 检查攻击者是否有IgnoredByEnemyAI标志
            if (attacker != null && attacker.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                // 如果攻击者有IgnoredByEnemyAI标志，不响应攻击
                return false;
            }
            return true;
        }

        // 补丁HumanAIController.AddCombatObjective方法，确保添加战斗目标时检查IgnoredByEnemyAI标志
        [HarmonyPatch(typeof(HumanAIController), nameof(HumanAIController.AddCombatObjective))]
        [HarmonyPrefix]
        public static bool Prefix(object[] __args)
        {
            // 检查参数数量
            if (__args.Length < 2)
            {
                return true;
            }

            // 获取目标参数
            Character target = __args[1] as Character;
            
            // 检查目标是否有IgnoredByEnemyAI标志
            if (target != null && target.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                // 如果目标有IgnoredByEnemyAI标志，不添加战斗目标
                return false;
            }
            return true;
        }
    }
}