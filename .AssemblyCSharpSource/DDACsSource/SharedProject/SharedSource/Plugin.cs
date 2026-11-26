namespace DeepDivingArmory;

internal enum NetworkHeader { Thermal, WeaponUse }

public sealed class Plugin : IBarotraumaPlugin
{
    internal static ContentPackage Package { get; private set; } = null!;
    internal static IGameNetwork Network { get; private set; } = null!;
    private IHarmonyProvider patches = null!;

    public void Init()
    {
        // The loader creates the plugin instance before it registers services for its assembly.
        Package = PluginServiceProvider.GetService<IContentPackageRetrievalService>().ContentPackage;
        Network = PluginServiceProvider.GetService<IGameNetwork>();
        patches = PluginServiceProvider.GetService<IHarmonyProvider>();
        var hooks = PluginServiceProvider.GetService<ISimpleHookService>();
        var components = PluginServiceProvider.GetService<IItemComponentRegistrar>();
        components.RegisterItemComponents(typeof(DDA.AmmoLoading.DeepAmmoLoader), typeof(DDA.AmmoLoading.ManualMagazineLoading));
        Network.RegisterNetworkHeaders<NetworkHeader>();
        hooks.RegisterHook<PluginRoundEndedDelegate>(RoundEnded);
        DDA.AmmoLoading.Plugin.Init(patches.GetHarmony(), Package);
        DeepSlotExpanded.DeepSlotExpandedPlugin.Init(patches.GetHarmony());
#if CLIENT
        hooks.RegisterHook<PluginRoundStartedDelegate>(_ => PatchOptionalMods());
        PluginSettings.Register(Package, PluginServiceProvider.GetService<ISettingsService>());
        DeepVisionPatch.DeepVisionPatch.RegisterActions(PluginServiceProvider.GetService<IStatusEffectService>());
        ThermalVisablePatch.ThermalVisablePatch.Register();
        WeaponSyncFix.WeaponUseFeedback.Register();
#else
        hooks.RegisterHook<PluginOnPostUpdateDelegate>(EntitySpawnerBudget.Plugin.OnUpdate);
        hooks.RegisterHook<PluginClientJoinedRoundDelegate>(ThermalVisablePatch.ThermalVisablePatch.SyncClient);
#endif
    }

    public void OnContentLoaded()
    {
#if CLIENT
        DeepVisionPatch.DeepVisionPatch.LoadTextures();
        PatchOptionalMods();
#endif
        patches.PatchAll();
        DDA.AmmoLoading.Plugin.PatchWeapons(patches.GetHarmony());
    }

#if CLIENT
    private void PatchOptionalMods()
    {
        VanillaBugFixes.Plugin.PatchPerformanceEnhancement(patches.GetHarmony());
        MoreInformationDisplay.Plugin.DisableStandalone();
    }
#endif

    private static void RoundEnded(GameSession session) => ClearRound();

    private static void ClearRound()
    {
        DeepSlotExpanded.DeepSlotExpandedPlugin.ClearRound();
#if CLIENT
        DeepVisionPatch.DeepVisionPatch.ClearRound();
        DDA.AmmoLoading.ManualMagazineLoading.ResetClient();
        ThermalVisablePatch.ThermalVisablePatch.ClearRound();
#else
        EntitySpawnerBudget.Plugin.ClearRound();
#endif
    }

    public void Dispose()
    {
        ClearRound();
        DeepSlotExpanded.SlotRegistry.ClearForReload();
        DDA.AmmoLoading.Plugin.Dispose();
#if CLIENT
        PluginSettings.Clear();
        DeepLaser.DeepLaser.DisposeGraphics();
        DeepVisionPatch.DeepVisionPatch.DisposeTextures();
#endif
    }
}
