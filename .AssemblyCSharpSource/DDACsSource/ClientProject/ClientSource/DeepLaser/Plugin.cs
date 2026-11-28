using Barotrauma.Items.Components;
using Barotrauma.Lights;
using FarseerPhysics;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;
using System.Reflection;

namespace DeepLaser
{
    public partial class DeepLaser
    {
        internal static void DisposeGraphics()
        {
            impactGlowTexture?.Dispose();
            impactCoreTexture?.Dispose();
            laserOverlayTarget?.Dispose();
            waterLaserSourceTarget?.Dispose();
            distortedLaserOverlayTarget?.Dispose();
            LaserEraseBlendState.Dispose();
            LaserOnOpaqueBackgroundBlendState.Dispose();
            LaserDepthWriteState.Dispose();
            LaserOccluderDepthState.Dispose();
        }

        private const float MaxLaserLength = 4000.0f;
        private const int LaserOccluderPadding = 4;
        private static readonly (string Tag, Color Color)[] LaserColors =
        {
            ("red_laser", new Color(255, 32, 32, 120)),
            ("green_laser", new Color(32, 255, 64, 120)),
            ("blue_laser", new Color(64, 128, 255, 120))
        };

        // Item.Draw's local function also accounts for wearables, the head and ladder pose.
        private static readonly Func<LimbType, Holdable, float, float> GetHeldItemDepth = typeof(Item)
            .GetMethods(BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public)
            .Single(method => method.Name.StartsWith("<Draw>g__GetHeldItemDepth|", StringComparison.Ordinal))
            .CreateDelegate<Func<LimbType, Holdable, float, float>>();

        private static MethodInfo? gunsmithTryGetTransformMethod;
        private static MethodInfo? gunsmithTryGetAttachmentDepthMethod;
        private static bool gunsmithTransformApiResolutionAttempted;
        private static bool gunsmithDepthApiResolutionAttempted;
        private static PropertyInfo? gunsmithTransformDrawPositionProperty;
        private static PropertyInfo? gunsmithTransformDrawRotationProperty;
        private static PropertyInfo? gunsmithTransformDirectionProperty;
        private static PropertyInfo? gunsmithTransformFacingDirectionProperty;
        private static bool loggedGunsmithTransformReflectionError;
        private static Texture2D? impactGlowTexture;
        private static Texture2D? impactCoreTexture;
        private static RenderTarget2D? laserOverlayTarget;
        private static RenderTarget2D? waterLaserSourceTarget;
        private static RenderTarget2D? distortedLaserOverlayTarget;
        private static readonly List<LaserFrameData> frameLasers = new();
        private static readonly HashSet<Item> seenWeapons = new();
        private static bool renderingDistortedLaserOverlay;
        private static bool laserOverlayReady;
        private static bool distortedLaserOverlayReady;
        private static readonly BlendState LaserEraseBlendState = new()
        {
            ColorSourceBlend = Blend.Zero,
            ColorDestinationBlend = Blend.InverseSourceAlpha,
            ColorBlendFunction = BlendFunction.Add,
            AlphaSourceBlend = Blend.Zero,
            AlphaDestinationBlend = Blend.InverseSourceAlpha,
            AlphaBlendFunction = BlendFunction.Add
        };
        private static readonly BlendState LaserOnOpaqueBackgroundBlendState = new()
        {
            ColorSourceBlend = Blend.SourceAlpha,
            ColorDestinationBlend = Blend.InverseSourceAlpha,
            ColorBlendFunction = BlendFunction.Add,
            AlphaSourceBlend = Blend.Zero,
            AlphaDestinationBlend = Blend.One,
            AlphaBlendFunction = BlendFunction.Add
        };
        private static readonly DepthStencilState LaserDepthWriteState = new()
        {
            DepthBufferEnable = true,
            DepthBufferWriteEnable = true,
            DepthBufferFunction = CompareFunction.LessEqual
        };
        private static readonly DepthStencilState LaserOccluderDepthState = new()
        {
            DepthBufferEnable = true,
            DepthBufferWriteEnable = false,
            DepthBufferFunction = CompareFunction.Less
        };
        [HarmonyPatch]
        private static class GameScreenDrawMapPatch
        {
            private static MethodBase? TargetMethod()
            {
                return AccessTools.Method(typeof(GameScreen), nameof(GameScreen.DrawMap), new[] { typeof(GraphicsDevice), typeof(SpriteBatch), typeof(double) });
            }

            private static void Prefix(GameScreen __instance, GraphicsDevice __0, SpriteBatch __1)
            {
                PrepareLaserOverlay(__0, __1, __instance);
            }
        }

        [HarmonyPatch(typeof(WaterRenderer), nameof(WaterRenderer.RenderWater))]
        private static class WaterRendererRenderWaterPatch
        {
            private static void Prefix(WaterRenderer __instance, SpriteBatch spriteBatch, Camera cam)
            {
                if (renderingDistortedLaserOverlay ||
                    !laserOverlayReady ||
                    distortedLaserOverlayReady ||
                    laserOverlayTarget == null ||
                    laserOverlayTarget.IsDisposed)
                {
                    return;
                }

                PrepareDistortedLaserOverlay(__instance, spriteBatch, cam);
            }
        }

        [HarmonyPatch]
        private static class LightManagerDebugDrawVerticesPatch
        {
            private static MethodBase? TargetMethod()
            {
                Type? lightManagerType = AccessTools.TypeByName("Barotrauma.Lights.LightManager");
                return AccessTools.Method(lightManagerType, "DebugDrawVertices", new[] { typeof(SpriteBatch) });
            }

            private static void Postfix(SpriteBatch spriteBatch)
            {
                if (spriteBatch == null || Screen.Selected is not GameScreen gameScreen) { return; }

                CompositeLaserOverlay(spriteBatch, gameScreen);
            }
        }

