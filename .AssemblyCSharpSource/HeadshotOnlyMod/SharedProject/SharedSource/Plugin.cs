using HarmonyLib;

namespace HeadshotOnlyMod
{
    public partial class HeadshotOnlyMod : IAssemblyPlugin
    {
        public void Initialize()
        {
            HarmonyPatches.ApplyPatches();
            LuaCsLogger.Log("[HeadshotOnlyMod] Loaded! deep_headshot_deadly and deep_headshot_deadly_irresistible Affliction now only apply to Human Head limbs.");
        }

        public void OnLoadCompleted() { }

        public void PreInitPatching() { }

        public void Dispose() { }
    }

    public static class HarmonyPatches
    {
        public static void ApplyPatches()
        {
            var harmony = new Harmony("HeadshotOnlyMod");

            var method = AccessTools.Method(typeof(Character), "DamageLimb", new[] {
                typeof(Vector2), typeof(Limb), typeof(IEnumerable<Affliction>), typeof(float),
                typeof(bool), typeof(Vector2), typeof(Character), typeof(float), typeof(bool),
                typeof(float), typeof(bool), typeof(bool), typeof(bool)
            });
            var prefix = AccessTools.Method(typeof(HarmonyPatches), "DamageLimbPrefix");

            harmony.Patch(method, new HarmonyMethod(prefix));
        }

        public static bool DamageLimbPrefix(ref Character __instance, ref Vector2 worldPosition, ref Limb hitLimb, ref IEnumerable<Affliction> afflictions, ref float stun, ref bool playSound, ref Vector2 attackImpulse, ref Character attacker, ref float damageMultiplier, ref bool allowStacking, ref float penetration, ref bool shouldImplode, ref bool ignoreDamageOverlay, ref bool recalculateVitality)
        {
            bool isHuman = __instance != null && __instance.IsHuman;
            bool isHeadLimb = hitLimb != null && hitLimb.type == LimbType.Head;

            if (isHuman && isHeadLimb)
            {
                return true;
            }

            if (afflictions != null)
            {
                afflictions = afflictions.Where(a =>
                    a.Prefab.Identifier != "deep_headshot_deadly" &&
                    a.Prefab.Identifier != "deep_headshot_deadly_irresistible"
                ).ToList();
            }

            return true;
        }
    }
}
