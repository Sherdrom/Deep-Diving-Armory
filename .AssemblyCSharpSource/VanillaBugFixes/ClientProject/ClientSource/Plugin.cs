using HarmonyLib;
using WeaponSyncFix;

namespace VanillaBugFixes
{
    public sealed partial class Plugin
    {
        partial void PatchPlatformSpecific(Harmony harmony)
        {
            var clientEventRead = AccessTools.Method(typeof(Item), "ClientEventRead");
            if (clientEventRead == null) { return; }

            harmony.Patch(
                clientEventRead,
                prefix: new HarmonyMethod(typeof(ItemClientEventReadPatch), nameof(ItemClientEventReadPatch.Prefix)),
                postfix: new HarmonyMethod(typeof(ItemClientEventReadPatch), nameof(ItemClientEventReadPatch.Postfix)));
        }

        partial void PreInitPatchingProjSpecific()
        {
            harmony ??= new Harmony(HarmonyId);

            var performanceEnhancementType = AccessTools.TypeByName("PerformanceEnhancement.PerformanceEnhancementPlugin");
            var characterUpdatePrefix = performanceEnhancementType == null
                ? null
                : AccessTools.Method(performanceEnhancementType, "CharacterUpdatePrefix");
            if (characterUpdatePrefix != null)
            {
                harmony.Patch(
                    characterUpdatePrefix,
                    postfix: new HarmonyMethod(
                        typeof(PerformanceEnhancementCharacterUpdatePrefixPatch),
                        nameof(PerformanceEnhancementCharacterUpdatePrefixPatch.Postfix)));
            }
        }
    }

    internal static class PerformanceEnhancementCharacterUpdatePrefixPatch
    {
        // Spectators have no Controlled character, so Performance Enhancement rejects every remote update.
        internal static void Postfix(ref bool __result)
        {
            if (GameMain.NetworkMember is { IsClient: true } && Character.Controlled == null)
            {
                __result = true;
            }
        }
    }
}
