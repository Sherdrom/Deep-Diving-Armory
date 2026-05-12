using Barotrauma.Items.Components;
using FarseerPhysics;
using FarseerPhysics.Dynamics;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;
using Voronoi2;

namespace DeepLaser
{
    public partial class DeepLaser : IAssemblyPlugin
    {
        private const float MaxLaserLength = 4000.0f;
        private static Texture2D? impactGlowTexture;
        private static Texture2D? impactCoreTexture;

        private static readonly (string Tag, Color Color)[] LaserColors =
        {
            ("red_laser", new Color(255, 32, 32, 80)),
            ("green_laser", new Color(32, 255, 64, 80)),
            ("blue_laser", new Color(64, 128, 255, 80))
        };

        [HarmonyPatch(typeof(Item), nameof(Item.Draw), new[] { typeof(SpriteBatch), typeof(bool), typeof(bool), typeof(Color?), typeof(float?) })]
        private static class ItemDrawPatch
        {
            private static void Postfix(Item __instance, SpriteBatch spriteBatch, bool editing)
            {
                if (editing || spriteBatch == null) { return; }
                RangedWeapon? rangedWeapon = __instance.GetComponent<RangedWeapon>();
                if (rangedWeapon == null) { return; }
                Character? holder = GetHolder(__instance);
                if (__instance.ParentInventory != null && holder == null) { return; }
                if (!TryFindLaser(__instance, out Item? laserItem, out Color laserColor) || laserItem == null) { return; }

                DrawLaser(rangedWeapon, spriteBatch, holder, laserItem, laserColor);
            }
        }

