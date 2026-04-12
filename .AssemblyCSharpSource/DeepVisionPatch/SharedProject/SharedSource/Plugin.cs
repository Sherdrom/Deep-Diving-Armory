using Barotrauma.LuaCs;
using Barotrauma.LuaCs.Data;

namespace DeepVisionPatch
{
    /// <summary>
    /// Deep Vision Patch Plugin
    /// Provides tactical view textures and night vision functionality for the Deep Diving Armory mod
    /// </summary>
    public partial class DeepVisionPatch : IAssemblyPlugin
    {
        public static ContentPackage Package { get; private set; }

        public IConfigService LuaCsConfigService { get; set; }
        public IPluginManagementService LuaCsPluginService { get; set; }

        partial void InitlizeProjSpecific();
        partial void OnLoadCompletedProjSpecific();
        partial void DisposeProjSpecific();

        public void Initialize()
        {
            InitlizeProjSpecific();
        }


        public void OnLoadCompleted()
        {
            OnLoadCompletedProjSpecific();
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            DisposeProjSpecific();
        }
    }
}
