using Barotrauma.Lights;
using Barotrauma.LuaCs.Data;
using Microsoft.Xna.Framework.Graphics;


namespace DeepVisionPatch
{
    partial class DeepVisionPatch
    {
        private Harmony? _harmonyInstance;
        private static String CurrentColorMode;

        // Texture creators - initialized during OnLoadCompleted
        public static CreateViewTexture ViewTexture { get; } = new CreateViewTexture();
        private static CreateNightVisionTexture GreenNightVisionTexture { get; } = new CreateNightVisionTexture();
        private static CreateNightVisionTexture BlueNightVisionTexture { get; } = new CreateNightVisionTexture();

        public static CreateNightVisionTexture CurrentNVTexture 
        { 
            get
            {
                if (CurrentColorMode == "Blue") { return BlueNightVisionTexture; }
                return GreenNightVisionTexture;
            }
        }

        partial void InitlizeProjSpecific()
        {
            LuaCsPluginService.TryGetPackageForPlugin<DeepVisionPatch>(out ContentPackage ResultPackage);
            Package = ResultPackage;

            LuaCsConfigService.TryGetConfig(Package, "NVGColorMode", out ISettingBase SetColor);
            CurrentColorMode = SetColor.GetStringValue();
            SetColor.OnValueChanged += _ =>
            {
                CurrentColorMode = SetColor.GetStringValue();
            };

            // Called when plugin is loading - use for initialization that doesn't depend on other plugins
            _harmonyInstance = new Harmony("DeepVisionPatch");
        }

