using Barotrauma;
using HarmonyLib;
using System.Runtime.CompilerServices;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace RemainedAmmo
{
    public partial class RemainedAmmo : IAssemblyPlugin
    {
        public Harmony? harmonyInstance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("RemainedAmmo");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] RemainedAmmo Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            harmonyInstance.PatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] RemainedAmmo Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] RemainedAmmo Disposed!");
        }
    }
}
