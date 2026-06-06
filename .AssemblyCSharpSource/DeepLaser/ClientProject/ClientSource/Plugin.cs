using Barotrauma.Items.Components;
using FarseerPhysics;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;
using System.Reflection;

namespace DeepLaser
{
    public partial class DeepLaser : IAssemblyPlugin
    {
        private const float MaxLaserLength = 4000.0f;
        private static readonly (string Tag, Color Color)[] LaserColors =
        {
            ("red_laser", new Color(255, 32, 32, 120)),
            ("green_laser", new Color(32, 255, 64, 120)),
            ("blue_laser", new Color(64, 128, 255, 120))
        };

        private static readonly Type? ConvexHullType = AccessTools.TypeByName("Barotrauma.Lights.ConvexHull");
        private static readonly Type? SegmentPointType = AccessTools.TypeByName("Barotrauma.Lights.SegmentPoint");
        private static readonly MethodInfo? GetHullsInRangeMethod = AccessMethod(ConvexHullType, "GetHullsInRange");
        private static readonly PropertyInfo? HullEnabledProperty = AccessProperty(ConvexHullType, "Enabled");
        private static readonly PropertyInfo? HullIsInvalidProperty = AccessProperty(ConvexHullType, "IsInvalid");
        private static readonly FieldInfo? HullVerticesField = AccessField(ConvexHullType, "vertices");
        private static readonly FieldInfo? SegmentPointWorldPosField = AccessField(SegmentPointType, "WorldPos");
        private static bool loggedHullReflectionError;
        private static MethodInfo? gunsmithTryGetTransformMethod;
        private static MethodInfo? gunsmithTryGetAttachmentDepthMethod;
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
        private static bool renderingDistortedLaserOverlay;
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
        private static MethodInfo? AccessMethod(Type? type, string name)
        {
            return type == null ? null : AccessTools.Method(type, name);
        }

        private static PropertyInfo? AccessProperty(Type? type, string name)
        {
            return type == null ? null : AccessTools.Property(type, name);
        }

        private static FieldInfo? AccessField(Type? type, string name)
        {
            return type == null ? null : AccessTools.Field(type, name);
        }

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
                if (renderingDistortedLaserOverlay || laserOverlayTarget == null || laserOverlayTarget.IsDisposed) { return; }

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
            distortedLaserOverlayReady = false;
            RenderTargetBinding[] sceneTargets = graphicsDevice.GetRenderTargets();
            int targetWidth = graphicsDevice.PresentationParameters.BackBufferWidth;
            int targetHeight = graphicsDevice.PresentationParameters.BackBufferHeight;

            if (sceneTargets.Length > 0 && sceneTargets[0].RenderTarget is Texture2D sceneTarget)
            {
                targetWidth = sceneTarget.Width;
                targetHeight = sceneTarget.Height;
            }

            RenderTarget2D overlayTarget = GetLaserOverlayTarget(graphicsDevice, targetWidth, targetHeight);

            graphicsDevice.SetRenderTarget(overlayTarget);
            graphicsDevice.Clear(ClearOptions.Target | ClearOptions.DepthBuffer, Color.Transparent, 1.0f, 0);

