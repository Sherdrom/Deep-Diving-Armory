using HarmonyLib;
namespace VanillaBugFixes
{
    public sealed partial class Plugin
    {
        partial void PreInitPatchingProjSpecific()
        {
            harmony ??= new Harmony(HarmonyId);

            var performanceEnhancementType = AccessTools.TypeByName("PerformanceEnhancement.PerformanceEnhancementRuntime");
            var shouldUpdateCharacter = performanceEnhancementType == null
                ? null
                : AccessTools.Method(
                    performanceEnhancementType,
                    "ShouldUpdateCharacter",
                    new[] { typeof(Character), typeof(Camera) });
            if (shouldUpdateCharacter != null)
            {
                harmony.Patch(
                    shouldUpdateCharacter,
                    postfix: new HarmonyMethod(
                        typeof(PerformanceEnhancementShouldUpdateCharacterPatch),
                        nameof(PerformanceEnhancementShouldUpdateCharacterPatch.Postfix)));
            }
        }
    }

    internal static class PerformanceEnhancementShouldUpdateCharacterPatch
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
