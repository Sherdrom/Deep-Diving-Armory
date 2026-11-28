using System.Numerics;
using VCE_SRW;
using VCE_VirtualizedMagazine;
using NP = DeepDivingArmory.NoProjectileConsume;

namespace Barotrauma
{
    public sealed class PhysicsBody { public bool Enabled; }
    public sealed class Submarine { }
    public sealed partial class Item
    {
        public Item? Container => ParentInventory?.Owner as Item;
        public ContentPackage? ContentPackage => Prefab.ContentPackage;
        public PhysicsBody? body = new();
        public bool HiddenInGame;
        public Submarine? Submarine;
        public Vector2 SimPosition;
        public void Remove() => Removed = true;
        public void SetTransform(Vector2 position, float rotation, Submarine? forceSubmarine = null)
        { SimPosition = position; Submarine = forceSubmarine; }
    }
    public sealed partial class ItemInventory
    {
        public bool TryPutItem(Item item, Character? user, bool createNetworkEvent) =>
            NP.AllowItemOperation(item) && TryPutItem(item, 0, false, false, user!);
    }
}

namespace DeepDivingArmory { internal static class Plugin { internal static ContentPackage Package = new("DDA"); } }
namespace VCE_SRW { public sealed class SwitchableRangedWeapon(Item item) { public Item Item = item; public int CurrentSelected; } }
namespace VCE_VirtualizedMagazine { public sealed class VirtualizedProjectile(Item item) : Projectile(item, new(new("Projectile"))) { } }
namespace Barotrauma.Items.Components { public sealed class Turret(Item item) { public Item Item = item; } }

