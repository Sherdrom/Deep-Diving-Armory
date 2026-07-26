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
    }
}