        private static void PrepareLaserOverlay(GraphicsDevice graphicsDevice, SpriteBatch spriteBatch, GameScreen gameScreen)
        {
            laserOverlayReady = false;
            distortedLaserOverlayReady = false;
            RenderTargetBinding[]? sceneTargets = null;
            bool renderTargetChanged = false;

            try
            {
                // DrawMap updates submarine DrawPosition right after this prefix; sync early so
                // laser rays, hull vertices, and occluders match the current frame's sub transform.
                foreach (Submarine sub in Submarine.Loaded)
                {
                    sub.UpdateTransform();
                }

                CollectLaserFrameData();
                if (frameLasers.Count == 0) { return; }

                sceneTargets = graphicsDevice.GetRenderTargets();
                int targetWidth = GameMain.GraphicsWidth > 0
                    ? GameMain.GraphicsWidth
                    : graphicsDevice.PresentationParameters.BackBufferWidth;
                int targetHeight = GameMain.GraphicsHeight > 0
                    ? GameMain.GraphicsHeight
                    : graphicsDevice.PresentationParameters.BackBufferHeight;

                if (sceneTargets.Length > 0 && sceneTargets[0].RenderTarget is Texture2D sceneTarget)
                {
                    targetWidth = sceneTarget.Width;
                    targetHeight = sceneTarget.Height;
                }

                RenderTarget2D overlayTarget = GetLaserOverlayTarget(graphicsDevice, targetWidth, targetHeight);

                graphicsDevice.SetRenderTarget(overlayTarget);
                renderTargetChanged = true;
                graphicsDevice.Clear(ClearOptions.Target | ClearOptions.DepthBuffer, Color.Transparent, 1.0f, 0);

                // Store the source color and alpha once; the final composite performs the original blending.
                spriteBatch.Begin(SpriteSortMode.Deferred, BlendState.Opaque, GUI.SamplerState, LaserDepthWriteState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
                DrawLaserBeams(spriteBatch);
                spriteBatch.End();

                spriteBatch.Begin(SpriteSortMode.Deferred, null, GUI.SamplerState, LaserDepthWriteState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
                DrawLaserImpactDots(spriteBatch);
                spriteBatch.End();

                spriteBatch.Begin(SpriteSortMode.Deferred, LaserEraseBlendState, GUI.SamplerState, LaserOccluderDepthState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
                DrawWorldOccluders(spriteBatch);
                DrawLaserOccluders(spriteBatch);
                spriteBatch.End();

                laserOverlayReady = true;
            }
            finally
            {
                if (renderTargetChanged && sceneTargets != null)
                {
                    if (sceneTargets.Length == 0)
                    {
                        graphicsDevice.SetRenderTarget(null);
                    }
                    else
                    {
                        graphicsDevice.SetRenderTargets(sceneTargets);
                    }
                }

                frameLasers.Clear();
                seenWeapons.Clear();
            }
        }

        private static void PrepareDistortedLaserOverlay(WaterRenderer waterRenderer, SpriteBatch spriteBatch, Camera cam)
        {
            if (laserOverlayTarget == null || laserOverlayTarget.IsDisposed) { return; }

            GraphicsDevice graphicsDevice = spriteBatch.GraphicsDevice;
            RenderTargetBinding[] sceneTargets = graphicsDevice.GetRenderTargets();
            RenderTarget2D waterSourceTarget = GetWaterLaserSourceTarget(graphicsDevice, laserOverlayTarget.Width, laserOverlayTarget.Height);
            RenderTarget2D distortedTarget = GetDistortedLaserOverlayTarget(graphicsDevice, laserOverlayTarget.Width, laserOverlayTarget.Height);

            // Opaque black lets the game's air pass erase water-distorted pixels that drift into dry areas.
            graphicsDevice.SetRenderTarget(waterSourceTarget);
            graphicsDevice.Clear(Color.Black);
            spriteBatch.Begin(
                SpriteSortMode.Deferred,
                LaserOnOpaqueBackgroundBlendState,
                SamplerState.PointClamp,
                DepthStencilState.None,
                null);
            spriteBatch.Draw(laserOverlayTarget, Vector2.Zero, Color.White);
            spriteBatch.End();

            graphicsDevice.SetRenderTarget(distortedTarget);
            graphicsDevice.Clear(Color.Black);

            renderingDistortedLaserOverlay = true;
            try
            {
                waterRenderer.RenderWater(spriteBatch, waterSourceTarget, cam);
                waterRenderer.RenderAir(graphicsDevice, cam, waterSourceTarget, cam.ShaderTransform);
                distortedLaserOverlayReady = true;
            }
            finally
            {
                renderingDistortedLaserOverlay = false;
                if (sceneTargets.Length == 0)
                {
                    graphicsDevice.SetRenderTarget(null);
                }
                else
                {
                    graphicsDevice.SetRenderTargets(sceneTargets);
                }
            }
        }

        private static void CompositeLaserOverlay(SpriteBatch spriteBatch, GameScreen gameScreen)
        {
            if (!laserOverlayReady) { return; }
            laserOverlayReady = false;
            if (laserOverlayTarget == null || laserOverlayTarget.IsDisposed) { return; }

            bool useDistortedOverlay = distortedLaserOverlayReady &&
                distortedLaserOverlayTarget != null &&
                !distortedLaserOverlayTarget.IsDisposed;
            Texture2D overlayTarget = useDistortedOverlay
                ? distortedLaserOverlayTarget!
                : laserOverlayTarget;

            Matrix inverseTransform = Matrix.Invert(gameScreen.Cam.Transform);
            Vector2 topLeft = Vector2.Transform(Vector2.Zero, inverseTransform);
            Vector2 topRight = Vector2.Transform(new Vector2(overlayTarget.Width, 0.0f), inverseTransform);
            Vector2 bottomLeft = Vector2.Transform(new Vector2(0.0f, overlayTarget.Height), inverseTransform);
            Vector2 right = topRight - topLeft;
            Vector2 down = bottomLeft - topLeft;
            Vector2 scale = new(right.Length() / overlayTarget.Width, down.Length() / overlayTarget.Height);
            float rotation = MathF.Atan2(right.Y, right.X);

            // Water rendering outputs an opaque dark background; add only its illuminated laser pixels.
            spriteBatch.End();
            spriteBatch.Begin(
                SpriteSortMode.Deferred,
                useDistortedOverlay ? BlendState.Additive : BlendState.NonPremultiplied,
                SamplerState.LinearWrap,
                DepthStencilState.None,
                null,
                null,
                transformMatrix: gameScreen.Cam.Transform);
            spriteBatch.Draw(overlayTarget, topLeft, null, Color.White, rotation, Vector2.Zero, scale, SpriteEffects.None, 0.0f);
            spriteBatch.End();
            spriteBatch.Begin(
                SpriteSortMode.Deferred,
                BlendState.NonPremultiplied,
                SamplerState.LinearWrap,
                DepthStencilState.None,
                null,
                null,
                transformMatrix: gameScreen.Cam.Transform);
        }

        private static RenderTarget2D GetLaserOverlayTarget(GraphicsDevice graphicsDevice, int width, int height)
        {
            if (laserOverlayTarget == null ||
                laserOverlayTarget.IsDisposed ||
                laserOverlayTarget.Width != width ||
                laserOverlayTarget.Height != height)
            {
                laserOverlayTarget?.Dispose();
                laserOverlayTarget = new RenderTarget2D(graphicsDevice, width, height, false, SurfaceFormat.Color, DepthFormat.Depth24);
            }

            return laserOverlayTarget;
        }

        private static RenderTarget2D GetWaterLaserSourceTarget(GraphicsDevice graphicsDevice, int width, int height)
        {
            if (waterLaserSourceTarget == null ||
                waterLaserSourceTarget.IsDisposed ||
                waterLaserSourceTarget.Width != width ||
                waterLaserSourceTarget.Height != height)
            {
                waterLaserSourceTarget?.Dispose();
                waterLaserSourceTarget = new RenderTarget2D(graphicsDevice, width, height, false, SurfaceFormat.Color, DepthFormat.None);
            }

            return waterLaserSourceTarget;
        }

        private static RenderTarget2D GetDistortedLaserOverlayTarget(GraphicsDevice graphicsDevice, int width, int height)
        {
            if (distortedLaserOverlayTarget == null ||
                distortedLaserOverlayTarget.IsDisposed ||
                distortedLaserOverlayTarget.Width != width ||
                distortedLaserOverlayTarget.Height != height)
            {
                distortedLaserOverlayTarget?.Dispose();
                distortedLaserOverlayTarget = new RenderTarget2D(graphicsDevice, width, height, false, SurfaceFormat.Color, DepthFormat.None);
            }

            return distortedLaserOverlayTarget;
        }

        private static void DrawWorldOccluders(SpriteBatch spriteBatch)
        {
            // ponytail: O(visible entities × active lasers); add a spatial index only if many simultaneous lasers profile badly.
            foreach (MapEntity mapEntity in Submarine.VisibleEntities)
            {
                if (mapEntity == null || mapEntity.Removed) { continue; }
                if (mapEntity is Hull hull)
                {
                    // Branches can grow outside their root hull.
                    hull.BallastFlora?.Draw(spriteBatch);
                    continue;
                }
                if (mapEntity is not Structure && mapEntity is not Item) { continue; }
                if (mapEntity is Item item && item.HasTag("deep_gunsmith".ToIdentifier()))
                {
                    continue;
                }
                if (!IntersectsAnyLaser(mapEntity.WorldRect)) { continue; }
                if (mapEntity is Item weaponItem &&
                    weaponItem.GetComponent<RangedWeapon>() != null &&
                    (IsFrameLaserWeapon(weaponItem) || TryFindLaser(weaponItem, out _, out _)))
                {
                    continue;
                }

                if (mapEntity.DrawBelowWater) { mapEntity.Draw(spriteBatch, false, true); }
                // Solid walls have their own front pass in DrawDamageable, outside DrawOverWater.
                if (mapEntity.DrawOverWater || mapEntity is Structure { DrawDamageEffect: true })
                {
                    mapEntity.Draw(spriteBatch, false, false);
                }
            }
        }

        private static void DrawLaserOccluders(SpriteBatch spriteBatch)
        {
            for (int i = 0; i < frameLasers.Count; i++)
            {
                DrawWeaponOccluder(spriteBatch, frameLasers[i]);
            }
        }

        private static bool IsFrameLaserWeapon(Item item)
        {
            for (int i = 0; i < frameLasers.Count; i++)
            {
                if (frameLasers[i].WeaponItem == item) { return true; }
            }

            return false;
        }

        private static bool IntersectsAnyLaser(Rectangle worldRect)
        {
            Rectangle expandedRect = MathUtils.ExpandRect(worldRect, LaserOccluderPadding);
            for (int i = 0; i < frameLasers.Count; i++)
            {
                LaserFrameData laser = frameLasers[i];
                if (WorldRectContains(expandedRect, laser.StartWorld) ||
                    WorldRectContains(expandedRect, laser.EndWorld) ||
                    MathUtils.GetLineWorldRectangleIntersection(laser.StartWorld, laser.EndWorld, expandedRect, out _))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool WorldRectContains(Rectangle rect, Vector2 point)
        {
            return point.X >= rect.X &&
                   point.X <= rect.Right &&
                   point.Y <= rect.Y &&
                   point.Y >= rect.Y - rect.Height;
        }

        private static void DrawWeaponOccluder(SpriteBatch spriteBatch, LaserFrameData laser)
        {
            Item weaponItem = laser.WeaponItem;
            Item laserItem = laser.LaserItem;
            if (laser.HasGunsmithDrawTransform)
            {
                bool flipX = laser.AttachmentFacingDirection < 0.0f;
                DrawSpriteOccluder(spriteBatch, weaponItem,
                    weaponItem.body?.DrawPosition ?? weaponItem.DrawPosition,
                    weaponItem.body?.DrawRotation ?? -weaponItem.RotationRad, flipX, laser.WeaponDepth);
                DrawSpriteOccluder(
                    spriteBatch,
                    laserItem,
                    laser.AttachmentDrawPosition,
                    laser.AttachmentDrawRotation,
                    flipX,
                    laser.AttachmentDepth);
                return;
            }

            // Item.Draw applies the same held depth to the gun and its visible container sprites.
            weaponItem.Draw(spriteBatch, false, weaponItem.DrawBelowWater, Color.White, laser.WeaponDepth);
        }

        private static void CollectLaserFrameData()
        {
            foreach (Character character in Character.CharacterList)
            {
                if (character.Removed || !character.Enabled) { continue; }

                foreach (Item weaponItem in character.HeldItems)
                {
                    TryAddLaserFrameData(weaponItem, character);
                }
            }

            foreach (Item weaponItem in Item.ItemList)
            {
                if (weaponItem == null || weaponItem.Removed || weaponItem.ParentInventory != null) { continue; }
                TryAddLaserFrameData(weaponItem, holder: null);
            }
        }

        private static void TryAddLaserFrameData(Item? weaponItem, Character? holder)
        {
            if (weaponItem == null ||
                weaponItem.GetComponent<RangedWeapon>() == null ||
                !seenWeapons.Add(weaponItem))
            {
                return;
            }

            if (TryCreateLaserFrameData(weaponItem, holder, out LaserFrameData laser))
            {
                frameLasers.Add(laser);
            }
        }

        private static void DrawLaserBeams(SpriteBatch spriteBatch)
        {
            for (int i = 0; i < frameLasers.Count; i++)
            {
                LaserFrameData laser = frameLasers[i];
                GUI.DrawLine(spriteBatch, laser.StartDraw, laser.EndDraw, laser.Color, depth: laser.BeamDepth, width: 1.0f);
            }
        }

        private static void DrawLaserImpactDots(SpriteBatch spriteBatch)
        {
            for (int i = 0; i < frameLasers.Count; i++)
            {
                LaserFrameData laser = frameLasers[i];
                if (laser.HitObstacle)
                {
                    DrawImpactDot(spriteBatch, laser.EndDraw, laser.Color, laser.BeamDepth);
                }
            }
        }

        private static bool TryFindLaser(Item weapon, out Item? laserItem, out Color color)
        {
            laserItem = null;
            color = Color.Transparent;

            if (weapon.OwnInventory == null) { return false; }

            laserItem = weapon.OwnInventory.FindItem(IsLaserItem, recursive: true);
            return laserItem != null && TryGetLaserColor(laserItem, out color);
        }

        private static bool IsLaserItem(Item? item)
        {
            return item != null && TryGetLaserColor(item, out _);
        }

        private static bool TryGetLaserColor(Item item, out Color color)
        {
            foreach ((string tag, Color mappedColor) in LaserColors)
            {
                if (item.HasTag(tag.ToIdentifier()))
                {
                    color = mappedColor;
                    return true;
                }
            }

            color = Color.Transparent;
            return false;
        }

        private static bool TryCreateLaserFrameData(Item weaponItem, Character? holder, out LaserFrameData laser)
        {
            laser = default;
            if (weaponItem.body == null ||
                !TryFindLaser(weaponItem, out Item? laserItem, out Color laserColor) ||
                laserItem == null)
            {
                return false;
            }

            weaponItem.body.UpdateDrawPosition();
            if (!TryGetLaserTransform(
                    weaponItem,
                    laserItem,
                    out bool hasGunsmithTransform,
                    out bool hasGunsmithDrawTransform,
                    out Vector2 startWorld,
                    out Vector2 directionWorld,
                    out Vector2 attachmentDrawPosition,
                    out float attachmentDrawRotation,
                    out float attachmentFacingDirection))
            {
                return false;
            }

            Vector2 endWorld = startWorld + directionWorld * MaxLaserLength;

            Vector2? hitPositionWorld = FindLaserHit(startWorld, endWorld, holder, weaponItem, laserItem);
            bool hitObstacle = hitPositionWorld.HasValue;
            if (hitPositionWorld.HasValue)
            {
                endWorld = hitPositionWorld.Value;
            }

            Vector2 startDraw = new(startWorld.X, -startWorld.Y);
            Vector2 endDraw = new(endWorld.X, -endWorld.Y);
            if (!IsFinite(startDraw) || !IsFinite(endDraw)) { return false; }

            float? gunsmithDepth = hasGunsmithTransform && TryGetGunsmithAttachmentDepth(weaponItem, laserItem, out float resolvedDepth)
                ? resolvedDepth : null;
            var depths = GetLaserDepths(weaponItem, laserItem, holder, hasGunsmithTransform, gunsmithDepth);

            laser = new LaserFrameData
            {
                WeaponItem = weaponItem,
                LaserItem = laserItem,
                WeaponDepth = depths.Weapon,
                Color = laserColor,
                StartWorld = startWorld,
                EndWorld = endWorld,
                StartDraw = startDraw,
                EndDraw = endDraw,
                BeamDepth = depths.Beam,
                HitObstacle = hitObstacle,
                HasGunsmithDrawTransform = hasGunsmithDrawTransform,
                AttachmentDrawPosition = attachmentDrawPosition,
                AttachmentDrawRotation = attachmentDrawRotation,
                AttachmentFacingDirection = attachmentFacingDirection,
                AttachmentDepth = depths.Attachment
            };
            return true;
        }

        private static float GetWeaponDrawDepth(Item weapon, Character? holder)
        {
            float depth = weapon.GetDrawDepth();
            if (holder?.Inventory is not { } inventory || weapon.GetComponent<Holdable>() is not { } holdable ||
                holdable.Picker != holder) { return depth; }

            if (inventory.GetItemInLimbSlot(InvSlotType.RightHand) == weapon) { return GetHeldItemDepth(LimbType.RightHand, holdable, depth); }
            if (inventory.GetItemInLimbSlot(InvSlotType.LeftHand) == weapon) { return GetHeldItemDepth(LimbType.LeftHand, holdable, depth); }
            return depth;
        }

        private static float GetContainedDrawDepth(Item weapon, Item attachment, float weaponDepth)
        {
            if (attachment == weapon || attachment.ParentInventory is not ItemInventory inventory ||
                inventory.Owner is not Item parent) { return weaponDepth; }

            ItemContainer container = inventory.Container;
            float layer = container.ContainedSpriteDepth < 0 ? attachment.Sprite?.Depth ?? 0.0f : container.ContainedSpriteDepth;
            if (container.containedSpriteDepths.Length > 0)
            {
                int index = container.ItemsUseInventoryPlacement ? inventory.FindIndex(attachment) : 0;
                if (!container.ItemsUseInventoryPlacement)
                {
                    foreach (var contained in container.containedItems)
                    {
                        if (contained.Item == attachment) { break; }
                        if (!contained.Hide && contained.Item?.Sprite != null) { index++; }
                    }
                }
                if ((uint)index < container.containedSpriteDepths.Length) { layer = container.containedSpriteDepths[index]; }
            }
            float parentDepth = GetContainedDrawDepth(weapon, parent, weaponDepth);
            return parentDepth + (layer - (parent.Sprite?.Depth ?? parent.SpriteDepth)) / 10000.0f;
        }

        private static (float Weapon, float Attachment, float Beam) GetLaserDepths(
            Item weapon, Item attachment, Character? holder, bool hasGunsmithTransform, float? gunsmithDepth)
        {
            float weaponDepth = GetWeaponDrawDepth(weapon, holder);
            float attachmentDepth;
            if (hasGunsmithTransform)
            {
                float baseDepth = weapon.activeSprite?.Depth ?? weapon.Sprite?.Depth ?? attachment.Sprite?.Depth ?? 0.0f;
                attachmentDepth = weaponDepth + ((gunsmithDepth ?? baseDepth) - baseDepth);
            }
            else
            {
                attachmentDepth = GetContainedDrawDepth(weapon, attachment, weaponDepth);
            }

            // A front-rail beam must stay in front of the gun even for sub-millionth container offsets.
            float beamDepth = attachmentDepth + 0.000001f;
            if (attachmentDepth < weaponDepth) { beamDepth = Math.Min(beamDepth, weaponDepth); }
            return (weaponDepth, attachmentDepth, MathHelper.Clamp(beamDepth, 0.0f, 1.0f));
        }

        private static bool TryGetLaserTransform(
            Item weaponItem,
            Item laserItem,
            out bool hasGunsmithTransform,
            out bool hasGunsmithDrawTransform,
            out Vector2 startWorld,
            out Vector2 directionWorld,
            out Vector2 attachmentDrawPosition,
            out float attachmentDrawRotation,
            out float attachmentFacingDirection)
        {
            hasGunsmithTransform = TryGetGunsmithTransformPayload(weaponItem, laserItem, out object transform);
            hasGunsmithDrawTransform = false;
            startWorld = default;
            directionWorld = default;
            attachmentDrawPosition = default;
            attachmentDrawRotation = 0.0f;
            attachmentFacingDirection = 0.0f;

            if (hasGunsmithTransform)
            {
                if (gunsmithTransformDrawPositionProperty!.GetValue(transform) is not Vector2 drawPosition ||
                    gunsmithTransformDirectionProperty!.GetValue(transform) is not Vector2 direction)
                {
                    DebugConsole.ThrowError("DeepLaser received an invalid GunsmithFramework quick attachment transform payload.");
                    return false;
                }

                if (!IsFinite(drawPosition) ||
                    !IsFinite(direction) ||
                    direction.LengthSquared() < 0.0001f)
                {
                    DebugConsole.ThrowError("DeepLaser received a non-finite GunsmithFramework quick attachment transform.");
                    return false;
                }

                direction.Normalize();
                startWorld = drawPosition;
                directionWorld = direction;
                attachmentDrawPosition = drawPosition;

                if (gunsmithTransformDrawRotationProperty!.GetValue(transform) is not float drawRotation ||
                    gunsmithTransformFacingDirectionProperty!.GetValue(transform) is not float facingDirection)
                {
                    DebugConsole.ThrowError("DeepLaser received an invalid GunsmithFramework quick attachment draw transform payload.");
                    return true;
                }

                if (!float.IsFinite(drawRotation) || !float.IsFinite(facingDirection))
                {
                    DebugConsole.ThrowError("DeepLaser received a non-finite GunsmithFramework quick attachment draw transform.");
                    return true;
                }

                hasGunsmithDrawTransform = true;
                attachmentDrawRotation = drawRotation;
                attachmentFacingDirection = facingDirection;
                return true;
            }

            startWorld = laserItem.DrawPosition;
            if (!IsFinite(startWorld) || startWorld == Vector2.Zero)
            {
                startWorld = laserItem.WorldPosition;
            }
            if (!IsFinite(startWorld)) { return false; }

            if (weaponItem.body == null) { return false; }

            float rotation = weaponItem.body.DrawRotation;
            directionWorld = new Vector2(MathF.Cos(rotation), MathF.Sin(rotation));
            if (weaponItem.body.Dir != 1.0f) { directionWorld = -directionWorld; }
            if (directionWorld.LengthSquared() < 0.0001f) { return false; }
            directionWorld.Normalize();
            return true;
        }

        private static bool TryGetGunsmithAttachmentDepth(Item weaponItem, Item attachmentItem, out float depth)
        {
            depth = 0.0f;
            if (!TryResolveGunsmithDepthApi())
            {
                return false;
            }

            object?[] args = { weaponItem, attachmentItem, 0.0f };
            if (gunsmithTryGetAttachmentDepthMethod!.Invoke(null, args) is not true ||
                args[2] is not float resolvedDepth ||
                !float.IsFinite(resolvedDepth))
            {
                return false;
            }

            depth = resolvedDepth;
            return true;
        }

        private static bool TryGetGunsmithTransformPayload(Item weaponItem, Item attachmentItem, out object transform)
        {
            transform = null!;
            if (!TryResolveGunsmithTransformApi())
            {
                return false;
            }

            object?[] args = { weaponItem, attachmentItem, null };
            if (gunsmithTryGetTransformMethod!.Invoke(null, args) is not true)
            {
                return false;
            }

            transform = args[2]!;
            return transform != null;
        }

        private static bool TryResolveGunsmithDepthApi()
        {
            if (gunsmithTryGetAttachmentDepthMethod != null)
            {
                return true;
            }
            if (gunsmithDepthApiResolutionAttempted)
            {
                return false;
            }

            gunsmithDepthApiResolutionAttempted = true;
            Type? gunsmithApiType = AccessTools.TypeByName("GunsmithFramework.GunsmithApi");
            gunsmithTryGetAttachmentDepthMethod = AccessTools.Method(
                gunsmithApiType,
                "TryGetAttachmentDepth",
                new[] { typeof(Item), typeof(Item), typeof(float).MakeByRefType() });

            if (gunsmithTryGetAttachmentDepthMethod == null)
            {
                LogGunsmithTransformReflectionErrorOnce("DeepLaser failed to resolve GunsmithFramework attachment depth API.");
                return false;
            }

            return true;
        }

        private static bool TryResolveGunsmithTransformApi()
        {
            if (gunsmithTryGetTransformMethod != null &&
                gunsmithTransformDrawPositionProperty != null &&
                gunsmithTransformDrawRotationProperty != null &&
                gunsmithTransformDirectionProperty != null &&
                gunsmithTransformFacingDirectionProperty != null)
            {
                return true;
            }
            if (gunsmithTransformApiResolutionAttempted)
            {
                return false;
            }

            // ponytail: the plugin set is fixed per session; reset this only if runtime plugin hot-loading is added.
            gunsmithTransformApiResolutionAttempted = true;
            Type? serviceType = AccessTools.TypeByName("GunsmithFramework.GunsmithQuickAttachmentTransformService");
            if (serviceType == null)
            {
                return false;
            }

            gunsmithTryGetTransformMethod = serviceType
                .GetMethods(BindingFlags.Public | BindingFlags.Static)
                .FirstOrDefault(method =>
                {
                    if (method.Name != "TryGetTransform") { return false; }
                    ParameterInfo[] parameters = method.GetParameters();
                    return parameters.Length == 3 &&
                           parameters[0].ParameterType == typeof(Item) &&
                           parameters[1].ParameterType == typeof(Item) &&
                           parameters[2].IsOut;
                });

            Type? transformType = gunsmithTryGetTransformMethod?.GetParameters()[2].ParameterType.GetElementType();
            gunsmithTransformDrawPositionProperty = transformType?.GetProperty("DrawPosition", BindingFlags.Public | BindingFlags.Instance);
            gunsmithTransformDrawRotationProperty = transformType?.GetProperty("DrawRotation", BindingFlags.Public | BindingFlags.Instance);
            gunsmithTransformDirectionProperty = transformType?.GetProperty("Direction", BindingFlags.Public | BindingFlags.Instance);
            gunsmithTransformFacingDirectionProperty = transformType?.GetProperty("FacingDirection", BindingFlags.Public | BindingFlags.Instance);

            bool resolved = gunsmithTryGetTransformMethod != null &&
                            gunsmithTransformDrawPositionProperty != null &&
                            gunsmithTransformDrawRotationProperty != null &&
                            gunsmithTransformDirectionProperty != null &&
                            gunsmithTransformFacingDirectionProperty != null;
            if (!resolved)
            {
                LogGunsmithTransformReflectionErrorOnce("DeepLaser failed to resolve GunsmithFramework quick attachment transform API.");
            }

            return resolved;
        }

        private static void DrawSpriteOccluder(
            SpriteBatch spriteBatch,
            Item item,
            Vector2 drawPosition,
            float drawRotation,
            bool flipX,
            float depth)
        {
            if (item.Sprite is not { } sprite || !IsFinite(drawPosition) || !float.IsFinite(drawRotation) || !float.IsFinite(item.Scale)) { return; }

            Vector2 origin = sprite.Origin;
            if (flipX)
            {
                origin.X = sprite.SourceRect.Width - origin.X;
            }

            sprite.Draw(
                spriteBatch,
                new Vector2(drawPosition.X, -drawPosition.Y),
                Color.White,
                origin,
                -drawRotation,
                item.Scale,
                flipX ? SpriteEffects.FlipHorizontally : SpriteEffects.None,
                depth: depth);
        }

        private static void DrawImpactDot(SpriteBatch spriteBatch, Vector2 position, Color laserColor, float depth)
        {
            impactGlowTexture ??= GUI.CreateCircle(3, filled: true);
            impactCoreTexture ??= GUI.CreateCircle(2, filled: true);

            spriteBatch.Draw(
                impactGlowTexture,
                position,
                null,
                laserColor * 0.8f,
                0.0f,
                new Vector2(impactGlowTexture.Width, impactGlowTexture.Height) / 2.0f,
                1.0f,
                SpriteEffects.None,
                depth);

            spriteBatch.Draw(
                impactCoreTexture,
                position,
                null,
                laserColor * 1.2f,
                0.0f,
                new Vector2(impactCoreTexture.Width, impactCoreTexture.Height) / 2.0f,
                1.0f,
                SpriteEffects.None,
                depth);
        }

        private static Vector2? FindLaserHit(Vector2 startWorld, Vector2 endWorld, Character? shooter, Item weaponItem, Item laserItem)
        {
            LaserHit closestHit = LaserHit.None;
            Submarine? sourceSubmarine = weaponItem.Submarine ?? laserItem.Submarine;

            TryUpdateClosestHit(ref closestHit, FindLightHullHit(startWorld, endWorld, sourceSubmarine));
            TryUpdateClosestHit(ref closestHit, CastLevelRay(startWorld, endWorld));
            TryUpdateClosestHit(ref closestHit, FindCharacterHit(startWorld, endWorld, shooter));

            return closestHit.HasHit ? closestHit.WorldPosition : null;
        }

        private static LaserHit FindLightHullHit(Vector2 startWorld, Vector2 endWorld, Submarine? sourceSubmarine)
        {
            Vector2 hullQueryStart = sourceSubmarine == null ? startWorld : startWorld - sourceSubmarine.DrawPosition;
            List<ConvexHull> hulls = ConvexHull.GetHullsInRange(hullQueryStart, Vector2.Distance(startWorld, endWorld), sourceSubmarine);
            if (hulls == null || hulls.Count == 0)
            {
                return LaserHit.None;
            }

            Vector2 segment = endWorld - startWorld;
            LaserHit closestHit = LaserHit.None;

            for (int i = 0; i < hulls.Count; i++)
            {
                ConvexHull hull = hulls[i];
                if (!IsValidHull(hull)) { continue; }
                TryUpdateClosestHit(ref closestHit, FindHullHit(hull, startWorld, segment));
            }

            return closestHit;
        }

        private static bool IsValidHull(ConvexHull? hull)
        {
            if (hull == null || !hull.Enabled || hull.IsInvalid) { return false; }
            if (hull.ParentEntity is { Removed: true } or { IsHidden: true }) { return false; }
            if (hull.ParentEntity is Structure { CastShadow: false }) { return false; }
            return true;
        }

        private static LaserHit FindHullHit(ConvexHull hull, Vector2 startWorld, Vector2 segment)
        {
            // The main thread maintains Pos. The lighting worker consumes cached segment coordinates.
            SegmentPoint[]? rawVertices = hull.vertices;
            if (rawVertices == null || rawVertices.Length < 3) { return LaserHit.None; }

            Vector2 hullOffset = hull.ParentEntity?.Submarine?.DrawPosition ?? Vector2.Zero;
            if (!IsFinite(hullOffset)) { return LaserHit.None; }

            Vector2 firstVertex = rawVertices[0].Pos + hullOffset;
            if (!IsFinite(firstVertex)) { return LaserHit.None; }

            Vector2 previousVertex = firstVertex;
            bool startInsideHull = false;
            LaserHit hullHit = LaserHit.None;
            for (int i = 1; i <= rawVertices.Length; i++)
            {
                Vector2 currentVertex = i == rawVertices.Length
                    ? firstVertex
                    : rawVertices[i].Pos + hullOffset;
                if (!IsFinite(currentVertex)) { return LaserHit.None; }

                if (TryGetSegmentIntersectionFraction(startWorld, segment, previousVertex, currentVertex, out float fraction))
                {
                    TryUpdateClosestHit(ref hullHit, new LaserHit(startWorld + segment * fraction, fraction));
                }

                if ((currentVertex.Y > startWorld.Y) != (previousVertex.Y > startWorld.Y))
                {
                    float intersectX = (previousVertex.X - currentVertex.X) *
                        (startWorld.Y - currentVertex.Y) /
                        (previousVertex.Y - currentVertex.Y) +
                        currentVertex.X;
                    if (startWorld.X < intersectX)
                    {
                        startInsideHull = !startInsideHull;
                    }
                }

                previousVertex = currentVertex;
            }

            return startInsideHull ? new LaserHit(startWorld, 0.0f) : hullHit;
        }

        private static LaserHit CastLevelRay(Vector2 startWorld, Vector2 endWorld)
        {
            LaserHit closestHit = LaserHit.None;
            Vector2 startSim = ConvertUnits.ToSimUnits(startWorld);
            Vector2 endSim = ConvertUnits.ToSimUnits(endWorld);

            GameMain.World.RayCast((fixture, point, normal, fraction) =>
            {
                if (fixture == null || fixture.IsSensor) { return -1; }
                if (fixture.Body == null) { return -1; }
                if (fixture.Body.UserData as string == "ruinroom") { return -1; }

                if (!closestHit.HasHit || fraction < closestHit.Fraction)
                {
                    closestHit = new LaserHit(ConvertUnits.ToDisplayUnits(point), fraction);
                }

                return fraction;
            }, startSim, endSim, Physics.CollisionLevel);

            return closestHit;
        }

        private static bool TryGetSegmentIntersectionFraction(Vector2 start, Vector2 segment, Vector2 edgeStart, Vector2 edgeEnd, out float fraction)
        {
            fraction = 0.0f;
            Vector2 edgeSegment = edgeEnd - edgeStart;
            float cross = Cross(segment, edgeSegment);
            if (Math.Abs(cross) < 0.0001f) { return false; }

            Vector2 diff = edgeStart - start;
            float rayFraction = Cross(diff, edgeSegment) / cross;
            float edgeFraction = Cross(diff, segment) / cross;
            if (rayFraction is < 0.0f or > 1.0f || edgeFraction is < 0.0f or > 1.0f)
            {
                return false;
            }

            fraction = rayFraction;
            return true;
        }

        private static float Cross(Vector2 a, Vector2 b)
        {
            return a.X * b.Y - a.Y * b.X;
        }

        private static void LogGunsmithTransformReflectionErrorOnce(string message)
        {
            if (loggedGunsmithTransformReflectionError) { return; }
            loggedGunsmithTransformReflectionError = true;
            DebugConsole.ThrowError(message);
        }

        private static LaserHit FindCharacterHit(Vector2 startWorld, Vector2 endWorld, Character? shooter)
        {
            Vector2 segment = endWorld - startWorld;
            float length = segment.Length();
            if (length < 0.001f) { return LaserHit.None; }

            Vector2 direction = segment / length;
            LaserHit closestHit = LaserHit.None;

            foreach (Character character in Character.CharacterList)
            {
                if (character == shooter || character.Removed || !character.Enabled || character.IsDead || character.InvisibleTimer > 0.0f) { continue; }

                var controller = character.AnimController;
                if (controller?.Limbs is not { Length: > 0 } limbs)
                {
                    if (controller?.Collider is { Enabled: true } collider)
                    {
                        collider.UpdateDrawPosition();
                        if (TryIntersectCircle(startWorld, direction, length, collider.DrawPosition, 35.0f, out float fraction))
                        {
                            TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + segment * fraction, fraction));
                        }
                    }
                    continue;
                }

                foreach (Limb limb in limbs)
                {
                    if (!IsValidLaserBlockingLimb(limb)) { continue; }

                    float radius = GetLimbHitRadius(limb);
                    if (TryIntersectCircle(startWorld, direction, length, limb.DrawPosition, radius, out float fraction))
                    {
                        TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (fraction * length), fraction));
                    }
                }

                if (controller.LimbJoints != null)
                {
                    foreach (var joint in controller.LimbJoints)
                    {
                        if (joint == null || joint.IsSevered) { continue; }
                        Limb limbA = joint.LimbA;
                        Limb limbB = joint.LimbB;
                        if (!IsValidLaserBlockingLimb(limbA) || !IsValidLaserBlockingLimb(limbB)) { continue; }

                        float radius = MathHelper.Clamp(Math.Min(GetLimbHitRadius(limbA), GetLimbHitRadius(limbB)) * 0.55f, 8.0f, 28.0f);
                        if (TryIntersectCapsule(startWorld, direction, length, limbA.DrawPosition, limbB.DrawPosition, radius, out float fraction))
                        {
                            TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (fraction * length), fraction));
                        }
                    }
                }
            }

