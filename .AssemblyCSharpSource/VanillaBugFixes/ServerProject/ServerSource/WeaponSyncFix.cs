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

    [HarmonyPatch]
    internal static class RangedWeaponUsePatch
    {
        [HarmonyTargetMethods]
        private static IEnumerable<MethodBase> TargetMethods()
        {
            foreach (var type in AccessTools.AllTypes())
            {
                if (!typeof(RangedWeapon).IsAssignableFrom(type)) { continue; }

                var method = AccessTools.DeclaredMethod(type, nameof(RangedWeapon.Use),
                    new[] { typeof(float), typeof(Character) });
                if (method == null || method.IsAbstract) { continue; }

                yield return method;
            }
        }

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
