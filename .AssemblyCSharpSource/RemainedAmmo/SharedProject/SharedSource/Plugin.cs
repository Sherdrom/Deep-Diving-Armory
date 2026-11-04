namespace RemainedAmmo
{
    public partial class RemainedAmmo : IAssemblyPlugin
    {
        public ILoggerService LoggerService { get; set; }
        public IPluginManagementService PluginService { get; set; }

        public static ContentPackage Package { get; private set; }

        public Harmony? harmonyInstance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("RemainedAmmo");
            PluginService.TryGetPackageForPlugin<RemainedAmmo>(out ContentPackage ownerPackage);
            Package = ownerPackage;
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            // JIT inlining can make parameterless PatchAll scan the game's assembly.
            harmonyInstance?.PatchAll(typeof(RemainedAmmo).Assembly);
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchSelf();
        }
    }
}
