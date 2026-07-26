using System;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;

namespace DamageRollbackFix
{
    /// <summary>
    /// 线程静态标志：当前是否处于 Projectile.HandleProjectileCollision 调用链中。
    /// 用于让 Attack.DoDamage/DoDamageToLimb 识别调用来源，仅跳过弹道预测伤害。
    /// </summary>
    internal static class ProjectileCollisionContext
    {
        [ThreadStatic]
        internal static bool IsActive;
    }

    /// <summary>
    /// 本地命中预测标志：区分本地调用 ApplyStatusEffects 和网络事件回调。
    /// 仅在 Postfix 中本地预测命中特效时为 true，防止去重补丁误跳过本地调用。
    /// </summary>
    internal static class ImpactPredictionContext
    {
        [ThreadStatic]
        internal static bool IsLocalPrediction;
    }

    /// <summary>
    /// 每个弹道最近一次本地命中预测时间戳，用于网络事件去重。
    /// ConditionalWeakTable 保证弹道被回收时条目自动清理。
    /// </summary>
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

    /// <summary>
    /// 补丁 1：Projectile.HandleProjectileCollision Prefix/Postfix
    /// - Prefix：设置弹道碰撞上下文标志（供伤害跳过补丁使用）
    /// - Postfix：客户端本地预测命中特效（OnImpact），消除服务器同步延迟；
    ///   记录时间戳供网络事件去重。
    /// </summary>
    [HarmonyPatch(typeof(Projectile), "HandleProjectileCollision")]
    internal static class HandleProjectileCollisionPatch
    {
        [HarmonyPrefix]
        internal static void Prefix()
        {
            ProjectileCollisionContext.IsActive = true;
        }

        [HarmonyPostfix]
        internal static void Postfix(Projectile __instance)
        {
            ProjectileCollisionContext.IsActive = false;

            // 客户端本地预测命中视觉特效（极低延迟反馈）
            // 伤害仍由服务器权威同步，此处仅预测 OnImpact 粒子/贴花等视觉特效
            if (GameMain.NetworkMember is { IsClient: true })
            {
                ImpactTimeTracker.RecordImpact(__instance);
                ImpactPredictionContext.IsLocalPrediction = true;
                __instance.ApplyStatusEffects(ActionType.OnImpact, 1.0f, user: __instance.User);
                ImpactPredictionContext.IsLocalPrediction = false;
            }
        }
    }

    /// <summary>
    /// 补丁 2：ItemComponent.ApplyStatusEffects Prefix
    /// 客户端网络事件回调时，若弹道 OnImpact 特效已由本地预测生成，则跳过以避免双重特效。
    /// 仅影响 Projectile + OnImpact，不影响 RangedWeapon/OnUse（由 WeaponSyncFix 处理）。
    /// </summary>
    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.ApplyStatusEffects))]
    internal static class ApplyStatusEffectsDedupPatch
    {
        private const double DedupWindow = 1.0;

        [HarmonyPrefix]
        internal static bool Prefix(ItemComponent __instance, ActionType type)
        {
            // 本地预测调用，放行
            if (ImpactPredictionContext.IsLocalPrediction) { return true; }
            // 单机/服务器无网络事件去重需求
            if (GameMain.NetworkMember is not { IsClient: true }) { return true; }
            // 仅对弹道 OnImpact 去重
            if (__instance is not Projectile proj) { return true; }
            if (type != ActionType.OnImpact) { return true; }
            // 近期已本地预测：网络事件为重复，跳过
            return ImpactTimeTracker.TimeSinceLastImpact(proj) >= DedupWindow;
        }
    }

    /// <summary>
    /// 补丁 3：Attack.DoDamage Prefix
    /// 客户端在弹道碰撞上下文中跳过伤害应用，避免预测伤害被服务器权威状态覆盖。
    /// 单机模式（NetworkMember == null）和服务器侧不跳过，保持原版行为。
    /// </summary>
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

    /// <summary>
    /// 补丁 4：Attack.DoDamageToLimb Prefix
    /// 同补丁 3，针对肢体伤害（弹道直接命中 Character 的 Limb）。
    /// </summary>
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
