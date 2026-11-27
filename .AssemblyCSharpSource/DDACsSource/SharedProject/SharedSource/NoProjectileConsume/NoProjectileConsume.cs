using Barotrauma.Items.Components;
using VCE_SRW;
using VCE_VirtualizedMagazine;

namespace DeepDivingArmory;

internal static partial class NoProjectileConsume
{
    private static readonly Identifier excluded = new("deep_meteorite");
    private static readonly ConditionalWeakTable<Item, Item> magazines = new();
    [ThreadStatic] private static (SwitchableRangedWeapon? Weapon, Projectile? Round) handheld;
    [ThreadStatic] private static TurretShot turret;

    internal struct TurretShot
    {
        internal Turret? Weapon;
        internal Item? Bolt, Box;
        internal Projectile? Fired;
    }

    private static bool Scoped(Item weapon) =>
        weapon.ContentPackage == Plugin.Package && weapon.Prefab.Identifier != excluded;

    private static bool Live(Item? item) => item is { Removed: false, IsInRemoveQueue: false };

    private static Item? Magazine(Item item)
    {
        if (magazines.TryGetValue(item, out var magazine))
        {
            if (Live(magazine) && Live(item) && item.Container == magazine) { return magazine; }
            magazines.Remove(item);
        }
        return null;
    }

    // Between Launch's initial Drop and reboxing, a turret bolt legitimately has no container.
    private static bool Protected(Item? item) => item != null && (Magazine(item) != null ||
        (turret.Fired?.Item == item && item.Container == null && Live(turret.Box) && Live(item)));

    internal static bool AllowDrop(Item __instance) => !Protected(__instance);
    internal static bool AllowItemOperation(Item __0) => !Protected(__0);
    internal static bool AllowRemoval(Entity __instance) =>
        __instance is not Item item || !MayBlock || !Protected(item);

    private static bool MayBlock =>
#if SERVER
        true;
#else
        GameMain.NetworkMember is not { IsClient: true };
#endif

    internal static void BeginHandheld(SwitchableRangedWeapon __instance,
        out (SwitchableRangedWeapon?, Projectile?) __state)
    {
        __state = handheld;
        handheld = (__instance, null);
    }

    internal static void FindRound(SwitchableRangedWeapon __instance, bool __0, Projectile? __result)
    {
        // VCE also queries FindProjectile(false) for aim previews and its preflight check.
        if (!__0 || handheld.Weapon != __instance || __result == null || __result is VirtualizedProjectile) { return; }
        var item = __result.Item;
        if (__instance.CurrentSelected != 0 || !Scoped(__instance.Item) ||
            item.Container is not { } magazine || magazine == __instance.Item || !Live(magazine) || !Live(item))
        {
            magazines.Remove(item);
            return;
        }
        magazines.AddOrUpdate(item, magazine);
        handheld.Round = __result;
    }

    private static void Park(Item item, Item magazine)
    {
        if (item.body != null) { item.body.Enabled = false; }
        item.SetTransform(magazine.SimPosition, 0f, forceSubmarine: magazine.Submarine);
    }

    internal static void RestoreRound(Projectile __instance)
    {
        if (Magazine(__instance.Item) is not { } magazine) { return; }
        __instance.IsActive = false;
        __instance.Item.HiddenInGame = false;
        Park(__instance.Item, magazine);
    }

    internal static void RestoreHandheld()
    {
        // Projectile.Launch moves the item back to the barrel after Projectile.Use returns.
        if (handheld.Round is { } round) { RestoreRound(round); }
    }

    internal static void EndHandheld((SwitchableRangedWeapon?, Projectile?) __state, Exception? __exception)
    {
        try { if (__exception != null) { RestoreHandheld(); } }
        finally { handheld = __state; }
    }

    internal static void BeginTurret(Turret __instance, out TurretShot __state)
    {
        __state = turret;
        turret = new() { Weapon = __instance };
    }

    internal static void CaptureBolt(Turret __instance, Item? projectile)
    {
        if (turret.Weapon != __instance) { return; }
        ReturnBolt(); // A single TryLaunch can launch more than one bolt.
        if (projectile == null) { return; }
        magazines.Remove(projectile); // Let the turret's own Drop detach even a previously boxed bolt.
        if (Scoped(__instance.Item) && projectile.Container is { Condition: > 0 } box && Live(box) && Live(projectile))
        {
            turret.Bolt = projectile;
            turret.Box = box;
        }
    }

    internal static void BeginProjectile(Projectile __instance)
    {
        var item = __instance.Item;
        if (item == turret.Bolt && __instance.Hitscan) { turret.Fired = __instance; return; }
        if (handheld.Round == __instance) { return; }
#if CLIENT
        // A remote shooter's launch event goes straight from ClientEventRead to Projectile.Use.
        if (WeaponSyncFix.NetworkEventContext.IsProjectileLaunchReplay && __instance is not VirtualizedProjectile &&
            item.Container is { Container: { } weapon } magazine && Live(item) && Live(magazine) && Scoped(weapon) &&
            weapon.GetComponent<SwitchableRangedWeapon>() is { CurrentSelected: 0 } ranged && ranged.FindProjectile(false) == __instance)
        {
            magazines.AddOrUpdate(item, magazine);
            return;
        }
#endif
        // A previously protected magazine may now be firing through an ordinary RangedWeapon.
        magazines.Remove(item);
    }

    private static void ReturnBolt()
    {
        var shot = turret;
        turret = new() { Weapon = shot.Weapon }; // Release the in-flight guards before TryPutItem calls PutItem and Drop.
        if (shot.Fired is not { } round || shot.Box is not { } box || !Live(round.Item)) { return; }
        var item = round.Item;
        if (item.ParentInventory != null && item.Container != box) { return; }
        if (!Live(box))
        {
            // A detached bolt was absent from the box's recursive removal queue.
            if (item.ParentInventory == null && MayBlock)
            {
                if (Entity.Spawner is { Removed: false } spawner) { spawner.AddItemToRemoveQueue(item); }
                else { item.Remove(); }
            }
            return;
        }
        round.IsActive = false;
        item.HiddenInGame = false;
        Park(item, box);
        if (item.Container != box) { box.OwnInventory?.TryPutItem(item, null, createNetworkEvent: MayBlock); }
        if (item.Container == box) { magazines.AddOrUpdate(item, box); }
    }

    internal static void EndTurret(TurretShot __state)
    {
        try { ReturnBolt(); }
        finally { turret = __state; }
    }

#if CLIENT
    private static readonly ConditionalWeakTable<Item, Submarine> tracerSubmarines = new();

    internal static void FixTracer(Projectile __instance, bool __result)
    {
        var item = __instance.Item;
        if (__result && item.Submarine is { } sub && Protected(item) && !sub.Borders.Contains(item.Position))
        {
            tracerSubmarines.AddOrUpdate(item, sub);
            item.Submarine = null;
        }
    }

    internal static void RestoreTracer(Projectile __instance)
    {
        var item = __instance.Item;
        if (tracerSubmarines.TryGetValue(item, out var sub))
        {
            item.Submarine ??= sub;
            tracerSubmarines.Remove(item);
        }
    }
#endif

    internal static void ClearRound()
    {
        magazines.Clear();
        handheld = default;
        turret = default;
#if CLIENT
        tracerSubmarines.Clear();
#endif
    }
}
