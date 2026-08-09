using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;
using Microsoft.Xna.Framework;
using WeaponSyncFix;

namespace DamageRollbackFix
{
    internal static class ProjectileCollisionContext
    {
        [ThreadStatic]
        internal static bool IsActive;
    }

    internal static class ImpactPredictionContext
    {
        [ThreadStatic]
        internal static bool IsLocalPrediction;

        [ThreadStatic]
        internal static bool IsQueuedNetworkReplay;
    }

    internal static class ImpactTimeTracker
    {
        private static readonly ConditionalWeakTable<Projectile, StrongBox<double>> LastImpactTimes = new();

        internal static void RecordImpact(Projectile projectile)
        {
            LastImpactTimes.GetOrCreateValue(projectile).Value = Timing.TotalTime;
        }

        internal static double TimeSinceLastImpact(Projectile projectile)
        {
            return LastImpactTimes.TryGetValue(projectile, out var box)
                ? Timing.TotalTime - box.Value
                : double.MaxValue;
        }
    }

    [HarmonyPatch(typeof(Projectile), "HandleProjectileCollision")]
    internal static class HandleProjectileCollisionPatch
    {
        [HarmonyPrefix]
        internal static void Prefix()
        {
            ProjectileCollisionContext.IsActive = true;
        }

        [HarmonyPostfix]
        internal static void Postfix(Projectile __instance, bool __result)
        {
            ProjectileCollisionContext.IsActive = false;
            if (!__result || NetworkEventContext.IsProjectileLaunchReplay) { return; }
            if (GameMain.NetworkMember is not { IsClient: true }) { return; }

            ImpactTimeTracker.RecordImpact(__instance);
            bool previousPrediction = ImpactPredictionContext.IsLocalPrediction;
            ImpactPredictionContext.IsLocalPrediction = true;
            try
            {
                __instance.ApplyStatusEffects(ActionType.OnImpact, 1.0f, user: __instance.User);
            }
            finally
            {
                ImpactPredictionContext.IsLocalPrediction = previousPrediction;
            }
        }
    }

    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.ApplyStatusEffects))]
    internal static class ApplyStatusEffectsDedupPatch
    {
        internal const double DedupWindow = 1.0;

        [HarmonyPrefix]
        internal static bool Prefix(
            ItemComponent __instance,
            ActionType type,
            float deltaTime,
            Character character,
            Limb targetLimb,
            Entity useTarget,
            Character user,
            Vector2? worldPosition,
            float attackMultiplier)
        {
            if (ImpactPredictionContext.IsLocalPrediction || ImpactPredictionContext.IsQueuedNetworkReplay)
            {
                return true;
            }
            if (GameMain.NetworkMember is not { IsClient: true }) { return true; }
            if (__instance is not Projectile proj || type != ActionType.OnImpact) { return true; }
            if (!NetworkEventContext.IsItemEvent) { return true; }

            if (ImpactTimeTracker.TimeSinceLastImpact(proj) < DedupWindow)
            {
                return false;
            }

            if (!proj.Hitscan) { return true; }

            PendingImpactQueue.Enqueue(proj, () => proj.ApplyStatusEffects(
                type,
                deltaTime,
                character,
                targetLimb,
                useTarget,
                user,
                worldPosition,
                attackMultiplier));
            return false;
        }
    }

    internal static class PendingImpactQueue
    {
        // ponytail: one projectile key plus a short timeout; add shot IDs only if event order proves insufficient.
        private const double Timeout = 0.1;
        private static readonly Queue<(Projectile Projectile, Action Apply, double EnqueuedAt)> Queue = new();

        internal static void Enqueue(Projectile projectile, Action apply)
        {
            Queue.Enqueue((projectile, apply, Timing.TotalTime));
        }

        internal static void Resolve(Projectile projectile)
        {
            int count = Queue.Count;
            while (count-- > 0)
            {
                var pending = Queue.Dequeue();
                if (pending.Projectile != projectile)
                {
                    Queue.Enqueue(pending);
                    continue;
                }

                ApplyIfNeeded(pending);
            }
        }

        internal static void FlushExpired()
        {
            int count = Queue.Count;
            double now = Timing.TotalTime;
            while (count-- > 0)
            {
                var pending = Queue.Dequeue();
                if (now - pending.EnqueuedAt < Timeout)
                {
                    Queue.Enqueue(pending);
                    continue;
                }

                ApplyIfNeeded(pending);
            }
        }

        private static void ApplyIfNeeded((Projectile Projectile, Action Apply, double EnqueuedAt) pending)
        {
            if (ImpactTimeTracker.TimeSinceLastImpact(pending.Projectile) < ApplyStatusEffectsDedupPatch.DedupWindow)
            {
                return;
            }

            bool previousReplay = ImpactPredictionContext.IsQueuedNetworkReplay;
            ImpactPredictionContext.IsQueuedNetworkReplay = true;
            try
            {
                pending.Apply();
            }
            finally
            {
                ImpactPredictionContext.IsQueuedNetworkReplay = previousReplay;
            }
        }
    }

    [HarmonyPatch(typeof(Character), nameof(Character.UpdateAll))]
    internal static class CharacterUpdateAllPatch
    {
        [HarmonyPostfix]
        internal static void Postfix()
        {
            PendingImpactQueue.FlushExpired();
        }
    }

    [HarmonyPatch(typeof(Attack), nameof(Attack.DoDamage))]
    internal static class AttackDoDamagePatch
    {
        [HarmonyPrefix]
        internal static bool Prefix(ref AttackResult __result)
        {
            if (GameMain.NetworkMember is { IsClient: true } && ProjectileCollisionContext.IsActive)
            {
                __result = new AttackResult();
                return false;
            }
            return true;
        }
    }

    [HarmonyPatch(typeof(Attack), nameof(Attack.DoDamageToLimb))]
    internal static class AttackDoDamageToLimbPatch
    {
        [HarmonyPrefix]
        internal static bool Prefix(ref AttackResult __result)
        {
            if (GameMain.NetworkMember is { IsClient: true } && ProjectileCollisionContext.IsActive)
            {
                __result = new AttackResult();
                return false;
            }
            return true;
        }
    }
}
