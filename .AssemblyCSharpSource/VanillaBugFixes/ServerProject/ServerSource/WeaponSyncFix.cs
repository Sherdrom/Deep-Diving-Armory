using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;

namespace WeaponSyncFix
{
    [HarmonyPatch(typeof(Projectile), nameof(Projectile.Shoot))]
    internal static class ProjectileShootPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(Projectile __instance, ref bool createNetworkEvent)
        {
            if (__instance.Hitscan && GameMain.NetworkMember is { IsServer: true })
            {
                createNetworkEvent = true;
            }
        }
    }
}
