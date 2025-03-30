using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using Barotrauma;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace PriateMissionPatch
{
    public partial class Plugin : IAssemblyPlugin
    {
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PriateMissionPatch Disposed!");
        }
    }
}
