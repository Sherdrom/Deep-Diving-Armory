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
        private static readonly Type? ConvexHullType = typeof(GameMain).Assembly.GetType("Barotrauma.Lights.ConvexHull");
        private static readonly Type? SegmentPointType = typeof(GameMain).Assembly.GetType("Barotrauma.Lights.SegmentPoint");
        private static readonly MethodInfo? GetHullsInRangeMethod = ConvexHullType?.GetMethod("GetHullsInRange", BindingFlags.Public | BindingFlags.Static);
        private static readonly MethodInfo? RefreshWorldPositionsMethod = ConvexHullType?.GetMethod("RefreshWorldPositions", BindingFlags.Public | BindingFlags.Instance);
        private static readonly PropertyInfo? HullEnabledProperty = ConvexHullType?.GetProperty("Enabled", BindingFlags.Public | BindingFlags.Instance);
        private static readonly PropertyInfo? HullIsInvalidProperty = ConvexHullType?.GetProperty("IsInvalid", BindingFlags.Public | BindingFlags.Instance);
        private static readonly FieldInfo? HullVerticesField = ConvexHullType?.GetField("vertices", BindingFlags.NonPublic | BindingFlags.Instance);
        private static readonly FieldInfo? SegmentPointWorldPosField = SegmentPointType?.GetField("WorldPos", BindingFlags.Public | BindingFlags.Instance);
        private static bool loggedHullReflectionError;
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
            if (RefreshWorldPositionsMethod == null || HullVerticesField == null || SegmentPointWorldPosField == null)
            {
                LogHullReflectionErrorOnce("DeepLaser failed to find light hull vertex reflection members.");
                return false;
            }

            RefreshWorldPositionsMethod.Invoke(hull, null);
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
