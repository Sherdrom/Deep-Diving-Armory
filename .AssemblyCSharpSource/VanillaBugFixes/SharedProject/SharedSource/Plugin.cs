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

            LuaCsSetup.PrintCsMessage("[Deep-Diving-Armory] VanillaBugFixes Loaded.");
        }

        partial void PatchPlatformSpecific(Harmony harmony);
        partial void PreInitPatchingProjSpecific();

        public void OnLoadCompleted() { }

        public void PreInitPatching()
        {
            PreInitPatchingProjSpecific();
        }

        public void Dispose()
        {
            harmony?.UnpatchSelf();
            harmony = null;
            LuaCsSetup.PrintCsMessage("[Deep-Diving-Armory] VanillaBugFixes Unloaded.");
        }
    }
}