internal static class NoProjectileConsumeTests
{
    internal static void Run()
    {
        ushort id = 6000;
        Item NewItem(string name) => new(++id, new(name, id) { ContentPackage = DeepDivingArmory.Plugin.Package });
        var weapon = new SwitchableRangedWeapon(NewItem("rifle"));
        var magazine = NewItem("magazine");
        magazine.SimPosition = new(12, 34);
        magazine.Submarine = new();
        magazine.OwnInventory = new(1) { Owner = magazine };
        var round = new Projectile(NewItem("round"), new(new("Projectile")));
        var item = round.Item;
        var turret = new Turret(NewItem("turret"));
        var box = NewItem("box");
        box.OwnInventory = new(1) { Owner = box };
        var bolt = new Projectile(NewItem("bolt"), new(new("Projectile"))) { Hitscan = true };

        void Capture(Projectile projectile) => NP.FindRound(weapon, true, projectile);
        static void Check(bool condition, string name)
        { if (!condition) { throw new Exception("Reusable projectile: " + name); } }
        void AssertRestored() => Check(!round.IsActive && !item.body!.Enabled && !item.HiddenInGame &&
            item.Container == magazine && item.SimPosition == magazine.SimPosition && item.Submarine == magazine.Submarine,
            "round ready for the next shot at the magazine");
        void Fire()
        {
            Check(!round.IsActive, "Projectile.Use entry gate");
            round.IsActive = item.HiddenInGame = item.body!.Enabled = true;
            item.SimPosition = new(21, 43);
        }

        for (int i = 0; i < 3; ++i)
        {
            item.ParentInventory = magazine.OwnInventory;
            NP.BeginHandheld(weapon, out var previous);
            Capture(round);
            NP.BeginProjectile(round);
            Fire();
            Check(!NP.AllowDrop(item) && !NP.AllowItemOperation(item) && !NP.AllowRemoval(item), "shot guards");
            NP.RestoreRound(round);
            AssertRestored();
            // Launch writes the barrel transform after Projectile.Use and an interleaved turret call must not steal it.
            item.SimPosition = new(-41, 0);
            NP.BeginTurret(turret, out var outer);
            NP.CaptureBolt(turret, null);
            NP.EndTurret(outer);
            NP.RestoreHandheld();
            AssertRestored();
            NP.EndHandheld(previous, null);
            Check(!NP.AllowItemOperation(item), "delayed removal remains blocked between shots");
        }

        NP.BeginProjectile(round);
        Check(NP.AllowDrop(item), "a different weapon can fire the same loaded magazine normally");
        NP.BeginHandheld(weapon, out var prior);
        Capture(round);
        weapon.CurrentSelected = 1;
        Capture(round);
        Check(NP.AllowDrop(item), "secondary slot relinquishes a previously protected round");
        weapon.CurrentSelected = 0;
        Capture(new VirtualizedProjectile(item));
        Check(NP.AllowDrop(item), "virtual projectile belongs to VCE");
        weapon.Item.Prefab.Identifier = new("deep_meteorite");
        Capture(round);
        Check(NP.AllowDrop(item), "excluded weapon");
        weapon.Item.Prefab.Identifier = new("rifle");
        weapon.Item.Prefab.ContentPackage = new("foreign");
        Capture(round);
        Check(NP.AllowDrop(item), "foreign package");
        weapon.Item.Prefab.ContentPackage = DeepDivingArmory.Plugin.Package;
        item.ParentInventory = new ItemInventory(1) { Owner = weapon.Item };
        Capture(round);
        Check(NP.AllowDrop(item), "directly loaded round");
        item.ParentInventory = magazine.OwnInventory;
        Capture(round);
        item.ParentInventory = null;
        Check(NP.AllowDrop(item), "detached round");
        item.ParentInventory = magazine.OwnInventory;
        Check(NP.AllowDrop(item), "stale tracking discarded on access");
        foreach (bool removed in new[] { false, true })
        {
            Capture(round);
            magazine.Removed = removed;
            magazine.IsInRemoveQueue = !removed;
            Check(NP.AllowRemoval(item) && NP.AllowItemOperation(item) && NP.AllowDrop(item), "dying magazine");
            magazine.Removed = magazine.IsInRemoveQueue = false;
        }
        Capture(round);
        Fire();
        NP.EndHandheld(prior, new InvalidOperationException());
        AssertRestored();

        void Launch(bool reusable, bool reject = false)
        {
            bolt.Item.ParentInventory = box.OwnInventory;
            NP.BeginTurret(turret, out var previous);
            NP.CaptureBolt(turret, bolt.Item);
            Check(NP.AllowDrop(bolt.Item), "initial turret Drop");
            bolt.Item.Drop(null!);
            NP.BeginProjectile(bolt);
            Check(NP.AllowDrop(bolt.Item) == !reusable && NP.AllowItemOperation(bolt.Item) == !reusable,
                "detached hitscan protection");
            bolt.IsActive = bolt.Item.HiddenInGame = true;
            box.OwnInventory.RejectInsertion = reject;
            NP.EndTurret(previous);
            Check(bolt.IsActive == !reusable && bolt.Item.HiddenInGame == !reusable, "turret readiness");
            Check((bolt.Item.Container == box) == (reusable && !reject), "turret containment");
            Check(NP.AllowItemOperation(bolt.Item) == (!reusable || reject), "turret retracking");
            if (reject) { Check(!bolt.Item.body!.Enabled && bolt.Item.SimPosition == box.SimPosition, "failed return parked"); }
        }
        Launch(true);
        Launch(true);
        box.Condition = 0;
        Launch(false);
        box.Condition = 1;
        bolt.Hitscan = false;
        Launch(false);
        bolt.Hitscan = true;
        box.SimPosition = new(1, 2);
        bolt.Item.body!.Enabled = true;
        Launch(true, reject: true);
        Launch(true);
        NP.ClearRound();
        Check(NP.AllowDrop(bolt.Item), "round cleanup");
        NP.BeginTurret(turret, out var active);
        NP.CaptureBolt(turret, bolt.Item);
        bolt.Item.Drop(null!);
        NP.BeginProjectile(bolt);
        box.IsInRemoveQueue = true;
        Check(NP.AllowItemOperation(bolt.Item) && NP.AllowRemoval(bolt.Item), "dying box releases the detached bolt");
        NP.EndTurret(active);
        Check(bolt.Item.IsInRemoveQueue, "box destroyed mid-shot cannot leave an orphan");
        Console.WriteLine("PASS: reusable handheld and turret projectile regression cases.");
    }
}
