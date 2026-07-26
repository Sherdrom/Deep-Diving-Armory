using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using Barotrauma.LuaCs;
using Barotrauma.Networking;
using Microsoft.Xna.Framework;
using HarmonyLib;

[assembly: IgnoreAccessChecksTo("Barotrauma")]
[assembly: IgnoreAccessChecksTo("BarotraumaCore")]
[assembly: IgnoreAccessChecksTo("DedicatedServer")]

// 兼容性定义：部分 LuaCs 编译环境缺少此特性，显式声明以支持访问 internal 成员
namespace System.Runtime.CompilerServices
{
    [AttributeUsage(AttributeTargets.Assembly, AllowMultiple = true)]
    internal sealed class IgnoreAccessChecksToAttribute : Attribute
    {
        public IgnoreAccessChecksToAttribute(string assemblyName) { }
    }
}

namespace WeaponSyncFix
{
    /// <summary>
    /// 插件入口：加载时 PatchAll，卸载时 UnpatchAll。
    /// </summary>
    public class WeaponSyncPlugin : IAssemblyPlugin
    {
        private const string HarmonyId = "weaponsync.fix";
        private Harmony _harmony;

        public void Initialize()
        {
            _harmony = new Harmony(HarmonyId);
            _harmony.PatchAll();
            // ClientEventRead 为客户端专属方法，服务器不存在，需手动检查后补丁
            var clientEventRead = AccessTools.Method(typeof(Item), "ClientEventRead");
            if (clientEventRead != null)
            {
                _harmony.Patch(
                    clientEventRead,
                    prefix: new HarmonyMethod(typeof(ItemClientEventReadPatch), nameof(ItemClientEventReadPatch.Prefix)),
                    postfix: new HarmonyMethod(typeof(ItemClientEventReadPatch), nameof(ItemClientEventReadPatch.Postfix)));
            }
            LuaCsLogger.Log("[WeaponSyncFix] Loaded v3.1 | dedup=0.2s | projectileSync=on | tracerDirFix=on");
        }

        public void OnLoadCompleted() { }

        public void PreInitPatching() { }

        public void Dispose()
        {
            _harmony?.UnpatchAll(HarmonyId);
            LuaCsLogger.Log("[WeaponSyncFix] Unloaded");
            _harmony = null;
        }
    }

    /// <summary>
    /// 每把武器最近一次本地开火时间戳，用于网络事件去重。
    /// ConditionalWeakTable 保证武器被回收时条目自动清理。
    /// </summary>
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

    /// <summary>
    /// 线程静态标志：当前是否处于 ClientEventRead 处理流程中。
    /// 用于区分 ApplyStatusEffects 是本地调用还是网络事件回调。
    /// </summary>
    internal static class NetworkEventContext
    {
        [ThreadStatic]
        internal static bool IsProcessing;
    }

    /// <summary>
    /// 补丁 1：Projectile.Shoot Prefix（核心修复）
    ///
    /// 根因：RangedWeapon.Use() 和 SwitchableRangedWeapon.Use() 均以 createNetworkEvent=false
    /// 调用 projectile.Shoot()，导致服务器从不发送子弹发射事件给客户端。
    /// 客户端因此从不执行 DoHitscan -> LaunchProjSpecific，tracer 完全缺失。
    ///
    /// 修复：服务器侧强制 createNetworkEvent=true，使客户端收到发射事件后
    /// 走 Shoot -> Launch -> Use -> DoHitscan -> LaunchProjSpecific 完整链路生成 tracer。
    ///
    /// 安全性：Shoot 内部仅当 GameMain.NetworkMember.IsServer 为 true 时创建事件，
    /// 客户端侧不会触发递归。StatusEffect.cs 原本即传 true，无行为变化。
    /// </summary>
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

    /// <summary>
    /// 补丁 2：Projectile.Launch Prefix（tracer方向修正）
    ///
    /// 根因：服务器 RangedWeapon.Use 第288行 rotation = Item.body.Rotation - Pi（Dir<0时），
    /// 传给客户端的 rotation 已包含 Dir 调整。客户端 Launch 设置 item.body.Rotation = rotation，
    /// 但 Use 第466行 if (item.body.Dir < 0 && item.ParentInventory is not ItemInventory) 会再次减 Pi，
    /// 导致双重调整，tracer 方向反向（枪口前后都出现枪线）。
    ///
    /// 偶发原因：库存同步事件先于发射事件到达时，item.ParentInventory 已为 null（非 ItemInventory），
    /// 条件成立触发双重调整。
    ///
    /// 修复：网络事件上下文中设置 item.body.Dir = 1，避免 Use 中的双重调整。
    /// 服务器传来的 rotation 已包含 Dir 调整，Dir 设为 1 不会再次调整。
    /// </summary>
    [HarmonyPatch(typeof(Projectile), "Launch")]
    internal static class ProjectileLaunchPatch
    {
        [HarmonyPrefix]
        internal static void Prefix(Projectile __instance)
        {
            if (!NetworkEventContext.IsProcessing) { return; }
            var body = __instance.Item.body;
            if (body != null)
            {
                body.Dir = 1;
            }
        }
    }

