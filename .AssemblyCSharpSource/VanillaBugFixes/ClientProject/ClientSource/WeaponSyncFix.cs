using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using Barotrauma.Networking;
using DamageRollbackFix;
using HarmonyLib;
using Microsoft.Xna.Framework;

namespace WeaponSyncFix
{
    internal static class NetworkEventContext
    {
        [ThreadStatic]
        internal static bool IsItemEvent;

        [ThreadStatic]
        internal static bool IsProjectileLaunchReplay;
    }

    internal static class FireTimeTracker
    {
        private static readonly ConditionalWeakTable<RangedWeapon, StrongBox<double>> LastFireTimes = new();

        internal static void RecordFire(RangedWeapon weapon)
        {
            LastFireTimes.GetOrCreateValue(weapon).Value = Timing.TotalTime;
        }

        internal static double TimeSinceLastFire(RangedWeapon weapon)
        {
            return LastFireTimes.TryGetValue(weapon, out var box)
                ? Timing.TotalTime - box.Value
                : double.MaxValue;
        }
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
        internal static void Postfix(RangedWeapon __instance, bool __result)
        {
            if (__result && !NetworkEventContext.IsItemEvent)
            {
                FireTimeTracker.RecordFire(__instance);
            }
        }
    }

    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.ApplyStatusEffects))]
    internal static class ApplyStatusEffectsPatch
    {
        private const double DedupWindow = 1.0;

        private static readonly MethodInfo PlaySoundMethod =
            AccessTools.Method(typeof(ItemComponent), "PlaySound",
                new[] { typeof(ActionType), typeof(Character) });

        [HarmonyPrefix]
        internal static bool Prefix(ItemComponent __instance, ActionType type)
        {
            if (!NetworkEventContext.IsItemEvent || __instance is not RangedWeapon || type != ActionType.OnUse)
            {
                return true;
            }

            var weapon = (RangedWeapon)__instance;
            return FireTimeTracker.TimeSinceLastFire(weapon) >= DedupWindow;
        }

        [HarmonyPostfix]
        internal static void Postfix(ItemComponent __instance, ActionType type, Character character)
        {
            if (!NetworkEventContext.IsItemEvent || __instance is not RangedWeapon rw || type != ActionType.OnUse)
            {
                return;
            }
            if (FireTimeTracker.TimeSinceLastFire(rw) < DedupWindow) { return; }

            PlaySoundMethod?.Invoke(rw, new object[] { ActionType.OnUse, character });
            AccessTools.Method(rw.GetType(), "LaunchProjSpecific")?.Invoke(rw, null);

            var body = rw.Item.body;
            if (body == null) { return; }

            float rotation = body.Rotation;
            if (body.Dir < 0f) { rotation += MathHelper.Pi; }
            body.ApplyLinearImpulse(
                new Vector2((float)Math.Cos(rotation), (float)Math.Sin(rotation)) * body.Mass * -50.0f,
                maxVelocity: NetConfig.MaxPhysicsBodyVelocity);
        }
    }
}
