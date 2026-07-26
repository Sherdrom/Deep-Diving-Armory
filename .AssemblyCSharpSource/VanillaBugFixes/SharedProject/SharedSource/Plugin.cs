using HarmonyLib;

namespace VanillaBugFixes
{
    public sealed partial class Plugin : IAssemblyPlugin
    {
        private const string HarmonyId = "vanillabugfixes";
        private Harmony? harmony;

        public void Initialize()
        {
            harmony = new Harmony(HarmonyId);
            harmony.PatchAll();
            PatchPlatformSpecific(harmony);

            LuaCsLogger.Log("[VanillaBugFixes] Loaded.");
        }

        partial void PatchPlatformSpecific(Harmony harmony);

        public void OnLoadCompleted() { }

        public void PreInitPatching() { }

        public void Dispose()
        {
            harmony?.UnpatchSelf();
            harmony = null;
            LuaCsLogger.Log("[VanillaBugFixes] Unloaded.");
        }
    }
}
