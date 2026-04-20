using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using HarmonyLib;

namespace NoCollisionHoldable
{
    public partial class NoCollisionHoldable : IAssemblyPlugin
    {
        public void Initialize() { }

        public void OnLoadCompleted()
        {
            NoCollisionHoldablePatch.ApplyPatch();
            LuaCsLogger.Log("[NoCollisionHoldable] Loaded! Holdables will not block characters.");
        }

        public void PreInitPatching() { }

        public void Dispose()
        {
            new Harmony("NoCollisionHoldableMod").UnpatchSelf();
        }
    }

    public static class NoCollisionHoldablePatch
    {
        public static void ApplyPatch()
        {
            var harmony = new Harmony("NoCollisionHoldableMod");
            var method = AccessTools.Method(typeof(Holdable), "OnPusherCollision", new[] {
                typeof(Fixture), typeof(Fixture), typeof(Contact)
            });
            var prefix = AccessTools.Method(typeof(NoCollisionHoldablePatch), "OnPusherCollisionPrefix");
            harmony.Patch(method, new HarmonyMethod(prefix));
        }

        public static bool OnPusherCollisionPrefix(Fixture sender, Fixture other, Contact contact, ref bool __result)
        {
            if (other.Body.UserData is Character character)
            {
                __result = false;
                return false;
            }
            else
            {
                __result = true;
                return false;
            }
        }
    }
}