        private static Character? GetHolder(Item item)
        {
            if (item.GetRootInventoryOwner() is not Character character) { return null; }

            return character.HeldItems.Contains(item) ? character : null;
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

        private static void DrawLaser(RangedWeapon rangedWeapon, SpriteBatch spriteBatch, Character? character, Item laserItem, Color laserColor)
        {
            if (rangedWeapon.Item.body == null) { return; }

            Vector2 startWorld = laserItem.DrawPosition;
            if (!IsFinite(startWorld) || startWorld == Vector2.Zero)
            {
                startWorld = laserItem.WorldPosition;
            }
            if (!IsFinite(startWorld)) { return; }

            float rotation = rangedWeapon.Item.body.Dir == 1.0f
                ? rangedWeapon.Item.body.Rotation
                : rangedWeapon.Item.body.Rotation - MathHelper.Pi;

            Vector2 directionWorld = new(MathF.Cos(rotation), MathF.Sin(rotation));
            if (directionWorld.LengthSquared() < 0.0001f) { return; }
            directionWorld.Normalize();

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

            float laserDepth = MathHelper.Clamp((laserItem.Sprite?.Depth ?? 0.0f) + 0.001f, 0.0f, 0.999f);

            GUI.DrawLine(spriteBatch, startDraw, endDraw, laserColor , depth: laserDepth, width: 1.0f);

            if (hitObstacle)
            {
                DrawImpactDot(spriteBatch, endDraw, laserColor, laserDepth );
            }
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
            Vector2 startWorldSim = ConvertUnits.ToSimUnits(startWorld);
            Vector2 endWorldSim = ConvertUnits.ToSimUnits(endWorld);
            Submarine? sourceSubmarine = weaponItem.Submarine ?? laserItem.Submarine;

            if (sourceSubmarine != null)
            {
                TryUpdateClosestHit(
                    ref closestHit,
                    CastLaserRay(startWorldSim - sourceSubmarine.SimPosition, endWorldSim - sourceSubmarine.SimPosition, sourceSubmarine, shooter, weaponItem, laserItem),
                    sourceSubmarine.SimPosition);
            }

            TryUpdateClosestHit(
                ref closestHit,
                CastLaserRay(startWorldSim, endWorldSim, null, shooter, weaponItem, laserItem),
                Vector2.Zero);

            foreach (Submarine submarine in Submarine.Loaded)
            {
                if (submarine == sourceSubmarine) { continue; }

                TryUpdateClosestHit(
                    ref closestHit,
                    CastLaserRay(startWorldSim - submarine.SimPosition, endWorldSim - submarine.SimPosition, submarine, shooter, weaponItem, laserItem),
                    submarine.SimPosition);
            }

            TryUpdateClosestHit(ref closestHit, FindCharacterHit(startWorld, endWorld, shooter));

            return closestHit.HasHit ? closestHit.WorldPosition : null;
        }

        private static LaserHit CastLaserRay(Vector2 startSim, Vector2 endSim, Submarine? raySubmarine, Character? shooter, Item weaponItem, Item laserItem)
        {
            LaserHit closestHit = LaserHit.None;
            List<Body> ignoredBodies = GetIgnoredBodies(shooter, weaponItem, laserItem);

            GameMain.World.RayCast((fixture, point, normal, fraction) =>
            {
                if (fixture == null) { return -1; }

                Body? body = fixture.Body;
                if (body == null || ignoredBodies.Contains(body)) { return -1; }
                if (!LaserBlocksVisibility(fixture, point, raySubmarine, shooter, weaponItem, laserItem)) { return -1; }

                if (!closestHit.HasHit || fraction < closestHit.Fraction)
                {
                    closestHit = new LaserHit(point, fraction);
                }

                return fraction;
            }, startSim, endSim, Physics.CollisionCharacter | Physics.CollisionWall | Physics.CollisionLevel | Physics.CollisionItemBlocking | Physics.CollisionProjectile | Physics.CollisionLagCompensationBody);

            return closestHit;
        }

        private static bool LaserBlocksVisibility(Fixture fixture, Vector2 hitPointSim, Submarine? raySubmarine, Character? shooter, Item weaponItem, Item laserItem)
        {
            Body? body = fixture.Body;
            if (body == null) { return false; }
            if (fixture.IsSensor) { return false; }
            if (fixture.UserData is Hull) { return false; }
            if (body.UserData as string == "ruinroom") { return false; }

            if (TryGetHitCharacter(fixture, out Character? hitCharacter))
            {
                if (raySubmarine != null && hitCharacter?.Submarine != raySubmarine) { return false; }
                return hitCharacter != shooter;
            }

            if (raySubmarine != null)
            {
                if (body.UserData is VoronoiCell) { return false; }
                if (body.UserData is Entity entity && entity.Submarine != raySubmarine) { return false; }
            }

            if (body.UserData is Structure structure)
            {
                if (structure.IsPlatform || structure.StairDirection != Direction.None) { return false; }

                int sectionIndex = structure.FindSectionIndex(ConvertUnits.ToDisplayUnits(hitPointSim));
                if (sectionIndex > -1 && structure.SectionBodyDisabled(sectionIndex)) { return false; }

                return structure.CastShadow;
            }

            if (body.UserData is Item item)
            {
                if (item == weaponItem || item == laserItem) { return false; }
                if (item.Condition <= 0.0f) { return false; }

                if (item.GetComponent<Door>() is { HasWindow: true } door &&
                    door.IsPositionOnWindow(ConvertUnits.ToDisplayUnits(hitPointSim)))
                {
                    return false;
                }

                return true;
            }

            if (body.UserData is Limb limb)
            {
                return limb.character != shooter && !limb.IsSevered;
            }

            if (body.UserData is Character character)
            {
                return character != shooter;
            }

            return true;
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
                        if (limb == null || limb.Removed || limb.IsSevered) { continue; }

                        checkedLimbs = true;
                        float radius = GetLimbHitRadius(limb);
                        if (TryIntersectCircle(startWorld, direction, length, limb.WorldPosition, radius, out float fraction))
                        {
                            TryUpdateClosestHit(ref closestHit, new LaserHit(startWorld + direction * (fraction * length), fraction));
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

        private static void TryUpdateClosestHit(ref LaserHit closestHit, LaserHit candidate, Vector2 simOffset)
        {
            if (!candidate.HasHit) { return; }

            TryUpdateClosestHit(ref closestHit, new LaserHit(ConvertUnits.ToDisplayUnits(candidate.SimPosition + simOffset), candidate.Fraction));
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
            public readonly Vector2 SimPosition;
            public readonly float Fraction;
            public readonly bool HasHit;

            public LaserHit(Vector2 position, float fraction)
            {
                WorldPosition = position;
                SimPosition = position;
                Fraction = fraction;
                HasHit = true;
            }

            private LaserHit(Vector2 position, float fraction, bool hasHit)
            {
                WorldPosition = position;
                SimPosition = position;
                Fraction = fraction;
                HasHit = hasHit;
            }
        }

        private static bool TryGetHitCharacter(Fixture fixture, out Character? character)
        {
            if (fixture.UserData is Limb fixtureLimb && !fixtureLimb.IsSevered)
            {
                character = fixtureLimb.character;
                return character != null;
            }

            if (fixture.Body?.UserData is Limb bodyLimb && !bodyLimb.IsSevered)
            {
                character = bodyLimb.character;
                return character != null;
            }

            if (fixture.UserData is Character fixtureCharacter)
            {
                character = fixtureCharacter;
                return true;
            }

            if (fixture.Body?.UserData is Character bodyCharacter)
            {
                character = bodyCharacter;
                return true;
            }

            character = null;
            return false;
        }

        private static List<Body> GetIgnoredBodies(Character? character, Item weaponItem, Item laserItem)
        {
            List<Body> ignoredBodies = new();

            if (character?.AnimController?.Limbs != null)
            {
                foreach (Limb limb in character.AnimController.Limbs)
                {
                    AddBody(ignoredBodies, limb.body?.FarseerBody);
                }
            }

            AddBody(ignoredBodies, weaponItem.body?.FarseerBody);
            AddBody(ignoredBodies, laserItem.body?.FarseerBody);

            return ignoredBodies;
        }

        private static void AddBody(List<Body> bodies, Body? body)
        {
            if (body != null && !bodies.Contains(body))
            {
                bodies.Add(body);
            }
        }

        private static bool IsFinite(Vector2 value)
        {
            return float.IsFinite(value.X) && float.IsFinite(value.Y);
        }
    }
}
