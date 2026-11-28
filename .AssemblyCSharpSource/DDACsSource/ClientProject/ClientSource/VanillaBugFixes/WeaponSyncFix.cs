using System;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using DamageRollbackFix;
using HarmonyLib;

namespace WeaponSyncFix
{
    internal static class NetworkEventContext
    {
        [ThreadStatic]
        internal static bool IsItemEvent;

        [ThreadStatic]
        internal static bool IsProjectileLaunchReplay;
    }

    internal static class PredictedProjectiles
    {
        private static readonly ConditionalWeakTable<Projectile, object> Projectiles = new();

        internal static void Mark(Projectile projectile)
        {
            Projectiles.GetOrCreateValue(projectile);
        }

        internal static bool Consume(Projectile projectile)
        {
            return Projectiles.Remove(projectile);
        }
    }

    [HarmonyPatch(typeof(Projectile), nameof(Projectile.Shoot))]
    internal static class ProjectileShootPatch
    {
        [HarmonyPrefix]
        internal static bool Prefix(Projectile __instance)
        {
            if (!NetworkEventContext.IsProjectileLaunchReplay)
            {
                if (GameMain.NetworkMember is { IsClient: true })
                {
                    PredictedProjectiles.Mark(__instance);
                }
                return true;
            }

            return !PredictedProjectiles.Consume(__instance);
        }

        [HarmonyPostfix]
        internal static void Postfix(Projectile __instance)
        {
            if (NetworkEventContext.IsProjectileLaunchReplay)
            {
                PendingImpactQueue.Resolve(__instance);
            }
        }
    }

    [HarmonyPatch(typeof(Projectile), nameof(Projectile.ClientEventRead))]
    internal static class ProjectileClientEventReadPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(out bool __state)
        {
            __state = NetworkEventContext.IsProjectileLaunchReplay;
            NetworkEventContext.IsProjectileLaunchReplay = true;
        }

        [HarmonyPostfix]
        internal static void Postfix(bool __state)
        {
            NetworkEventContext.IsProjectileLaunchReplay = __state;
        }

        [HarmonyFinalizer]
        internal static Exception Finalizer(Exception __exception, bool __state)
        {
            NetworkEventContext.IsProjectileLaunchReplay = __state;
            return __exception;
        }
    }

    [HarmonyPatch(typeof(Item), nameof(Item.ClientEventRead))]
    internal static class ItemClientEventReadPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(out bool __state)
        {
            __state = NetworkEventContext.IsItemEvent;
            NetworkEventContext.IsItemEvent = true;
        }

        [HarmonyPostfix]
        internal static void Postfix(bool __state)
        {
            NetworkEventContext.IsItemEvent = __state;
        }

        [HarmonyFinalizer]
        internal static Exception Finalizer(Exception __exception, bool __state)
        {
            NetworkEventContext.IsItemEvent = __state;
            return __exception;
        }
    }

    [HarmonyPatch(typeof(Projectile), "Launch")]
    internal static class ProjectileLaunchPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(Projectile __instance)
        {
            if (!NetworkEventContext.IsProjectileLaunchReplay) { return; }

            var body = __instance.Item.body;
            if (body != null)
            {
                body.Dir = 1;
            }
        }
    }
}