            return closestHit;
        }

        private static bool IsValidLaserBlockingLimb(Limb? limb)
        {
            return limb is { Removed: false, IsSevered: false, Hidden: false, Alpha: > 0, body.Enabled: true };
        }

        private static float GetLimbHitRadius(Limb limb)
        {
            if (limb.body == null) { return 18.0f; }

            float simRadius = Math.Max(limb.body.Radius, Math.Max(limb.body.Width, limb.body.Height) * 0.5f);
            float radius = ConvertUnits.ToDisplayUnits(simRadius);
            return MathHelper.Clamp(radius, 10.0f, 45.0f);
        }

        private static bool TryIntersectCircle(Vector2 rayStart, Vector2 rayDirection, float rayLength, Vector2 center, float radius, out float fraction)
        {
            fraction = 0.0f;
            Vector2 toCenter = center - rayStart;
            if (toCenter.LengthSquared() <= radius * radius) { return true; }

            float perpendicular = Cross(toCenter, rayDirection);
            float chordSquared = radius * radius - perpendicular * perpendicular;
            if (chordSquared < 0.0f) { return false; }
            float entry = Vector2.Dot(toCenter, rayDirection) - MathF.Sqrt(chordSquared);
            if (entry < 0.0f || entry > rayLength || rayLength <= 0.0f) { return false; }
            fraction = entry / rayLength;
            return true;
        }

