using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using Barotrauma;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace MyModName
{
    public partial class Plugin : IAssemblyPlugin
    {
        public static Plugin? Instance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            Instance = new Plugin();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] Template Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] Template Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] Template Disposed!");
        }
    }
}
