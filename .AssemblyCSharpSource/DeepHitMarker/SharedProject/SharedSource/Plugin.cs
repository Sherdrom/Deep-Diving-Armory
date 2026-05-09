using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;

namespace DeepHitMarker
{
    public partial class DeepHitMarker : IAssemblyPlugin
    {
        public static float HitHintTimer { get; set; }
        public static float KillHintTimer { get; set; }
        public static int HitHintSize { get; set; } = 10;
        public static int KillHintSize { get; set; } = 30;
        public static Color HitHintColor { get; private set; }
        public static int CrosshairDistance { get; set; } = 12;
        public static bool IsHeadshot { get; set; }
        
        private Harmony? _harmonyInstance;

        public readonly string Name = "Deep Hit Marker";

        public void Initialize()
        {
            try
            {
                LuaCsLogger.Log($"[DeepHitMarker] Loading...");
                _harmonyInstance = new Harmony("Deep.Hit.Marker.Esirpus");
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[DeepHitMarker] Error during initialization: {ex.Message}");
                _harmonyInstance = null;
            }
        }

        public void OnLoadCompleted()
        {
            try
            {
                if (_harmonyInstance == null)
                {
                    LuaCsLogger.Log($"[DeepHitMarker] Cannot load: not properly initialized");
                    return;
                }

                _harmonyInstance.PatchAll();

                if (LuaCsSetup.Instance?.Hook is ILuaEventService eventService)
                {
                    eventService.Add("think", "UpdateDeepHitMarker", UpdateDeepHitMarker);
                }

                LuaCsLogger.Log($"[DeepHitMarker] Loaded successfully!");
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[DeepHitMarker] Error during loading: {ex.Message}");
            }
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
            try
            {
                if (LuaCsSetup.Instance?.Hook is ILuaEventService eventService)
                {
                    eventService.Remove("think", "UpdateDeepHitMarker");
                }
                
                _harmonyInstance?.UnpatchSelf();
                _harmonyInstance = null;
                LuaCsLogger.Log("[DeepHitMarker] Disposed successfully!");
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[DeepHitMarker] Error during disposal: {ex.Message}");
            }
        }

        [HarmonyPatch(typeof(Character), nameof(Character.ApplyAttack))]
        public static class ApplyAttackPatch
        {
            public static void Postfix(Character __instance, Character attacker, AttackResult __result)
            {
                try
                {
                    if (__instance == null || attacker == null) { return; }
                    if (IsDefaultAttackResult(__result)) { return; }
                    if (attacker != Character.Controlled) { return; }
                    
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
                catch (Exception ex)
                {
                    LuaCsLogger.Log($"[DeepHitMarker] Error in ApplyAttack patch: {ex.Message}");
                }
            }

            private static bool IsOutOfScreen(Vector2 position)
            {
                try
                {
                    if (Screen.Selected?.Cam == null) { return true; }
                    return position.X < Screen.Selected.Cam.WorldView.X
                        || position.X > Screen.Selected.Cam.WorldView.Right
                        || position.Y > Screen.Selected.Cam.WorldView.Y
                        || position.Y < Screen.Selected.Cam.WorldView.Y - Screen.Selected.Cam.WorldView.Height;
                }
                catch
                {
                    return true;
                }
            }

            private static bool IsDefaultAttackResult(AttackResult result)
            {
                return result.Damage == 0 && result.Afflictions == null && result.HitLimb == null && result.AppliedDamageModifiers == null;
            }
        }

        public static object[]? UpdateDeepHitMarker(object[]? args)
        {
            try
            {
                if (HitHintTimer > 0)
                {
                    HitHintTimer = Math.Max(HitHintTimer - (float)Timing.Step, 0f);
                }
                
                if (KillHintTimer > 0)
                {
                    KillHintTimer = Math.Max(KillHintTimer - (float)Timing.Step, 0f);
                }
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[DeepHitMarker] Error in update: {ex.Message}");
            }
            
            return null;
        }

        [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.DrawHUD))]
        static class RangedWeapon_DrawHUD_Patch
        {
            static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
            {
                try
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
                                new CodeInstruction(OpCodes.Call, typeof(DeepHitMarker).GetMethod(nameof(DrawHint)))
                            };
                            codes.InsertRange(i + 1, injectCode);
                            return codes;
                        }
                    }

                    var endInjectCode = new List<CodeInstruction>
                    {
                        new CodeInstruction(OpCodes.Ldarg_0),
                        new CodeInstruction(OpCodes.Ldarg_1),
                        new CodeInstruction(OpCodes.Call, typeof(DeepHitMarker).GetMethod(nameof(DrawHint)))
                    };
                    codes.AddRange(endInjectCode);
                    return codes;
                }
                catch (Exception ex)
                {
                    LuaCsLogger.Log($"[DeepHitMarker] Error in DrawHUD transpiler: {ex.Message}");
                    return instructions;
                }
            }
        }

        public static void DrawHint(RangedWeapon rangedWeapon, SpriteBatch spriteBatch)
        {
            try
            {
                if (rangedWeapon == null || spriteBatch == null) { return; }
                
                var position = rangedWeapon.crosshairPos;
                
                if (HitHintTimer <= 0 && KillHintTimer <= 0) { return; }
                
                Color color = IsHeadshot ? Color.Red : Color.White;
                HitHintColor = new Color(color.R, color.G, color.B, HitHintTimer > 0 ? (byte)255 : (byte)0);
                
                int size = Math.Max(HitHintSize, 1);
                int distance = Math.Max(CrosshairDistance, 0);
                
                ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X + distance, position.Y + distance),
                                     new Vector2(position.X + distance + size, position.Y + distance + size),
                                     HitHintColor, 4f);
                ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X - distance, position.Y + distance),
                                     new Vector2(position.X - distance - size, position.Y + distance + size),
                                     HitHintColor, 4f);
                ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X + distance, position.Y - distance),
                                     new Vector2(position.X + distance + size, position.Y - distance - size),
                                     HitHintColor, 4f);
                ShapeExtensions.DrawLine(spriteBatch,
                                     new Vector2(position.X - distance, position.Y - distance),
                                     new Vector2(position.X - distance - size, position.Y - distance - size),
                                     HitHintColor, 4f);

                if (KillHintTimer > 0)
                {
                    float alpha = KillHintTimer / 0.5f;
                    Color killColor = new Color(255, 0, 0, Math.Min(alpha, 1.0f) * 255);
                    ShapeExtensions.DrawCircle(spriteBatch, position, Math.Max(KillHintSize, 1), 32, killColor, 2f);
                }
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[DeepHitMarker] Error drawing hint: {ex.Message}");
            }
        }
    }
}
