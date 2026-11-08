global using Barotrauma;
global using Microsoft.Xna.Framework;
using Barotrauma.LuaCs;
using HarmonyLib;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]

namespace DDA.AmmoLoading;

public sealed class Plugin : IAssemblyPlugin
{
    private Harmony? harmony;

    public void Initialize()
    {
        AssemblyLoadContext.GetLoadContext(typeof(Plugin).Assembly)!.Resolving += ResolveVce;
        harmony = new Harmony("deepdivingarmory.deepammoloader");
        harmony.Patch(AccessTools.Method(typeof(Item), nameof(Item.Load),
                [typeof(ContentXElement), typeof(Submarine), typeof(IdRemap), typeof(bool)]),
            prefix: new HarmonyMethod(typeof(Plugin), nameof(MigrateSavedComponent)));
    }

    // LuaCs discovers ItemComponent subclasses from the loaded assembly.
    public void PreInitPatching() { }
    public void OnLoadCompleted() { }
    public void Dispose()
    {
        AssemblyLoadContext.GetLoadContext(typeof(Plugin).Assembly)!.Resolving -= ResolveVce;
        harmony?.UnpatchSelf();
        harmony = null;
    }

    private static Assembly? ResolveVce(AssemblyLoadContext context, AssemblyName name)
    {
        if (name.Name is not ("VanillaComponentsExpandedClient" or "VanillaComponentsExpandedServer")) { return null; }
        // LuaCs cannot resolve VCE in the native plugin context; share its existing types.
        return AssemblyLoadContext.All.SelectMany(c => c.Assemblies).FirstOrDefault(a => a.FullName == name.FullName);
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
