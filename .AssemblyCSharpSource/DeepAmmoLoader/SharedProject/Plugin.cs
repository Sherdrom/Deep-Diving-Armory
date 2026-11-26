global using Barotrauma;
global using Microsoft.Xna.Framework;
using Barotrauma.Items.Components;
using Barotrauma.LuaCs;
using HarmonyLib;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using VCE_SRW;
using VCE_VirtualizedMagazine;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]

namespace DDA.AmmoLoading;

public sealed class Plugin : IAssemblyPlugin
{
    private Harmony? harmony;
    private static ContentPackage? ownerPackage;

    public IPluginManagementService LuaCsPluginService { get; set; } = null!;
#if CLIENT
    public IConfigService LuaCsConfigService { get; set; } = null!;
#endif

    public void Initialize()
    {
        AssemblyLoadContext.GetLoadContext(typeof(Plugin).Assembly)!.Resolving += ResolveVce;
        harmony = new Harmony("deepdivingarmory.deepammoloader");
        harmony.Patch(AccessTools.Method(typeof(Item), nameof(Item.Load),
                [typeof(ContentXElement), typeof(Submarine), typeof(IdRemap), typeof(bool)]),
            prefix: new HarmonyMethod(typeof(Plugin), nameof(MigrateSavedComponent)));
#if CLIENT
        harmony.CreateClassProcessor(typeof(DeepAmmoLoaderTargetInputPatch)).Patch();
        harmony.CreateClassProcessor(typeof(ManualMagazineLoading)).Patch();
#endif
    }

    // LuaCs discovers ItemComponent subclasses from the loaded assembly.
    public void PreInitPatching() { }
    public void OnLoadCompleted()
    {
        if (!LuaCsPluginService.TryGetPackageForPlugin<Plugin>(out ownerPackage)) { return; }
        var transpiler = new HarmonyMethod(typeof(Plugin), nameof(PatchProjectileCleanup));
        foreach (var type in new[] { typeof(RangedWeapon), typeof(SwitchableRangedWeapon) })
        {
            harmony!.Patch(AccessTools.DeclaredMethod(type, nameof(RangedWeapon.Use), [typeof(float), typeof(Character)]),
                transpiler: transpiler);
        }
#if CLIENT
        if (LuaCsConfigService.TryGetConfig<Barotrauma.LuaCs.Data.ISettingControl>(ownerPackage, "StopManualLoading", out var control))
        { ManualMagazineLoading.StopControl = control; }
#endif
    }
    public void Dispose()
    {
        AssemblyLoadContext.GetLoadContext(typeof(Plugin).Assembly)!.Resolving -= ResolveVce;
#if CLIENT
        ManualMagazineLoading.ResetClient();
#endif
        harmony?.UnpatchSelf();
        harmony = null;
        ownerPackage = null;
    }

    private static Assembly? ResolveVce(AssemblyLoadContext context, AssemblyName name)
    {
        if (name.Name is not ("VanillaComponentsExpandedClient" or "VanillaComponentsExpandedServer")) { return null; }
        // LuaCs cannot resolve VCE in the native plugin context; share its existing types.
        return AssemblyLoadContext.All.SelectMany(c => c.Assemblies).FirstOrDefault(a => a.FullName == name.FullName);
    }

    private static IEnumerable<CodeInstruction> PatchProjectileCleanup(IEnumerable<CodeInstruction> instructions) =>
        Transpilers.MethodReplacer(instructions, AccessTools.Method(typeof(Item), nameof(Item.RemoveContained)),
            AccessTools.Method(typeof(Plugin), nameof(RemoveFiredProjectile)));

    private static void RemoveFiredProjectile(Item weapon, Item projectile)
    {
        // VCE reuses the projectile in its magazine. RemoveContained would clear that ownership.
        if (projectile.Container is { } magazine && magazine != weapon &&
            weapon.ContentPackage == ownerPackage && projectile.GetComponent<VirtualizedProjectile>() != null) { return; }
        weapon.RemoveContained(projectile);
    }

    internal static void MigrateSavedComponent(ContentXElement element)
    {
        if (element.GetAttributeIdentifier("identifier", Identifier.Empty) != "deep_new_ammoloader".ToIdentifier()) { return; }
        foreach (var component in element.Element.Elements())
        {
            if (component.Name.LocalName.Equals("AmmoLoader", StringComparison.OrdinalIgnoreCase))
            { component.Name = nameof(DeepAmmoLoader); }
        }
    }
}
