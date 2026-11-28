using Barotrauma.Items.Components;
using VCE_SRW;
using VCE_VirtualizedMagazine;

namespace DDA.AmmoLoading;

internal static class Plugin
{
    private static ContentPackage? ownerPackage;

    internal static void Init(Harmony harmony, ContentPackage package)
    {
        ownerPackage = package;
        harmony.Patch(AccessTools.Method(typeof(Item), nameof(Item.Load),
                [typeof(ContentXElement), typeof(Submarine), typeof(IdRemap), typeof(bool)]),
            prefix: new HarmonyMethod(typeof(Plugin), nameof(MigrateSavedComponent)));
    }

    internal static void PatchWeapons(Harmony harmony)
    {
        var transpiler = new HarmonyMethod(typeof(Plugin), nameof(PatchProjectileCleanup));
        foreach (var type in new[] { typeof(RangedWeapon), typeof(SwitchableRangedWeapon) })
        {
            harmony.Patch(AccessTools.DeclaredMethod(type, nameof(RangedWeapon.Use), [typeof(float), typeof(Character)]),
                transpiler: transpiler);
        }
    }

    internal static void Dispose() => ownerPackage = null;

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
