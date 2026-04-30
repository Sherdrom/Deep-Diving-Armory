using HarmonyLib;

namespace HumanAIIgnoreEnemyAIPatch
{
    public partial class HumanAIIgnoreEnemyAIPatch : IAssemblyPlugin
    {
        public void Initialize() { }

        public void OnLoadCompleted()
        {
            var harmony = new Harmony("HumanAI.IgnoreEnemyAI");
            harmony.PatchAll();
            LuaCsLogger.Log("[HumanAIIgnoreEnemyAIPatch] Loaded! AI will now ignore characters with IgnoredByEnemyAI flag.");
        }

        public void PreInitPatching() { }

        public void Dispose()
        {
            new Harmony("HumanAI.IgnoreEnemyAI").UnpatchSelf();
        }
    }

    [HarmonyPatch]
    public static class Patches
    {
        [HarmonyPatch(typeof(AIObjectiveFightIntruders), nameof(AIObjectiveFightIntruders.IsValidTarget), new Type[] { typeof(Character), typeof(Character), typeof(bool) })]
        [HarmonyPostfix]
        public static void IsValidTargetPostfix(Character target, ref bool __result)
        {
            if (!__result) return;
            if (target.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                __result = false;
            }
        }

        [HarmonyPatch(typeof(HumanAIController), nameof(HumanAIController.RespondToAttack))]
        [HarmonyPrefix]
        public static bool RespondToAttackPrefix(HumanAIController __instance, Character attacker)
        {
            if (attacker != null && attacker.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                return false;
            }
            return true;
        }

        [HarmonyPatch(typeof(HumanAIController), nameof(HumanAIController.AddCombatObjective))]
        [HarmonyPrefix]
        public static bool AddCombatObjectivePrefix(object[] __args)
        {
            if (__args.Length < 2)
            {
                return true;
            }
            Character target = __args[1] as Character;
            if (target != null && target.HasAbilityFlag(AbilityFlags.IgnoredByEnemyAI))
            {
                return false;
            }
            return true;
        }
    }
}