            // Store the source color and alpha once; the final composite performs the original blending.
            spriteBatch.Begin(SpriteSortMode.Deferred, BlendState.Opaque, GUI.SamplerState, LaserDepthWriteState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
            DrawLasers(spriteBatch, drawImpactDot: false);
            spriteBatch.End();

            spriteBatch.Begin(SpriteSortMode.Deferred, null, GUI.SamplerState, LaserDepthWriteState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
            DrawLasers(spriteBatch, drawBeam: false);
            spriteBatch.End();

            spriteBatch.Begin(SpriteSortMode.Deferred, LaserEraseBlendState, GUI.SamplerState, LaserOccluderDepthState, GameMain.ScissorTestEnable, transformMatrix: gameScreen.Cam.Transform);
            DrawWorldOccluders(spriteBatch);
            DrawLaserOccluders(spriteBatch);
            spriteBatch.End();

            if (sceneTargets.Length == 0)
            {
                graphicsDevice.SetRenderTarget(null);
            }
            else
            {
                graphicsDevice.SetRenderTargets(sceneTargets);
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
            foreach (MapEntity mapEntity in Submarine.VisibleEntities)
            {
                if (mapEntity == null || mapEntity.Removed) { continue; }
                if (mapEntity is Item item &&
                    (item.HasTag("deep_gunsmith") ||
                     (item.GetComponent<RangedWeapon>() != null && TryFindLaser(item, out _, out _))))
                {
                    continue;
                }

                mapEntity.Draw(spriteBatch, false, true);
                mapEntity.Draw(spriteBatch, false, false);
            }
        }

        private static void DrawLaserOccluders(SpriteBatch spriteBatch)
        {
            HashSet<Item> drawnWeapons = new();

            foreach (Character character in Character.CharacterList)
            {
                if (character.Removed || !character.Enabled) { continue; }

                foreach (Item weaponItem in character.HeldItems)
                {
                    if (weaponItem == null || !drawnWeapons.Add(weaponItem)) { continue; }

                    DrawWeaponOccluder(weaponItem, spriteBatch, character);
                }
            }

            foreach (Item weaponItem in Item.ItemList)
            {
                if (weaponItem == null || weaponItem.Removed || weaponItem.ParentInventory != null || !drawnWeapons.Add(weaponItem)) { continue; }

                DrawWeaponOccluder(weaponItem, spriteBatch, holder: null);
            }
        }

        private static void DrawWeaponOccluder(Item weaponItem, SpriteBatch spriteBatch, Character? holder)
        {
            if (weaponItem.GetComponent<RangedWeapon>() == null ||
                !TryFindLaser(weaponItem, out Item? laserItem, out _) ||
                laserItem == null)
            {
                return;
            }

            weaponItem.body?.UpdateDrawPosition();
            if (TryGetGunsmithAttachmentDrawTransform(weaponItem, laserItem, out Vector2 gunsmithDrawPosition, out float gunsmithDrawRotation, out float gunsmithFacingDirection))
            {
                float gunsmithAttachmentDepth = laserItem.Sprite?.Depth ?? weaponItem.activeSprite?.Depth ?? weaponItem.Sprite?.Depth ?? 0.0f;
                if (TryGetGunsmithAttachmentDepth(weaponItem, laserItem, out float resolvedAttachmentDepth))
                {
                    gunsmithAttachmentDepth = resolvedAttachmentDepth;
                }

                DrawWeaponSpriteOccluder(spriteBatch, weaponItem, gunsmithFacingDirection);
                DrawSpriteOccluder(
                    spriteBatch,
                    laserItem,
                    gunsmithDrawPosition,
                    gunsmithDrawRotation,
                    gunsmithFacingDirection < 0.0f ? SpriteEffects.FlipHorizontally : SpriteEffects.None,
                    mirrorOriginForHorizontalFlip: gunsmithFacingDirection < 0.0f,
                    depthOverride: gunsmithAttachmentDepth);
                return;
            }

            weaponItem.SetContainedItemPositions();
            bool isOuterRail = laserItem.Sprite != null &&
                weaponItem.Sprite != null &&
                laserItem.Sprite.Depth < weaponItem.Sprite.Depth;
            if (isOuterRail)
            {
                DrawItemSpriteOccluder(spriteBatch, weaponItem, laserItem);
                return;
            }

            weaponItem.Draw(spriteBatch, false, true, Color.White, null);
            weaponItem.Draw(spriteBatch, false, false, Color.White, null);
            if (holder?.IsClimbing == true && weaponItem.body?.Dir == -1.0f)
            {
                DrawItemSpriteOccluder(spriteBatch, weaponItem, weaponItem);
                DrawItemSpriteOccluder(spriteBatch, weaponItem, laserItem);
            }
        }

        private static void DrawItemSpriteOccluder(SpriteBatch spriteBatch, Item weaponItem, Item occluderItem)
        {
            if (occluderItem.Sprite == null) { return; }

            bool flipX = weaponItem.body?.Dir == -1.0f;
            DrawSpriteOccluder(
                spriteBatch,
                occluderItem,
                occluderItem.DrawPosition,
                occluderItem.body?.DrawRotation ?? 0.0f,
                flipX ? SpriteEffects.FlipHorizontally : SpriteEffects.None,
                mirrorOriginForHorizontalFlip: flipX);
        }

        private static void DrawLasers(SpriteBatch spriteBatch, bool drawBeam = true, bool drawImpactDot = true)
        {
            HashSet<Item> drawnWeapons = new();

            foreach (Character character in Character.CharacterList)
            {
                if (character.Removed || !character.Enabled) { continue; }

                foreach (Item weaponItem in character.HeldItems)
                {
                    if (weaponItem == null || !drawnWeapons.Add(weaponItem)) { continue; }

                    RangedWeapon? rangedWeapon = weaponItem.GetComponent<RangedWeapon>();
                    if (rangedWeapon == null) { continue; }

                    TryDrawWeaponLaser(rangedWeapon, spriteBatch, character, drawBeam, drawImpactDot);
                }
            }

            foreach (Item weaponItem in Item.ItemList)
            {
                if (weaponItem == null || weaponItem.Removed || weaponItem.ParentInventory != null || !drawnWeapons.Add(weaponItem)) { continue; }

                RangedWeapon? rangedWeapon = weaponItem.GetComponent<RangedWeapon>();
                if (rangedWeapon == null) { continue; }

                TryDrawWeaponLaser(rangedWeapon, spriteBatch, character: null, drawBeam, drawImpactDot);
            }
        }

        private static void TryDrawWeaponLaser(RangedWeapon rangedWeapon, SpriteBatch spriteBatch, Character? character, bool drawBeam, bool drawImpactDot)
        {
            Item weaponItem = rangedWeapon.Item;
            if (!TryFindLaser(weaponItem, out Item? laserItem, out Color laserColor) || laserItem == null) { return; }

            weaponItem.body?.UpdateDrawPosition();
            DrawLaser(rangedWeapon, spriteBatch, character, laserItem, laserColor, drawBeam, drawImpactDot);
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
                if (item.HasTag(tag))
                {
                    color = mappedColor;
                    return true;
                }
            }

            color = Color.Transparent;
            return false;
        }

        private static void DrawLaser(RangedWeapon rangedWeapon, SpriteBatch spriteBatch, Character? character, Item laserItem, Color laserColor, bool drawBeam, bool drawImpactDot)
        {
            if (rangedWeapon.Item.body == null) { return; }

            bool hasGunsmithTransform = TryGetGunsmithTransformPayload(rangedWeapon.Item, laserItem, out _);
            if (!TryGetLaserStartAndDirection(rangedWeapon.Item, laserItem, out Vector2 startWorld, out Vector2 directionWorld))
            {
                return;
            }

            Vector2 endWorld = startWorld + directionWorld * MaxLaserLength;

            Vector2? hitPositionWorld = FindLaserHit(startWorld, endWorld, character, rangedWeapon.Item, laserItem);
            bool hitObstacle = hitPositionWorld.HasValue;
            if (hitPositionWorld.HasValue)
            {
                endWorld = hitPositionWorld.Value;
            }

            Vector2 startDraw = new(startWorld.X, -startWorld.Y);
            Vector2 endDraw = new(endWorld.X, -endWorld.Y);
            if (!IsFinite(startDraw) || !IsFinite(endDraw)) { return; }

            float laserDepth;
            if (hasGunsmithTransform && TryGetGunsmithAttachmentDepth(rangedWeapon.Item, laserItem, out float attachmentDepth))
            {
                laserDepth = MathHelper.Clamp(attachmentDepth + 0.001f, 0.0f, 0.999f);
            }
            else
            {
                float baseDepth = hasGunsmithTransform
                    ? (rangedWeapon.Item.activeSprite?.Depth ?? rangedWeapon.Item.Sprite?.Depth ?? laserItem.Sprite?.Depth ?? 0.0f)
                    : (laserItem.Sprite?.Depth ?? 0.0f);
                laserDepth = MathHelper.Clamp(baseDepth + 0.001f, 0.0f, 0.999f);
            }

            if (drawBeam)
            {
                GUI.DrawLine(spriteBatch, startDraw, endDraw, laserColor, depth: laserDepth, width: 1.0f);
            }

            if (hitObstacle && drawImpactDot)
            {
                DrawImpactDot(spriteBatch, endDraw, laserColor, laserDepth);
            }
        }

        private static bool TryGetLaserStartAndDirection(Item weaponItem, Item laserItem, out Vector2 startWorld, out Vector2 directionWorld)
        {
            if (TryGetGunsmithLaserTransform(weaponItem, laserItem, out startWorld, out directionWorld))
            {
                return true;
            }

            startWorld = laserItem.DrawPosition;
            if (!IsFinite(startWorld) || startWorld == Vector2.Zero)
            {
                startWorld = laserItem.WorldPosition;
            }
            if (!IsFinite(startWorld)) { return false; }

            if (weaponItem.body == null) { return false; }

            float rotation = weaponItem.body.Dir == 1.0f
                ? weaponItem.body.Rotation
                : weaponItem.body.Rotation - MathHelper.Pi;

            directionWorld = new Vector2(MathF.Cos(rotation), MathF.Sin(rotation));
            if (directionWorld.LengthSquared() < 0.0001f) { return false; }
            directionWorld.Normalize();
            return true;
        }

        private static bool TryGetGunsmithLaserTransform(Item weaponItem, Item laserItem, out Vector2 startWorld, out Vector2 directionWorld)
        {
            startWorld = default;
            directionWorld = default;

            if (!TryGetGunsmithTransformPayload(weaponItem, laserItem, out object transform))
            {
                return false;
            }

            if (gunsmithTransformDrawPositionProperty!.GetValue(transform) is not Vector2 drawPosition ||
                gunsmithTransformDirectionProperty!.GetValue(transform) is not Vector2 direction)
            {
                DebugConsole.ThrowError("DeepLaser received an invalid GunsmithFramework quick attachment transform payload.");
                return false;
            }

            if (!IsFinite(drawPosition) || !IsFinite(direction) || direction.LengthSquared() < 0.0001f)
            {
                DebugConsole.ThrowError("DeepLaser received a non-finite GunsmithFramework quick attachment transform.");
                return false;
            }

            direction.Normalize();
            startWorld = drawPosition;
            directionWorld = direction;
            return true;
        }

        private static bool TryGetGunsmithAttachmentDrawTransform(Item weaponItem, Item attachmentItem, out Vector2 drawPosition, out float drawRotation, out float facingDirection)
        {
            drawPosition = default;
            drawRotation = 0.0f;
            facingDirection = 0.0f;

            if (!TryGetGunsmithTransformPayload(weaponItem, attachmentItem, out object transform))
            {
                return false;
            }

            if (gunsmithTransformDrawPositionProperty!.GetValue(transform) is not Vector2 payloadDrawPosition ||
                gunsmithTransformDrawRotationProperty!.GetValue(transform) is not float payloadDrawRotation ||
                gunsmithTransformFacingDirectionProperty!.GetValue(transform) is not float payloadFacingDirection)
            {
                DebugConsole.ThrowError("DeepLaser received an invalid GunsmithFramework quick attachment draw transform payload.");
                return false;
            }

            if (!IsFinite(payloadDrawPosition) || !float.IsFinite(payloadDrawRotation) || !float.IsFinite(payloadFacingDirection))
            {
                DebugConsole.ThrowError("DeepLaser received a non-finite GunsmithFramework quick attachment draw transform.");
                return false;
            }

            drawPosition = payloadDrawPosition;
            drawRotation = payloadDrawRotation;
            facingDirection = payloadFacingDirection;
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
            Item occluderItem,
            Vector2 drawPosition,
            float drawRotation,
            SpriteEffects effects,
            bool mirrorOriginForHorizontalFlip = false,
            float? depthOverride = null)
        {
            if (occluderItem.Sprite == null || !IsFinite(drawPosition) || !float.IsFinite(drawRotation)) { return; }

            DrawSpriteOccluder(
                spriteBatch,
                occluderItem.Sprite,
                occluderItem.Scale,
                drawPosition,
                drawRotation,
                effects,
                mirrorOriginForHorizontalFlip,
                depthOverride);
        }

        private static void DrawWeaponSpriteOccluder(SpriteBatch spriteBatch, Item weaponItem, float facingDirection)
        {
            Sprite? weaponSprite = weaponItem.activeSprite ?? weaponItem.Sprite;
            Vector2 drawPosition = weaponItem.body?.DrawPosition ?? weaponItem.DrawPosition;
            float drawRotation = weaponItem.body?.DrawRotation ?? -weaponItem.RotationRad;
            if (weaponSprite == null || !IsFinite(drawPosition) || !float.IsFinite(drawRotation)) { return; }

            DrawSpriteOccluder(
                spriteBatch,
                weaponSprite,
                weaponItem.Scale,
                drawPosition,
                drawRotation,
                facingDirection < 0.0f ? SpriteEffects.FlipHorizontally : SpriteEffects.None,
                mirrorOriginForHorizontalFlip: facingDirection < 0.0f);
        }

        private static void DrawSpriteOccluder(
            SpriteBatch spriteBatch,
            Sprite sprite,
            float scale,
            Vector2 drawPosition,
            float drawRotation,
            SpriteEffects effects,
            bool mirrorOriginForHorizontalFlip = false,
            float? depthOverride = null)
        {
            if (sprite == null || !IsFinite(drawPosition) || !float.IsFinite(drawRotation) || !float.IsFinite(scale)) { return; }

            Vector2 origin = sprite.Origin;
            if (mirrorOriginForHorizontalFlip)
            {
                origin.X = sprite.SourceRect.Width - origin.X;
            }

            sprite.Draw(
                spriteBatch,
                new Vector2(drawPosition.X, -drawPosition.Y),
                Color.White,
                origin,
                -drawRotation,
                scale,
                effects,
                depth: depthOverride ?? sprite.Depth);
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
                depth - 0.0001f);
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
            if (!TryGetHullsInRange(hullQueryStart, Vector2.Distance(startWorld, endWorld), sourceSubmarine, out System.Collections.IEnumerable? hulls) || hulls == null)
            {
                return LaserHit.None;
            }

            Vector2 segment = endWorld - startWorld;
            LaserHit closestHit = LaserHit.None;

            foreach (object hull in hulls)
            {
                if (!IsValidHull(hull)) { continue; }
                if (!TryGetHullVertices(hull, out Vector2[] vertices)) { continue; }

                for (int i = 0; i < vertices.Length; i++)
                {
                    Vector2 edgeStart = vertices[i];
                    Vector2 edgeEnd = vertices[(i + 1) % vertices.Length];
                    if (TryGetSegmentIntersectionFraction(startWorld, segment, edgeStart, edgeEnd, out float fraction))
                    {
                        TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + segment * fraction, fraction));
                    }
                }

