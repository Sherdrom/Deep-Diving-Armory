using Barotrauma;
using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using HarmonyLib;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;
using System.Reflection.Emit;
using Color = Microsoft.Xna.Framework.Color;

namespace DeepHitMarker
{
    public class DeepHitMarker : IAssemblyPlugin
    {
        public readonly string Name = "Deep Hit Marker";
        public static float HitHintTimer { get; set; }
        public static int HitHintSize { get; set; } = 10;
        public static Color HitHintColor { get; set; }
        public static int CrosshairDistance { get; set; } = 12; // 从10改为20，让线条离中心更远
        public static bool IsHeadshot { get; set; }

        public Harmony? harmonyInstance;

        public void Initialize()
        {
            LuaCsLogger.Log($"Deep Hit Marker loading...");
            harmonyInstance = new Harmony("Deep.Hit.Marker.Esirprus");
        }
        public void Dispose()
        {
            harmonyInstance?.UnpatchSelf();
            LuaCsLogger.Log("Deep Hit Marker disposed!");
        }

        public void OnLoadCompleted()
        {
            if (true)
            {
                harmonyInstance.PatchAll();
                GameMain.LuaCs.Hook.Add("think", "UpdateDeepHitMarker", UpdateDeepHitMarker);
                LuaCsLogger.Log($"Deep Hit Marker loaded!");
            }
            else
            {
                harmonyInstance = null;
                LuaCsLogger.Log($"Deep Hit Marker has been disabled because other mod contains its function.");
            }
        }

        public void PreInitPatching()
        {
        }

        //patch ApplyAttack
        [HarmonyPatch(typeof(Character), nameof(Character.ApplyAttack))]
        public static class ApplyAttackPatch
        {
            public static void Postfix(Character __instance, Character attacker, AttackResult __result)
            {
                if (__instance == null || attacker == null || IsDefaultAttackResult(__result)) { return; }
                if (attacker == Character.Controlled)
                {
#if DEBUG
                    string limbName = __result.HitLimb != null ? __result.HitLimb.Name : "null";
                    LuaCsLogger.Log($"{attacker.Name} attacked {__instance.Name}, limb: {limbName}");
#endif
                    if (IsOutOfScreen(__instance.WorldPosition)) { return; }
                    HitHintTimer = 0.25f;
                    // 使用不区分大小写的比较，并检查多种可能的头部名称
                    IsHeadshot = __result.HitLimb != null && 
                                 (__result.HitLimb.Name.ToLower() == "head" || 
                                  __result.HitLimb.Name.ToLower().Contains("head"));
                }
            }
            private static bool IsOutOfScreen(Vector2 position)
            {
                if (Screen.Selected?.Cam == null) { return true; }
                bool result = position.X < Screen.Selected.Cam.WorldView.X
                              || position.X > Screen.Selected.Cam.WorldView.Right
                              || position.Y > Screen.Selected.Cam.WorldView.Y
                              || position.Y < Screen.Selected.Cam.WorldView.Y - Screen.Selected.Cam.WorldView.Height;
                return result;
            }
            private static bool IsDefaultAttackResult(AttackResult result)
            {
                return result.Damage == 0 && result.Afflictions == null && result.HitLimb == null && result.AppliedDamageModifiers == null;
            }
        }
        //dont use this it will cause game crash on subeditor
        ////patch UpdateHUDComponentSpecific
        //[HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.UpdateHUDComponentSpecific))]
        //public static class UpdateHUDComponentSpecificPatch
        //{
        //    public static void Postfix(float deltaTime)
        //    {
        //        HitHintTimer -= deltaTime;
        //        HitHintTimer = Math.Max(HitHintTimer, 0);
        //    }
        //}

        public static object[]? UpdateDeepHitMarker(object[]? args)
        {
            HitHintTimer -= (float)Timing.Step;
            HitHintTimer = Math.Max(HitHintTimer, 0);
            return null;
        }

        //patch DrawHUD
        [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.DrawHUD))]
        static class RangedWeapon_DrawHUD_Patch
        {
            // 替换 RangedWeapon_DrawHUD_Patch 类中的 Transpiler 方法
static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
{
    var codes = new List<CodeInstruction>(instructions);
    
    // 尝试找到任何 Ldfld 指令，作为备选插入点
    for (int i = 0; i < codes.Count; i++)
    {
        // 找到第一个 Ldfld 指令作为插入点
        if (codes[i].opcode == OpCodes.Ldfld)
        {
            var injectCode = new List<CodeInstruction>
            {
                new CodeInstruction(OpCodes.Ldarg_0),      // this (RangedWeapon)
                new CodeInstruction(OpCodes.Ldarg_1),      // spriteBatch
                new CodeInstruction(OpCodes.Call, typeof(DeepHitMarker).GetMethod("DrawHint"))
            };

            codes.InsertRange(i + 1, injectCode);
            return codes;
        }
    }
    
    // 如果找不到任何插入点，就直接在方法末尾添加
    var endInjectCode = new List<CodeInstruction>
    {
        new CodeInstruction(OpCodes.Ldarg_0),      // this (RangedWeapon)
        new CodeInstruction(OpCodes.Ldarg_1),      // spriteBatch
        new CodeInstruction(OpCodes.Call, typeof(DeepHitMarker).GetMethod("DrawHint"))
    };
    
    codes.AddRange(endInjectCode);
    return codes;
}

        }
        public static void DrawHint(RangedWeapon rangedWeapon, SpriteBatch spriteBatch)
        {
            var position = rangedWeapon.crosshairPos;
            Color color = IsHeadshot ? Color.Red : Color.White;
            HitHintColor = new Color(color.R, color.G, color.B, HitHintTimer > 0 ? 255 : 0);
            float lineThickness = 4f; // 线条粗细
            ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X + CrosshairDistance, position.Y + CrosshairDistance),
                                     new Vector2(position.X + CrosshairDistance + HitHintSize, position.Y + CrosshairDistance + HitHintSize),
                                     HitHintColor, lineThickness);
            ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X - CrosshairDistance, position.Y + CrosshairDistance),
                                     new Vector2(position.X - CrosshairDistance - HitHintSize, position.Y + CrosshairDistance + HitHintSize),
                                     HitHintColor, lineThickness);
            ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X + CrosshairDistance, position.Y - CrosshairDistance),
                                     new Vector2(position.X + CrosshairDistance + HitHintSize, position.Y - CrosshairDistance - HitHintSize),
                                     HitHintColor, lineThickness);
            ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X - CrosshairDistance, position.Y - CrosshairDistance),
                                     new Vector2(position.X - CrosshairDistance - HitHintSize, position.Y - CrosshairDistance - HitHintSize),
                                     HitHintColor, lineThickness);
        }
    }

}
