using Barotrauma;
using Barotrauma.Items.Components;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using static Barotrauma.PetBehavior.ItemProduction;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace Deep_SwitchableRangedWeapon
{
    public partial class SRW : IAssemblyPlugin
    {
        public static SRW? Instance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.

            Type type = Type.GetType("Barotrauma.Items.Components.SwitchableRangedWeapon");
            if (type == null)
            {
                Instance = new SRW();
                LuaCsSetup.PrintCsMessage("[Deep Diving Armory] SwitchableRangedWeapon Initialized!");
            }
            else
            {
                DebugConsole.AddWarning($"WARNING: A instance of SwitchableRangedWeapon is already exist! Skipping...");
            }
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            Instance = null;
        }
    }
}
