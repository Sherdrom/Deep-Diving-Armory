using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using HarmonyLib;

namespace IgnoreArmLimbsMod
{
    public partial class IgnoreArmLimbsMod : IAssemblyPlugin
    {
        public void Initialize() { }

        public void OnLoadCompleted()
        {
            var harmony = new Harmony("IgnoreArmLimbsMod");
            harmony.PatchAll();
            LuaCsLogger.Log("[IgnoreArmLimbsMod] Loaded! Arm hits will be ignored with a chance.");
        }

        public void PreInitPatching() { }

        public void Dispose()
        {
            new Harmony("IgnoreArmLimbsMod").UnpatchSelf();
        }
    }

    public static class IgnoreArmLimbsPatch
    {
        public const float IgnoreChance = 0.6f;
        public static bool DebugMode = false;

        public static bool ShouldIgnoreHit(Projectile projectile, Limb limb)
        {
            if (IgnoreChance <= 0f) return false;
            Random random = new Random((int)(Timing.TotalTime * 1000) ^ (projectile?.item?.ID ?? 0) ^ (limb?.character?.ID ?? 0));
            return random.NextDouble() < IgnoreChance;
        }
    }

    [HarmonyPatch(typeof(Projectile), "OnProjectileCollision")]
    [HarmonyPatch(new Type[] { typeof(Fixture), typeof(Fixture), typeof(Contact) })]
    static class Projectile_OnProjectileCollision_Patch
    {
        static bool Prefix(Projectile __instance, Fixture f1, Fixture target, Contact contact)
        {
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
            {
                if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand ||
                    limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm ||
                    limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                {
                    if (IgnoreArmLimbsPatch.ShouldIgnoreHit(__instance, limb))
                    {
                        if (__instance.IgnoredBodies != null)
                        {
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        else
                        {
                            __instance.IgnoredBodies = new List<Body>();
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        return false;
                    }
                }
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
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
            {
                if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand ||
                    limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm ||
                    limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                {
                    if (IgnoreArmLimbsPatch.ShouldIgnoreHit(__instance, limb))
                    {
                        if (__instance.IgnoredBodies != null)
                        {
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        else
                        {
                            __instance.IgnoredBodies = new List<Body>();
                            __instance.IgnoredBodies.Add(target.Body);
                        }
                        return false;
                    }
                }
            }
            return true;
        }
    }
}
