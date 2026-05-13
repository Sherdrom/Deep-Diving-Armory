using HarmonyLib;

namespace DeepLaser
{
    public partial class DeepLaser : IAssemblyPlugin
    {
        private Harmony? harmony;

        public IConfigService ConfigService { get; set; } = null!;
        public IPluginManagementService PluginService { get; set; } = null!;
        public ILoggerService LoggerService { get; set; } = null!;

        public void Initialize()
        {
            harmony = new Harmony("DeepLaser");
            harmony.PatchAll();
            LoggerService.Log("DeepLaser initialized.");
        }

        public void OnLoadCompleted()
        {
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
            harmony?.UnpatchSelf();
            harmony = null;
            LoggerService.Log("DeepLaser disposed.");
        }
    }
}
