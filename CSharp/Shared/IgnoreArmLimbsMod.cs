using HarmonyLib;
using Barotrauma;
using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using Microsoft.Xna.Framework;
using System;
using System.Collections.Generic;

namespace Barotrauma
{
    public static class IgnoreArmLimbsPatch
    {
        public const float IgnoreChance = 0.6f;// 60%概率忽略手臂击中躯干
        public static bool DebugMode = false; // 调试模式开关
        
        public static void ApplyPatch()
        {
            var harmony = new Harmony("IgnoreArmLimbsMod");
            harmony.PatchAll();
            // 输出补丁应用成功的消息
            if (DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Patch applied successfully");
        }
        
        // 执行碰撞检测
        public static bool ShouldIgnoreHit(Projectile projectile, Limb limb)
        {
            if (IgnoreChance <= 0f) return false;
            
            // 执行随机判定
            Random random = new Random((int)(Timing.TotalTime * 1000) ^ (projectile?.item?.ID ?? 0) ^ (limb?.character?.ID ?? 0));
            bool result = random.NextDouble() < IgnoreChance;
            // 输出随机判定结果
            if (DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: ShouldIgnoreHit result: {result}");
            return result;
        }
    }
    
    [HarmonyPatch(typeof(Projectile), "OnProjectileCollision")]
    [HarmonyPatch(new Type[] { typeof(Fixture), typeof(Fixture), typeof(Contact) })]
    static class Projectile_OnProjectileCollision_Patch
    {
        static bool Prefix(Projectile __instance, Fixture f1, Fixture target, Contact contact)
        {
            // 输出方法被调用的消息
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: OnProjectileCollision Prefix called");
            
            // 检查网络状态
            bool isServer = GameMain.NetworkMember != null && GameMain.NetworkMember.IsServer;
            bool isSingleplayer = GameMain.IsSingleplayer;
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: IsServer: {isServer}, IsSingleplayer: {isSingleplayer}");
            
            // 在所有模式下都执行碰撞检测，包括客户端
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Inside collision detection condition");
            
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
                {
                    if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: Detected hit on limb type: {limb.type}");
                    // 检查是否是手臂相关的肢体
                    if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand || 
                        limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm || 
                        limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                    {
                        if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: Detected hit on arm for character: {limb.character.Name}");
                        bool shouldIgnore = IgnoreArmLimbsPatch.ShouldIgnoreHit(__instance, limb);
                        if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: Should ignore hit: {shouldIgnore}");
                        if (shouldIgnore)
                        {
                            // 忽略手臂击中，添加到忽略列表
                            if (__instance.IgnoredBodies != null)
                            {
                                if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Adding arm body to ignored list");
                                __instance.IgnoredBodies.Add(target.Body);
                            }
                            else
                            {
                                if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: IgnoredBodies is null");
                                __instance.IgnoredBodies = new List<Body>();
                                __instance.IgnoredBodies.Add(target.Body);
                            }
                            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Returning false to ignore arm hit");
                            return false;
                        }
                        else
                        {
                            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Not ignoring arm hit");
                        }
                    }
                }
            else
            {
                if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Not a human limb hit");
            }
            return true;
        }
    }
    
    [HarmonyPatch(typeof(Projectile), "HandleProjectileCollision")]
    [HarmonyPatch(new Type[] { typeof(Fixture), typeof(Vector2), typeof(Vector2) })]
    static class Projectile_HandleProjectileCollision_Patch
    {
        static bool Prefix(Projectile __instance, Fixture target, Vector2 collisionNormal, Vector2 velocity)
        {
            // 输出方法被调用的消息
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision Prefix called");
            
            // 检查网络状态
            bool isServer = GameMain.NetworkMember != null && GameMain.NetworkMember.IsServer;
            bool isSingleplayer = GameMain.IsSingleplayer;
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: IsServer: {isServer}, IsSingleplayer: {isSingleplayer}");
            
            // 在所有模式下都执行碰撞检测，包括客户端
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - Inside collision detection condition");
            
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
            {
                if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: HandleProjectileCollision - Detected hit on limb type: {limb.type}");
                // 检查是否是手臂相关的肢体
                if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand || 
                    limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm || 
                    limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                {
                    if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: HandleProjectileCollision - Detected hit on arm for character: {limb.character.Name}");
                    bool shouldIgnore = IgnoreArmLimbsPatch.ShouldIgnoreHit(__instance, limb);
                    if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine($"IgnoreArmLimbsMod: HandleProjectileCollision - Should ignore hit: {shouldIgnore}");
                    if (shouldIgnore)
                    {
                        // 忽略手臂击中，添加到忽略列表
                        if (__instance.IgnoredBodies != null)
                        {
                            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - Adding arm body to ignored list");
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        else
                        {
                            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - IgnoredBodies is null");
                            __instance.IgnoredBodies = new List<Body>();
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - Returning false to ignore arm hit");
                        return false;
                    }
                    else
                    {
                        if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - Not ignoring arm hit");
                    }
                }
            }
            else
            {
                if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: HandleProjectileCollision - Not a human limb hit");
            }
            return true;
        }
    }
    
    public class IgnoreArmLimbsMod : ACsMod
    {
        public override void Initialize()
        {
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Initializing mod");
            IgnoreArmLimbsPatch.ApplyPatch();
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Mod initialized");
        }
        
        public override void Stop()
        {
            if (IgnoreArmLimbsPatch.DebugMode) System.Console.WriteLine("IgnoreArmLimbsMod: Stopping mod");
        }
    }
}