namespace GunSmith
{
    public partial class GunSmith : IAssemblyPlugin
    {
        public IConfigService ConfigService { get; set; } = null!;
        public IPluginManagementService PluginService { get; set; } = null!;
        public ILoggerService LoggerService { get; set; } = null!;

        public static ContentPackage? Package { get; private set; }
        private Harmony? harmonyInstance;

        public void Initialize()
        {
            harmonyInstance = new Harmony("DeepDivingArmory.GunSmith");
            if (PluginService.TryGetPackageForPlugin<GunSmith>(out ContentPackage ownerPackage))
            {
                Package = ownerPackage;
            }

            InitializePlatform();
            LoggerService.Log("GunSmith initialized.");
        }

        public void OnLoadCompleted()
        {
            harmonyInstance?.PatchAll();
            if (harmonyInstance != null)
            {
                GunsmithQuickAttachmentBarrelSelectorPatch.PatchOptionalVce(harmonyInstance);
            }
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
