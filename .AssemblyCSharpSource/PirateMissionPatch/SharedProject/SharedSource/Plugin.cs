using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using Barotrauma;
using HarmonyLib;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace PirateMissionPatch
{
    public partial class PirateMissionPatch : IAssemblyPlugin
    {
        public Harmony? harmonyInstance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("PriateMissionPatch");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            harmonyInstance?.PatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Disposed!");
        }
    }
    
}
