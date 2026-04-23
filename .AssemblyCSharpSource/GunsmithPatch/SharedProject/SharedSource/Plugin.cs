namespace GunsmithPatch
{
    public partial class GunsmithPatch : IAssemblyPlugin
    {
        public IConfigService ConfigService { get; set; } = null!;
        public IPluginManagementService PluginService { get; set; } = null!;
        public ILoggerService LoggerService { get; set; } = null!;

        public static ContentPackage? Package { get; private set; }
        private Harmony? harmonyInstance;

        public void Initialize()
        {
            harmonyInstance = new Harmony("DeepDivingArmory.GunsmithPatch");
            if (PluginService.TryGetPackageForPlugin<GunsmithPatch>(out ContentPackage ownerPackage))
            {
                Package = ownerPackage;
            }

            InitializePlatform();
            LoggerService.Log("GunsmithPatch initialized.");
        }

        public void OnLoadCompleted()
        {
            harmonyInstance?.PatchAll();
            OnLoadCompletedPlatform();
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
            DisposePlatform();
            harmonyInstance?.UnpatchSelf();
        }

        partial void InitializePlatform();
        partial void OnLoadCompletedPlatform();
        partial void DisposePlatform();
    }
}