    /// <summary>
    /// 补丁 3：RangedWeapon.Use() Postfix
    /// - 记录本地开火时间戳（用于去重）
    /// - 服务器侧广播 ApplyStatusEffectEventData(OnUse) 到所有客户端
    ///   补充武器组件自身的 OnUse 状态效果（原版 Item.Use 不创建此事件）
    /// </summary>
    [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.Use))]
    internal static class RangedWeaponUsePatch
    {
        [HarmonyPostfix]
        internal static void Postfix(RangedWeapon __instance, bool __result, Character character)
        {
            if (!__result) { return; }
            FireTimeTracker.RecordFire(__instance);
            if (GameMain.NetworkMember is { IsServer: true } && character != null)
            {
                GameMain.NetworkMember.CreateEntityEvent(
                    __instance.Item,
                    new Item.ApplyStatusEffectEventData(ActionType.OnUse, __instance, character));
            }
        }
    }

    /// <summary>
    /// 补丁 3：Item.ClientEventRead Prefix/Postfix
    /// 设置网络事件处理标志，供 ApplyStatusEffects 补丁区分调用来源。
    /// 无 [HarmonyPatch] 特性：客户端专属方法需手动补丁，避免服务器 PatchAll 异常。
    /// </summary>
    internal static class ItemClientEventReadPatch
    {
        [HarmonyPrefix]
        internal static void Prefix()
        {
            NetworkEventContext.IsProcessing = true;
        }

        [HarmonyPostfix]
        internal static void Postfix()
        {
            NetworkEventContext.IsProcessing = false;
        }
    }

    /// <summary>
    /// 补丁 4：ItemComponent.ApplyStatusEffects Prefix + Postfix
    /// - Prefix：网络事件触发时，若本地近期已开火则跳过（去重，防双重特效）
    /// - Postfix：远程开火时补放枪声、枪口闪光粒子、后坐力
    ///
    /// 原版 Item.Use() 仅对本地玩家调用 ic.PlaySound(OnUse) 和 RangedWeapon.LaunchProjSpecific()，
    /// 远程玩家/AI 开火时客户端从不执行这些方法，导致枪声和枪口闪光缺失。
    /// </summary>
    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.ApplyStatusEffects))]
    internal static class ApplyStatusEffectsPatch
    {
        private const double DedupWindow = 0.2;

        // 反射缓存：PlaySound 为客户端 partial 方法，服务器侧不存在（返回 null，安全跳过）
        private static readonly MethodInfo PlaySoundMethod =
            AccessTools.Method(typeof(ItemComponent), "PlaySound",
                new[] { typeof(ActionType), typeof(Character) });

        // 反射缓存：LaunchProjSpecific 为 RangedWeapon 的 private partial 方法
        private static readonly MethodInfo LaunchProjSpecificMethod =
            AccessTools.Method(typeof(RangedWeapon), "LaunchProjSpecific");

        [HarmonyPrefix]
        internal static bool Prefix(ItemComponent __instance, ActionType type)
        {
            if (!NetworkEventContext.IsProcessing) { return true; }
            if (GameMain.NetworkMember is { IsServer: true }) { return true; }
            if (__instance is not RangedWeapon rw) { return true; }
            if (type != ActionType.OnUse) { return true; }
            // 本地近期已开火：网络事件为重复，跳过以避免双重特效
            return FireTimeTracker.TimeSinceLastFire(rw) >= DedupWindow;
        }

        [HarmonyPostfix]
        internal static void Postfix(ItemComponent __instance, ActionType type, Character character)
        {
            if (!NetworkEventContext.IsProcessing) { return; }
            if (GameMain.NetworkMember is { IsServer: true }) { return; }
            if (__instance is not RangedWeapon rw) { return; }
            if (type != ActionType.OnUse) { return; }
            if (FireTimeTracker.TimeSinceLastFire(rw) < DedupWindow) { return; }

            // 远程开火补偿：补放原版仅本地玩家才执行的特效
            // 1. 枪声（原版 Item.Use 第3393行 ic.PlaySound(OnUse, user)）
            PlaySoundMethod?.Invoke(rw, new object[] { ActionType.OnUse, character });

            // 2. 枪口闪光粒子（原版 RangedWeapon.Use 第341行 LaunchProjSpecific()）
            LaunchProjSpecificMethod?.Invoke(rw, null);

            // 3. 后坐力冲量（原版 RangedWeapon.Use 第332行 ApplyLinearImpulse 系数 -50.0f）
            var body = rw.Item.body;
            if (body == null) { return; }
            float rot = body.Rotation;
            if (body.Dir < 0f) { rot += MathHelper.Pi; }
            body.ApplyLinearImpulse(
                new Vector2((float)Math.Cos(rot), (float)Math.Sin(rot)) * body.Mass * -50.0f,
                maxVelocity: NetConfig.MaxPhysicsBodyVelocity);
        }
    }
}