        private static bool TryIntersectCapsule(Vector2 rayStart, Vector2 rayDirection, float rayLength, Vector2 capsuleStart, Vector2 capsuleEnd, float radius, out float fraction)
        {
            Vector2 axis = capsuleEnd - capsuleStart;
            float axisLength = axis.Length();
            if (axisLength == 0.0f) { return TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleStart, radius, out fraction); }
            axis /= axisLength;

            Vector2 fromStart = rayStart - capsuleStart;
            float along = Vector2.Dot(fromStart, axis);
            float across = Cross(axis, fromStart);
            fraction = 0.0f;
            if (along >= 0.0f && along <= axisLength && MathF.Abs(across) <= radius) { return true; }

            float nearest = float.PositiveInfinity;
            float normalSpeed = Cross(axis, rayDirection);
            if (normalSpeed != 0.0f && rayLength > 0.0f)
            {
                float distance = (MathF.CopySign(radius, across) - across) / normalSpeed;
                float onAxis = along + distance * Vector2.Dot(rayDirection, axis);
                if (distance >= 0.0f && distance <= rayLength && onAxis >= 0.0f && onAxis <= axisLength)
                {
                    nearest = distance / rayLength;
                }
            }
            if (TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleStart, radius, out float first)) { nearest = Math.Min(nearest, first); }
            if (TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleEnd, radius, out float last)) { nearest = Math.Min(nearest, last); }
            if (!float.IsFinite(nearest)) { return false; }
            fraction = nearest;
            return true;
        }

        private static void TryUpdateClosestHit(ref LaserHit closestHit, LaserHit candidate)
        {
            if (!candidate.HasHit) { return; }

            if (!closestHit.HasHit || candidate.Fraction < closestHit.Fraction)
            {
                closestHit = candidate;
            }
        }

        private struct LaserFrameData
        {
            public Item WeaponItem;
            public Item LaserItem;
            public float WeaponDepth;
            public Color Color;
            public Vector2 StartWorld;
            public Vector2 EndWorld;
            public Vector2 StartDraw;
            public Vector2 EndDraw;
            public float BeamDepth;
            public bool HitObstacle;
            public bool HasGunsmithDrawTransform;
            public Vector2 AttachmentDrawPosition;
            public float AttachmentDrawRotation;
            public float AttachmentFacingDirection;
            public float AttachmentDepth;
        }

        private readonly struct LaserHit
        {
            public static LaserHit None => new(Vector2.Zero, 1.0f, false);

            public readonly Vector2 WorldPosition;
            public readonly float Fraction;
            public readonly bool HasHit;

            public LaserHit(Vector2 position, float fraction)
            {
                WorldPosition = position;
                Fraction = fraction;
                HasHit = true;
            }

            private LaserHit(Vector2 position, float fraction, bool hasHit)
            {
                WorldPosition = position;
                Fraction = fraction;
                HasHit = hasHit;
            }
        }

        private static bool IsFinite(Vector2 value)
        {
            return float.IsFinite(value.X) && float.IsFinite(value.Y);
        }
    }
}
