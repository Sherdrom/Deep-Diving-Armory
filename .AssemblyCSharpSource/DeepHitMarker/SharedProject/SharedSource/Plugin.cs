using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;

namespace DeepHitMarker
{
    public partial class Plugin : IAssemblyPlugin
    {
        public readonly string Name = "Deep Hit Marker";
        public static float HitHintTimer { get; set; }
        public static float KillHintTimer { get; set; }
        public static int HitHintSize { get; set; } = 10;
        public static int KillHintSize { get; set; } = 30;
        public static Color HitHintColor { get; set; }
        public static int CrosshairDistance { get; set; } = 12;
        public static bool IsHeadshot { get; set; }

        private Harmony? _harmonyInstance;

        public void Initialize()
        {
            LuaCsLogger.Log($"Deep Hit Marker loading...");
            _harmonyInstance = new Harmony("Deep.Hit.Marker.Esirprus");
        }

        public void OnLoadCompleted()
        {
            if (true)
            {
                _harmonyInstance?.PatchAll();

                if (LuaCsSetup.Instance?.Hook is ILuaEventService eventService)
                {
                    eventService.Add("think", "UpdateDeepHitMarker", UpdateDeepHitMarker);
                }

                LuaCsLogger.Log($"Deep Hit Marker loaded!");
            }
            else
            {
                _harmonyInstance = null;
                LuaCsLogger.Log($"Deep Hit Marker has been disabled because other mod contains its function.");
            }
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
            _harmonyInstance?.UnpatchSelf();
            LuaCsLogger.Log("Deep Hit Marker disposed!");
        }

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
                    if (__instance.IsDead)
                    {
                        KillHintTimer = 0.5f;
                    }
                    IsHeadshot = __result.HitLimb != null &&
                                 (__result.HitLimb.Name.ToLower() == "head" ||
                                  __result.HitLimb.Name.ToLower().Contains("head"));
                }
            }

            private static bool IsOutOfScreen(Vector2 position)
            {
                if (Screen.Selected?.Cam == null) { return true; }
                return position.X < Screen.Selected.Cam.WorldView.X
                    || position.X > Screen.Selected.Cam.WorldView.Right
                    || position.Y > Screen.Selected.Cam.WorldView.Y
                    || position.Y < Screen.Selected.Cam.WorldView.Y - Screen.Selected.Cam.WorldView.Height;
            }

            private static bool IsDefaultAttackResult(AttackResult result)
            {
                return result.Damage == 0 && result.Afflictions == null && result.HitLimb == null && result.AppliedDamageModifiers == null;
            }
        }

        public static object[]? UpdateDeepHitMarker(object[]? args)
        {
            HitHintTimer -= (float)Timing.Step;
            HitHintTimer = Math.Max(HitHintTimer, 0);
            KillHintTimer -= (float)Timing.Step;
            KillHintTimer = Math.Max(KillHintTimer, 0);
            return null;
        }

        [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.DrawHUD))]
        static class RangedWeapon_DrawHUD_Patch
        {
            static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
            {
                var codes = new List<CodeInstruction>(instructions);

                for (int i = 0; i < codes.Count; i++)
                {
                    if (codes[i].opcode == OpCodes.Ldfld)
                    {
                        var injectCode = new List<CodeInstruction>
                        {
                            new CodeInstruction(OpCodes.Ldarg_0),
                            new CodeInstruction(OpCodes.Ldarg_1),
                            new CodeInstruction(OpCodes.Call, typeof(Plugin).GetMethod("DrawHint"))
                        };
                        codes.InsertRange(i + 1, injectCode);
                        return codes;
                    }
                }

                var endInjectCode = new List<CodeInstruction>
                {
                    new CodeInstruction(OpCodes.Ldarg_0),
                    new CodeInstruction(OpCodes.Ldarg_1),
                    new CodeInstruction(OpCodes.Call, typeof(Plugin).GetMethod("DrawHint"))
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
            float lineThickness = 4f;

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

            if (KillHintTimer > 0)
            {
                float alpha = KillHintTimer / 0.1f;
                Color killColor = new Color(255, 0, 0, alpha * 255);
                ShapeExtensions.DrawCircle(spriteBatch, position, KillHintSize, 32, killColor, 2f);
            }
        }
    }
}