        partial void OnLoadCompletedProjSpecific()
        {
            // Called after all plugins have loaded - use for plugin interactions and final initialization
            _harmonyInstance?.PatchAll();
            // Initialize texture creators with their specific parameters
            ViewTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, 256);
            GreenNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(55, 210, 90, 100));
            BlueNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(65, 145, 225, 100));
        }

        partial void DisposeProjSpecific()
        {
            NightVisionPatch.RemoveNightVisionLight();
            NightVisionPatch.NightVisionStatus.Clear();
            _harmonyInstance?.UnpatchSelf();
        }
    }

    [HarmonyPatch(typeof(LightManager), nameof(LightManager.ClearLights))]
    public static class Patch_LightManager_ClearLights
    {
        public static void Prefix()
        {
            NightVisionPatch.RemoveNightVisionLight();
            NightVisionPatch.NightVisionStatus.Clear();
        }
    }

    [HarmonyPatch(typeof(LightManager),nameof(LightManager.UpdateObstructVision))]
    public static class Patch_LightManager_UpdateObstructVision
    {
        public static float FieldOfView { get; set; } = MathF.PI * 8 / 9; // Default to 8/9 PI degrees
        
        // 恒定视野字典
        public static readonly Dictionary<string, float> ObstructVision = new Dictionary<string, float>
        {
            ["ObstructVision_30"] = MathF.PI / 6,
            ["ObstructVision_45"] = MathF.PI / 4
        };
        public static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
        {
            List<CodeInstruction> codes = new List<CodeInstruction>(instructions);
            MethodInfo whiteGetter = AccessTools.Method(typeof(Color), "get_White")
                ?? throw new InvalidOperationException("DeepVisionPatch: Color.get_White was not found.");
            MethodInfo clearMethod = AccessTools.Method(typeof(GraphicsDevice), nameof(GraphicsDevice.Clear), new[] { typeof(Color) })
                ?? throw new InvalidOperationException("DeepVisionPatch: GraphicsDevice.Clear(Color) was not found.");
            MethodInfo helperMethod = AccessTools.Method(
                typeof(Patch_LightManager_UpdateObstructVision),
                nameof(DrawDdaVisionOrClear),
                new[] { typeof(GraphicsDevice), typeof(Color), typeof(LightManager), typeof(SpriteBatch), typeof(Camera), typeof(Vector2) })
                ?? throw new InvalidOperationException("DeepVisionPatch: DDA vision helper was not found.");

            int clearIndex = -1;
            for (int i = 0; i + 1 < codes.Count; i++)
            {
                bool white = IsCall(codes[i]) && Equals(codes[i].operand, whiteGetter);
                bool clear = IsCall(codes[i + 1]) && Equals(codes[i + 1].operand, clearMethod);
                if (!white || !clear) { continue; }
                if (clearIndex >= 0)
                {
                    throw new InvalidOperationException("DeepVisionPatch: UpdateObstructVision has multiple Color.White clear anchors.");
                }
                clearIndex = i + 1;
            }

            if (clearIndex < 0)
            {
                throw new InvalidOperationException("DeepVisionPatch: UpdateObstructVision Color.White clear anchor was not found.");
            }

            CodeInstruction clearInstruction = codes[clearIndex];
            clearInstruction.opcode = OpCodes.Call;
            clearInstruction.operand = helperMethod;
            codes.InsertRange(clearIndex, new[]
            {
                new CodeInstruction(OpCodes.Ldarg_0),
                new CodeInstruction(OpCodes.Ldarg_2),
                new CodeInstruction(OpCodes.Ldarg_3),
                new CodeInstruction(OpCodes.Ldarg_S, (byte)4)
            });
            return codes;
        }

        private static bool IsCall(CodeInstruction instruction)
            => instruction.opcode == OpCodes.Call || instruction.opcode == OpCodes.Callvirt;

        private static void DrawDdaVisionOrClear(
            GraphicsDevice graphics,
            Color fallbackColor,
            LightManager lightManager,
            SpriteBatch spriteBatch,
            Camera cam,
            Vector2 lookAtPosition)
        {
            Character character = Character.Controlled;
            if (character == null)
            {
                graphics.Clear(fallbackColor);
                return;
            }

            Item rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand);
            Item leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand);
            Item? headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
            bool hasWeaponInHand = rightHand?.HasTag("weapon") == true || leftHand?.HasTag("weapon") == true;
            bool hasObstructVisionItem = rightHand?.HasTag("ObstructVision") == true
                || leftHand?.HasTag("ObstructVision") == true
                || headItem?.HasTag("ObstructVision") == true;
            if (!hasWeaponInHand && !hasObstructVisionItem)
            {
                graphics.Clear(fallbackColor);
                return;
            }

            bool hasDeepVisionItem = rightHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name
                || leftHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name
                || headItem?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name;
            if (!hasDeepVisionItem)
            {
                graphics.Clear(fallbackColor);
                return;
            }

            if (!hasObstructVisionItem && (!character.IsKeyDown(InputType.Aim) || !character.CanAim))
            {
                graphics.Clear(fallbackColor);
                return;
            }

            foreach (KeyValuePair<ushort, bool> maskStatus in HelmetMaskPatch.MaskStatus)
            {
                if (headItem != null && headItem.ID == maskStatus.Key && !((rightHand != null && rightHand.HasTag("ObstructVision")) || (leftHand != null && leftHand.HasTag("ObstructVision"))))
                {
                    if (maskStatus.Value && !character.IsKeyDown(InputType.Aim))
                    {
                        graphics.Clear(fallbackColor);
                        return;
                    }
                    if (maskStatus.Value)
                    {
                        headItem = null;
                        if (!((rightHand != null && rightHand.HasTag("weapon")) || (leftHand != null && leftHand.HasTag("weapon"))))
                        {
                            graphics.Clear(fallbackColor);
                            return;
                        }
                        if (!(rightHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name || leftHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name))
                        {
                            graphics.Clear(fallbackColor);
                            return;
                        }
                    }
                }
            }

            if (headItem != null && headItem.HasTag("ObstructVision") || (rightHand != null && rightHand.HasTag("ObstructVision")) || (leftHand != null && leftHand.HasTag("ObstructVision")))
            {
                float minVal = MathF.PI;
                foreach (KeyValuePair<string, float> kvp in ObstructVision)
                {
                    if (headItem != null && headItem.HasTag(kvp.Key) && kvp.Value < minVal)
                    {
                        minVal = kvp.Value;
                    }
                    if ((rightHand != null && rightHand.HasTag(kvp.Key)) || (leftHand != null && leftHand.HasTag(kvp.Key)))
                    {
                        if (kvp.Value < minVal) minVal = kvp.Value;
                    }
                    FieldOfView = minVal;
                }
            }
            else
            {
                float offsetMin = 256f;
                float offsetMax = 540f;
                float neededOffset = MathHelper.Clamp(Screen.Selected.Cam.OffsetAmount, offsetMin, offsetMax);
                float minFov = MathF.PI / 6;
                float maxFov = MathF.PI * 8 / 9;
                float t = MathHelper.Clamp((neededOffset - offsetMin) / (offsetMax - offsetMin), 0f, 1f);
                FieldOfView = maxFov - (maxFov - minFov) * t;
            }

            graphics.Clear(Color.Black);
            Vector2 diff = lookAtPosition - LightManager.ViewTarget.WorldPosition;
            diff.Y = -diff.Y;
            if (diff.LengthSquared() > 20.0f * 20.0f) { lightManager.losOffset = diff; }
            float rotation = MathUtils.VectorToAngle(lightManager.losOffset);

            const float MaxOffset = 256.0f;
            DeepVisionPatch.ViewTexture.UpdateSectorTexture(FieldOfView, new Color(255, 255, 255, 30));
            Texture2D texture = DeepVisionPatch.ViewTexture.GetTexture();
            Texture2D textureCircle = DeepVisionPatch.ViewTexture.GetTextureCircle();
            float MinHorizontalScale = MathHelper.Lerp(5f, 1.5f, 0);
            float MaxHorizontalScale = MinHorizontalScale * 5f;
            float VerticalScale = MathHelper.Lerp(4.0f, 1.25f, 0);

            float relativeOriginStartPosition = 0.1f;
            float originStartPosition = texture.Width * relativeOriginStartPosition * MinHorizontalScale;

            Limb? headLimb = character.AnimController.GetLimb(LimbType.Head);
            if (headLimb == null)
            {
                graphics.Clear(fallbackColor);
                return;
            }
            Vector2 headPosition = headLimb.WorldPosition;

            Vector2 scale = new Vector2(
                MathHelper.Clamp(lightManager.losOffset.Length() / MaxOffset, MinHorizontalScale, MaxHorizontalScale), VerticalScale);

            spriteBatch.Begin(SpriteSortMode.Deferred, transformMatrix: cam.Transform * Matrix.CreateScale(new Vector3(GameSettings.CurrentConfig.Graphics.LightMapScale, GameSettings.CurrentConfig.Graphics.LightMapScale, 1.0f)));
            spriteBatch.Draw(texture, new Vector2(headPosition.X, -headPosition.Y), null, Color.White, rotation,
                new Vector2(originStartPosition, texture.Height / 2), scale, SpriteEffects.None, 1.0f);
            spriteBatch.Draw(textureCircle, new Vector2(headPosition.X, -headPosition.Y + 70f), null, Color.White, 0f,
                new Vector2(originStartPosition, textureCircle.Height / 2), new Vector2(0.35f, 0.45f), SpriteEffects.None, 1.0f);
            spriteBatch.End();
        }
    }
}
