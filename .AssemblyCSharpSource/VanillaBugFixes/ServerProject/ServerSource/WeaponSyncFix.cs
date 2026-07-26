using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;

namespace WeaponSyncFix
{
    [HarmonyPatch(typeof(Projectile), nameof(Projectile.Shoot))]
    internal static class ProjectileShootPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(ref bool createNetworkEvent)
        {
            if (GameMain.NetworkMember is { IsServer: true })
            {
                createNetworkEvent = true;
            }
        }
    }

    [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.Use))]
    internal static class RangedWeaponUsePatch
    {
        [HarmonyPostfix]
        internal static void Postfix(RangedWeapon __instance, bool __result, Character character)
        {
            if (!__result || character == null) { return; }
            if (GameMain.NetworkMember is not { IsServer: true } networkMember) { return; }

            networkMember.CreateEntityEvent(
                __instance.Item,
                new Item.ApplyStatusEffectEventData(ActionType.OnUse, __instance, character));
        }
    }
}
