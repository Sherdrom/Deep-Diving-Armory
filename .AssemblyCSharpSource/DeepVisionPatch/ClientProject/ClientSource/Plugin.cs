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
                if (CurrentColorMode == "White Phosphorus") { return BlueNightVisionTexture; }
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
            GreenNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(0, 255, 0, 50));
            BlueNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(0, 0, 255, 50));
        }

        partial void DisposeProjSpecific()
        {
            // Cleanup resources
            _harmonyInstance?.UnpatchSelf();
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
        public static bool Prefix(LightManager __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, Camera cam, ref Vector2 lookAtPosition)
        {
            Character character = Character.Controlled;
            if (character == null) return true;
            // 检查玩家是否在使用枪械物品并按住右键
            // if (Character.Controlled.SelectedItem?.GetComponent<Holdable>() == null) return;
            Item rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand);
            Item leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand);
            Item headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
            if (rightHand == null && leftHand == null && headItem == null) { return true; }
            if (!((rightHand != null && (rightHand.HasTag("weapon")||rightHand.HasTag("ObstructVision")))|| (leftHand != null && (leftHand.HasTag("weapon")||leftHand.HasTag("ObstructVision"))) || headItem != null && headItem.HasTag("ObstructVision"))) { return true; }
            if (!(rightHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name || leftHand?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name || headItem?.Prefab.ContentPackage?.Name == DeepVisionPatch.Package.Name)) { return true; }
            if (character == null || (!character.IsKeyDown(InputType.Aim)&& !((rightHand != null && rightHand.HasTag("ObstructVision"))|| (leftHand != null && leftHand.HasTag("ObstructVision")) || headItem != null && headItem.HasTag("ObstructVision")))|| !character.CanAim) { return true;}
            // Custom logic for reduced vision cone
            if ((!__instance.LosEnabled || __instance.LosMode == LosMode.None) && __instance.ObstructVisionAmount <= 0.0f) { return false; }
            if (__instance.ObstructVisionAmount > 0.0f) { return true; }
            if (LightManager.ViewTarget == null) { return false; }

            // 面罩视野的开关判断
            foreach (KeyValuePair<ushort, bool> maskStatus in HelmetMaskPatch.MaskStatus)
            {
                if (headItem != null && headItem.ID == maskStatus.Key && !((rightHand != null && rightHand.HasTag("ObstructVision")) || (leftHand != null && leftHand.HasTag("ObstructVision"))))
                {
                    //若面罩打开且不是瞄准状态，则视为正常状态
                    if (maskStatus.Value && !character.IsKeyDown(InputType.Aim)) return true;
                    if (maskStatus.Value)
                    {
                        headItem = null;
                        if (!((rightHand != null && rightHand.HasTag("weapon")) || (leftHand != null && leftHand.HasTag("weapon")))) { return true; }
                        if (!(rightHand?.Prefab.ContentPackage?.Name == "Deep Diving Armory" || leftHand?.Prefab.ContentPackage?.Name == "Deep Diving Armory")) { return true; }
                    }
                }
            }

            // 根据headItem的xml中的tag设置恒定的视野角度：例如30度、45度
            //ToDo：也可根据headItem中包含的物品tag（夜视仪、热成像）来设置角度
            if (headItem != null && headItem.HasTag("ObstructVision") || (rightHand != null && rightHand.HasTag("ObstructVision")) || (leftHand != null && leftHand.HasTag("ObstructVision")))
            {
                float minVal = MathF.PI;
                foreach (KeyValuePair<string, float> kvp in ObstructVision)
                {
                    if (headItem != null && headItem.HasTag(kvp.Key))
                    {
                        if (kvp.Value < minVal) minVal = kvp.Value;
                    }
                    if ((rightHand != null && rightHand.HasTag(kvp.Key)) || (leftHand != null && leftHand.HasTag(kvp.Key)))
                    {
                        if (kvp.Value < minVal) minVal = kvp.Value;
                    }
                    FieldOfView = minVal;
                }
            }

            // 一般情况
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

            graphics.SetRenderTarget(__instance.LosTexture);

                graphics.Clear(Color.Black);
                Vector2 diff = lookAtPosition - LightManager.ViewTarget.WorldPosition;
                diff.Y = -diff.Y;
                if (diff.LengthSquared() > 20.0f * 20.0f) { __instance.losOffset = diff; }
                float rotation = MathUtils.VectorToAngle(__instance.losOffset);

                //the visible area stretches to the maximum when the cursor is this far from the character
                const float MaxOffset = 256.0f;
                // Texture2D texture = new CreateViewTexture().CreateSectorTexture(graphics,256,FieldOfView,Color.Black);
                DeepVisionPatch.ViewTexture.UpdateSectorTexture(FieldOfView, new Color(255,255,255,30));
                Texture2D texture = DeepVisionPatch.ViewTexture.GetTexture();
                Texture2D textureCircle = DeepVisionPatch.ViewTexture.GetTextureCircle();
                //the magic numbers here are just based on experimentation
                float MinHorizontalScale = MathHelper.Lerp(5f, 1.5f, 0);
                float MaxHorizontalScale = MinHorizontalScale * 5f;
                float VerticalScale = MathHelper.Lerp(4.0f, 1.25f, 0);

                //Starting point and scale-based modifier that moves the point of origin closer to the edge of the texture if the player moves their mouse further away, or vice versa.
                float relativeOriginStartPosition = 0.1f; //Increasing this value moves the origin further behind the character
                float originStartPosition = texture.Width * relativeOriginStartPosition * MinHorizontalScale;
                // float relativeOriginLookAtPosModifier = -0.055f; //Increase this value increases how much the vision changes by moving the mouse
                // float originLookAtPosModifier = texture.Width * relativeOriginLookAtPosModifier;
                
                // 获取玩家头部位置
                var headLimb = Character.Controlled.AnimController.GetLimb(LimbType.Head);
                if (headLimb == null) return false;
                Vector2 headPosition = headLimb.WorldPosition;

                Vector2 scale = new Vector2(
                    MathHelper.Clamp(__instance.losOffset.Length() / MaxOffset, MinHorizontalScale, MaxHorizontalScale), VerticalScale);

                spriteBatch.Begin(SpriteSortMode.Deferred, transformMatrix: cam.Transform * Matrix.CreateScale(new Vector3(GameSettings.CurrentConfig.Graphics.LightMapScale, GameSettings.CurrentConfig.Graphics.LightMapScale, 1.0f)));
                spriteBatch.Draw(texture, new Vector2(headPosition.X, -headPosition.Y), null, Color.White, rotation,
                    new Vector2(originStartPosition, texture.Height / 2), scale, SpriteEffects.None, 1.0f);
                spriteBatch.Draw(textureCircle, new Vector2(headPosition.X, -headPosition.Y + 70f), null, Color.White, 0f,
                    new Vector2(originStartPosition, textureCircle.Height / 2), new Vector2(0.35f,0.45f), SpriteEffects.None, 1.0f);
                spriteBatch.End();
                        
            //--------------------------------------
            if (__instance.LosEnabled && __instance.LosMode != LosMode.None && LightManager.ViewTarget != null)
            {
                Vector2 pos = LightManager.ViewTarget.DrawPosition;
                bool centeredOnHead = false;
                if (LightManager.ViewTarget is Character targetCharacter &&
                    targetCharacter.AnimController?.GetLimb(LimbType.Head) is Limb head &&
                    !head.IsSevered && !head.Removed)
                {
                    pos = head.body.DrawPosition;
                    centeredOnHead = true;
                }

                Rectangle camView = new Rectangle(cam.WorldView.X, cam.WorldView.Y - cam.WorldView.Height, cam.WorldView.Width, cam.WorldView.Height);
                Matrix shadowTransform = cam.ShaderTransform
                    * Matrix.CreateOrthographic(GameMain.GraphicsWidth, GameMain.GraphicsHeight, -1, 1) * 0.5f;

                var convexHulls = ConvexHull.GetHullsInRange(LightManager.ViewTarget.Position, cam.WorldView.Width * 0.75f, LightManager.ViewTarget.Submarine);

                //make sure the head isn't peeking through any LOS segments, and if it is,
                //center the LOS on the character's collider instead
                if (centeredOnHead)
                {
                    foreach (var ch in convexHulls)
                    {
                        if (!ch.Enabled) { continue; }
                        Vector2 currentViewPos = pos;
                        Vector2 defaultViewPos = LightManager.ViewTarget.DrawPosition;
                        if (ch.ParentEntity?.Submarine != null)
                        {
                            defaultViewPos -= ch.ParentEntity.Submarine.DrawPosition;
                            currentViewPos -= ch.ParentEntity.Submarine.DrawPosition;
                        }
                        //check if a line from the character's collider to the head intersects with the los segment (= head poking through it)
                        if (ch.LosIntersects(defaultViewPos, currentViewPos))
                        {
                            pos = LightManager.ViewTarget.DrawPosition;
                        }
                    }
                }

                if (convexHulls != null)
                {
                    LightManager.ShadowVertices.Clear();
                    LightManager.PenumbraVertices.Clear();
                    foreach (ConvexHull convexHull in convexHulls)
                    {
                        if (!convexHull.Intersects(camView)) { continue; }

                        Vector2 relativeViewPos = pos;
                        if (convexHull.ParentEntity?.Submarine != null) 
                        { 
                            relativeViewPos -= convexHull.ParentEntity.Submarine.DrawPosition;
                        }

                        convexHull.CalculateLosVertices(relativeViewPos);

                        for (int i = 0; i < convexHull.ShadowVertexCount; i++)
                        {
                            LightManager.ShadowVertices.Add(convexHull.ShadowVertices[i]);
                        }

                        for (int i = 0; i < convexHull.PenumbraVertexCount; i++)
                        {
                            LightManager.PenumbraVertices.Add(convexHull.PenumbraVertices[i]);
                        }
                    }

                    if (LightManager.ShadowVertices.Count > 0)
                    {
                        ConvexHull.shadowEffect.World = shadowTransform;
                        ConvexHull.shadowEffect.CurrentTechnique.Passes[0].Apply();
                        graphics.DrawUserPrimitives(PrimitiveType.TriangleList, LightManager.ShadowVertices.ToArray(), 0, LightManager.ShadowVertices.Count / 3, VertexPositionColor.VertexDeclaration);

                        if (LightManager.PenumbraVertices.Count > 0)
                        {
                            ConvexHull.penumbraEffect.World = shadowTransform;
                            ConvexHull.penumbraEffect.CurrentTechnique.Passes[0].Apply();
                            graphics.DrawUserPrimitives(PrimitiveType.TriangleList, LightManager.PenumbraVertices.ToArray(), 0, LightManager.PenumbraVertices.Count / 3, VertexPositionTexture.VertexDeclaration);
                        }
                    }
                }
            }
            // Skip the original method
            graphics.SetRenderTarget(null);
            return false;
        }
    }
}