                if (!closestHit.HasHit && IsPointInsidePolygon(startWorld, vertices))
                {
                    TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld, 0.0f));
                }
            }

            return closestHit;
        }

        private static bool TryGetHullsInRange(Vector2 startWorld, float range, Submarine? sourceSubmarine, out System.Collections.IEnumerable? hulls)
        {
            hulls = null;
            if (GetHullsInRangeMethod == null)
            {
                LogHullReflectionErrorOnce("DeepLaser failed to find Barotrauma.Lights.ConvexHull.GetHullsInRange.");
                return false;
            }

            hulls = GetHullsInRangeMethod.Invoke(null, new object?[] { startWorld, range, sourceSubmarine }) as System.Collections.IEnumerable;
            return hulls != null;
        }

        private static bool IsValidHull(object hull)
        {
            if (HullEnabledProperty?.GetValue(hull) is bool enabled && !enabled) { return false; }
            if (HullIsInvalidProperty?.GetValue(hull) is bool isInvalid && isInvalid) { return false; }
            return true;
        }

        private static bool TryGetHullVertices(object hull, out Vector2[] vertices)
        {
            vertices = Array.Empty<Vector2>();
            if (HullVerticesField == null || SegmentPointWorldPosField == null)
            {
                LogHullReflectionErrorOnce("DeepLaser failed to find light hull vertex reflection members.");
                return false;
            }

            // RefreshWorldPositions mutates SegmentPoint.WorldPos, which the game's ray-cast sorting
            // also reads on another thread. Snapshot the current world positions without writing them.
            if (HullVerticesField.GetValue(hull) is not Array rawVertices || rawVertices.Length < 3) { return false; }

            List<Vector2> result = new(rawVertices.Length);
            for (int i = 0; i < rawVertices.Length; i++)
            {
                object? vertex = rawVertices.GetValue(i);
                if (vertex == null) { return false; }
                if (SegmentPointWorldPosField.GetValue(vertex) is not Vector2 worldPos || !IsFinite(worldPos)) { return false; }
                result.Add(worldPos);
            }

            vertices = result.ToArray();
            return true;
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

        private static bool IsPointInsidePolygon(Vector2 point, Vector2[] vertices)
        {
            bool inside = false;
            for (int i = 0, j = vertices.Length - 1; i < vertices.Length; j = i++)
            {
                Vector2 a = vertices[i];
                Vector2 b = vertices[j];
                if ((a.Y > point.Y) != (b.Y > point.Y))
                {
                    float intersectX = (b.X - a.X) * (point.Y - a.Y) / (b.Y - a.Y) + a.X;
                    if (point.X < intersectX)
                    {
                        inside = !inside;
                    }
                }
            }

            return inside;
        }

        private static void LogHullReflectionErrorOnce(string message)
        {
            if (loggedHullReflectionError) { return; }
            loggedHullReflectionError = true;
            DebugConsole.ThrowError(message);
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

                bool checkedLimbs = false;
                if (character.AnimController?.Limbs != null)
                {
                    foreach (Limb limb in character.AnimController.Limbs)
                    {
                        if (!IsValidLaserBlockingLimb(limb)) { continue; }

                        checkedLimbs = true;
                        float radius = GetLimbHitRadius(limb);
                        if (TryIntersectCircle(startWorld, direction, length, limb.WorldPosition, radius, out float fraction))
                        {
                            TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (fraction * length), fraction));
                        }
                    }

                    if (character.AnimController.LimbJoints != null)
                    {
                        foreach (var joint in character.AnimController.LimbJoints)
                        {
                            if (joint == null || joint.IsSevered) { continue; }
                            Limb limbA = joint.LimbA;
                            Limb limbB = joint.LimbB;
                            if (!IsValidLaserBlockingLimb(limbA) || !IsValidLaserBlockingLimb(limbB)) { continue; }

                            float radius = MathHelper.Clamp(Math.Min(GetLimbHitRadius(limbA), GetLimbHitRadius(limbB)) * 0.55f, 8.0f, 28.0f);
                            if (TryIntersectCapsule(startWorld, direction, length, limbA.WorldPosition, limbB.WorldPosition, radius, out float fraction))
                            {
                                TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (fraction * length), fraction));
                            }
                        }
                    }
                }

                if (!checkedLimbs && TryIntersectCircle(startWorld, direction, length, character.WorldPosition, 35.0f, out float characterFraction))
                {
                    TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (characterFraction * length), characterFraction));
                }
            }

            return closestHit;
        }

        private static bool IsValidLaserBlockingLimb(Limb? limb)
        {
            return limb != null && !limb.Removed && !limb.IsSevered && limb.body != null;
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
            Vector2 toCenter = center - rayStart;
            float projectedDistance = Vector2.Dot(toCenter, rayDirection);
            if (projectedDistance < 0.0f || projectedDistance > rayLength)
            {
                fraction = 0.0f;
                return false;
            }

            float distanceSquared = toCenter.LengthSquared() - projectedDistance * projectedDistance;
            float radiusSquared = radius * radius;
            if (distanceSquared > radiusSquared)
            {
                fraction = 0.0f;
                return false;
            }

            float offset = MathF.Sqrt(Math.Max(0.0f, radiusSquared - distanceSquared));
            float hitDistance = Math.Max(0.0f, projectedDistance - offset);
            if (hitDistance > rayLength)
            {
                fraction = 0.0f;
                return false;
            }

            fraction = hitDistance / rayLength;
            return true;
        }

        private static bool TryIntersectCapsule(Vector2 rayStart, Vector2 rayDirection, float rayLength, Vector2 capsuleStart, Vector2 capsuleEnd, float radius, out float fraction)
        {
            Vector2 capsuleSegment = capsuleEnd - capsuleStart;
            float capsuleLengthSquared = capsuleSegment.LengthSquared();
            if (capsuleLengthSquared < 0.001f)
            {
                return TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleStart, radius, out fraction);
            }

            if (TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleStart, radius, out fraction) ||
                TryIntersectCircle(rayStart, rayDirection, rayLength, capsuleEnd, radius, out fraction))
            {
                return true;
            }

            Vector2 raySegment = rayDirection * rayLength;
            if (TryGetSegmentIntersectionFraction(rayStart, raySegment, capsuleStart, capsuleEnd, out fraction))
            {
                return true;
            }

            Vector2 relativeStart = rayStart - capsuleStart;
            float a = Vector2.Dot(raySegment, raySegment);
            float b = Vector2.Dot(raySegment, capsuleSegment);
            float c = Vector2.Dot(capsuleSegment, capsuleSegment);
            float d = Vector2.Dot(raySegment, relativeStart);
            float e = Vector2.Dot(capsuleSegment, relativeStart);
            float denominator = a * c - b * b;

            float rayFraction = denominator > 0.0001f ? MathHelper.Clamp((b * e - c * d) / denominator, 0.0f, 1.0f) : 0.0f;
            float capsuleFraction = MathHelper.Clamp((b * rayFraction + e) / c, 0.0f, 1.0f);
            rayFraction = MathHelper.Clamp((b * capsuleFraction - d) / a, 0.0f, 1.0f);

            Vector2 closestOnRay = rayStart + raySegment * rayFraction;
            Vector2 closestOnCapsule = capsuleStart + capsuleSegment * capsuleFraction;
            if (Vector2.DistanceSquared(closestOnRay, closestOnCapsule) > radius * radius)
            {
                fraction = 0.0f;
                return false;
            }

            fraction = rayFraction;
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
