using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Runtime.CompilerServices;
using System.Text;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;
using HarmonyLib;
using Barotrauma;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace DeepVisionPatch
{
    /// <summary>
    /// Deep Vision Patch Plugin
    /// Provides tactical view textures and night vision functionality for the Deep Diving Armory mod
    /// </summary>
    public partial class DeepVisionPatch : IAssemblyPlugin
    {
        private Harmony? _harmonyInstance;

        // Texture creators - initialized during OnLoadCompleted
        public static CreateViewTexture ViewTexture { get; } = new CreateViewTexture();
        public static CreateNightVisionTexture GreenNightVisionTexture { get; } = new CreateNightVisionTexture();
        public static CreateNightVisionTexture BlueNightVisionTexture { get; } = new CreateNightVisionTexture();

        public void Initialize()
        {
            // Called when plugin is loading - use for initialization that doesn't depend on other plugins
            _harmonyInstance = new Harmony("DeepVisionPatch");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // Called after all plugins have loaded - use for plugin interactions and final initialization
            _harmonyInstance?.PatchAll();

            // Initialize texture creators with their specific parameters
            ViewTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, 256);
            GreenNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(0, 255, 0, 50));
            BlueNightVisionTexture.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice, new Color(0, 0, 255, 50));

            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup resources
            _harmonyInstance?.UnpatchSelf();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] DeepVisionPatch Disposed!");
        }
    }
}
