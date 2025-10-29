using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using HarmonyLib;
using Barotrauma;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace DeepVisionPatch
{
    public partial class DeepVisionPatch : IAssemblyPlugin
    {
        public Harmony? harmonyInstance;
        public static CreateViewTexture viewTexture = new CreateViewTexture();
        public static CreateNightVisionTexture nvTexture = new CreateNightVisionTexture();
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("DeepVisionPatch");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            harmonyInstance?.PatchAll();
            viewTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, 256);
            nvTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, 256, 256);
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchSelf();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Disposed!");
        }
    }
}
