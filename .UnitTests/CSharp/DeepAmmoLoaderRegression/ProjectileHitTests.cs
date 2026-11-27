using DeepDivingArmory;
using FarseerPhysics.Dynamics;
using VCE_VirtualizedMagazine;
using static DeepDivingArmory.ContractNoHighPenetration;

internal static class ProjectileHitTests
{
    private static void Check(bool value, string message)
    {
        if (!value) { throw new Exception(message); }
    }

    private static Item Item(string id) => new(42, new ItemPrefab(id, 42));
    private static Projectile Round(Item item)
    {
        var p = new Projectile(item, item.Prefab.ConfigElement);
        item.Components.Add(p);
        p.Attack = new() { SourceItem = item };
        return p;
    }

    internal static void Run()
    {
        ArmsAndShields();
        FriendlyFire();
        Contract();
        Console.WriteLine("PASS: arm hash, shields, friendly-fire markers, final penetration, mixed rounds and nested effects.");
    }

    private delegate bool CollisionPrefix(Projectile p, Fixture target, ref bool result);

    private static void ArmsAndShields()
    {
        var p = Round(Item("round"));
        var human = new Character { ID = 317 };
        static Fixture Target(object? data) => new(new Body(data));
        Fixture LimbTarget(LimbType type) => Target(new Limb(human, type));
        // Golden decisions from the MoonSharp double-precision formula, with item ID 42 and human ID 317.
        foreach (var (time, ignored) in new[] { (0.0, true), (1.001, false), (2.2, false), (8.5, true), (1234.5, true) })
        {
            Timing.TotalTime = time;
            foreach (var type in Enum.GetValues<LimbType>())
            {
                var target = LimbTarget(type);
                bool allow = !ignored || type is LimbType.Head or LimbType.Torso;
                foreach (CollisionPrefix prefix in new CollisionPrefix[] { ProjectileCollisions.OnCollision,
                    ProjectileCollisions.HandleVanilla, ProjectileCollisions.HandleVirtual })
                {
                    bool result = true;
                    Check(prefix(p, target, ref result) == allow && result == allow, $"arm {type} at {time}");
                }
            }
        }
        bool collisionResult = false;
        human.IsHuman = false;
        Check(ProjectileCollisions.HandleVirtual(p, LimbTarget(LimbType.LeftArm), ref collisionResult), "nonhuman arm");
        ProjectileCollisions.ClearRound();
        p.MaxTargetsToHit = 8;
        foreach (var (id, block) in new[] { ("deep_double_handed_shield_heavy", 2), ("deep_wuchuan", 2),
            ("deep_mobile_shield", 1), ("deep_single_handed_shield", 1), ("unrelated", 0) })
        {
            var shield = Item(id);
            shield.OwnInventory = new(5);
            shield.OwnInventory.AllItems.AddRange([Item("deep_mobile_shield_fix_plate_phy"), Item("deep_mobile_shield_fix_plate_tun"),
                Item("deep_mobile_shield_fix_plate_tun"), Item("unrelated")]);
            shield.OwnInventory.AllItems[2].Condition = 0;
            var component = new ItemContainer(shield, 5);
            int expected = block == 0 ? 8 : 8 - block - 3 + 1;
            foreach (var body in new object[] { shield, component })
            {
                Check(ProjectileCollisions.HandleVanilla(p, Target(body), ref collisionResult) && p.MaxTargetsToHit == expected, id);
                Check(ProjectileCollisions.OnCollision(p, Target(body), ref collisionResult) && p.MaxTargetsToHit == 8, "restore pristine");
            }
        }
        var heavy = Target(Item("deep_wuchuan"));
        p.MaxTargetsToHit = 3;
        for (int i = 0; i < 3; i++) { ProjectileCollisions.HandleVirtual(p, heavy, ref collisionResult); }
        Check(p.MaxTargetsToHit == 1, "virtual shields decrement cumulatively and clamp");
        p.MaxTargetsToHit = 5;
        ProjectileCollisions.ClearRound();
        ProjectileCollisions.HandleVanilla(p, heavy, ref collisionResult);
        Check(p.MaxTargetsToHit == 4, "round reset must forget pristine limit");
    }

    private static void FriendlyFire()
    {
        var marker = new Identifier("deep_firendlyfire_avoid_tac_detect");
        var target = new Character { Info = new(), CharacterHealth = new() };
        var p = Round(Item("round"));
        bool Protected()
        {
            p.FriendlyFire = true;
            FriendlyFireProjectile.Shoot(p, target);
            return !p.FriendlyFire;
        }
        Timing.TotalTime = 0;
        target.Info.Stats[(StatTypes.None, marker)] = 1;
        Check(Protected(), "saved stat");
        target.Info = null;
        Timing.TotalTime = 0.499;
        Check(Protected(), "positive marker cache");
        Timing.TotalTime = 0.5;
        Check(!Protected(), "marker expires at half a second");
        target.CharacterHealth.Afflictions[marker] = 1;
        Check(!Protected(), "negative marker cache");
        FriendlyFireProjectile.ClearRound();
        Check(Protected(), "affliction and cache reset");
        target.CharacterHealth = null;
        var chip = Item("deep_firendlyfire_avoid_tac");
        target.Inventory.AllItems.Add(chip);
        var contents = target.Inventory.AllItems;
        for (int depth = 0; depth <= 7; depth++)
        {
            FriendlyFireProjectile.ClearRound();
            Check(Protected() == (depth <= 6), $"chip depth {depth}");
            if (depth == 7) { break; }
            var box = Item("box");
            box.OwnInventory = new(1);
            contents.Clear();
            contents.Add(box);
            contents = box.OwnInventory.AllItems;
            contents.Add(chip);
        }
        target.Inventory.AllItems.Clear();
        target.Inventory.AllItems.Add(chip);
        chip.Removed = true;
        FriendlyFireProjectile.ClearRound();
        Check(!Protected(), "removed chip");
        chip.Removed = false;
        target.IsHuman = false;
        FriendlyFireProjectile.ClearRound();
        Check(!Protected(), "nonhuman shooter");
        p.User = new Character();
        bool Pass()
        {
            bool result = false;
            return !FriendlyFireProjectile.IgnoreFriendly(p, target, ref result) && result;
        }
        Check(Pass(), "friendly marked target");
        p.User.Team++;
        Check(!Pass(), "enemy");
        p.User = target;
        Check(!Pass(), "self");
        p.User = null;
        Check(!Pass(), "missing shooter");
        p.User = new Character();
        target.Removed = true;
        Check(!Pass(), "removed character even with cached marker");
    }

    private static void Contract()
    {
        var marker = new Identifier("deep_contract_no_high_penetration_detect");
        var shooter = new Character { CharacterHealth = new() };
        shooter.CharacterHealth.Afflictions[marker] = 1;
        var limb = new Limb(new Character(), LimbType.Torso);
        var item = Item("round");
        var dda = new ContentPackage("Deep-Diving-Armory");
        var foreign = new ContentPackage("Other Mod");
        item.Prefab.ContentPackage = dda;
        var p = Round(item);
        var attack = p.Attack!;
        attack.Penetration = 0.8f;
        void Tag(string id) => item.Prefab.Tags = [new(id)];
        void Hit(bool blocked, float original = 1, bool generic = false, bool chip = false, bool noAttacker = false)
        {
            CapturePenetration(original, out float state);
            var result = new AttackResult(99);
            bool run = ApplyAttack(attack, noAttacker ? null! : shooter, generic ? null! : limb,
                chip ? original + 0.1f : original, state, ref result);
            Check(run != blocked && result.Damage == (blocked ? 0 : 99), $"contract {original}, chip={chip}, generic={generic}");
        }
        Tag("deep_round");
        foreach (float pen in new[] { 0f, 0.8f, 0.85f, 0.89998f }) { Hit(false, pen); }
        foreach (float pen in new[] { 0.89999998f, 0.9f, 0.95f, 1f }) { Hit(true, pen); }
        Hit(false, noAttacker: true);
        attack.SourceItem = null; Hit(false);
        attack.SourceItem = item; item.Removed = true; Hit(false);
        item.Removed = false;
        shooter.CharacterHealth.Afflictions[marker] = 0; Hit(false);
        shooter.CharacterHealth.Afflictions[marker] = 0.001f; Hit(true);
        item.Prefab.ContentPackage = foreign; Hit(false);
        item.Prefab.ContentPackage = dda;
        Tag("grenade"); Hit(false);
        Tag("riflemanbonus"); Hit(false);
        p.Hitscan = true; Hit(true);
        Tag("shotgunammo");
        p.Attack = new(); Hit(false);
        p.Attack = attack;
        Hit(true, 0.8f, chip: true);
        Hit(false, 0.75f, chip: true);
        Hit(true, 0, generic: true, chip: true);
        p.Launcher = Item("gun");
        p.Launcher.Components.Add(new RangedWeapon(p.Launcher, item.Prefab.ConfigElement) { Penetration = 0.1f });
        Hit(true, 0, generic: true);
        Hit(false, 0.1f, generic: true, chip: true);
        Hit(false, 0, chip: true);

        var localRound = new ItemPrefab("localround", 1) { ContentPackage = dda };
        var otherRound = new ItemPrefab("foreignround", 2) { ContentPackage = foreign };
        ItemPrefab.Prefabs.Values.AddRange([localRound, otherRound]);
        item.Prefab.Identifier = new("VCE_VirtualizedProjectile");
        item.Prefab.ContentPackage = foreign;
        Hit(false);
        var mag = new VirtualizedMagazine(Item("magazine"));
        item.ParentInventory = new ItemInventory(1) { Container = mag };
        mag.LoadedAmmoIdentifiers.Push(otherRound.Identifier);
        mag.LoadedAmmoIdentifiers.Push(localRound.Identifier); Hit(true);
        mag.LoadedAmmoIdentifiers.Push(otherRound.Identifier); Hit(false);
        mag.LoadedAmmoIdentifiers.Push(new("missing")); Hit(false);
        mag.LoadedAmmoIdentifiers.Clear(); Hit(false);
        ItemPrefab.Prefabs.Values.Remove(localRound);
        ItemPrefab.Prefabs.Values.Remove(otherRound);
        item.Prefab.Identifier = new("round"); item.Prefab.ContentPackage = dda;

        static bool Allowed(StatusEffect effect, Entity entity)
        {
            bool result = true;
            bool run = HasRequiredItems(effect, entity, ref result);
            Check(result == run, "blocked effect must return false even after another prefix sets the result");
            return run;
        }
        var radiation = new StatusEffect();
        var explosion = new StatusEffect { Explosions = [new()] };
        var burn = new StatusEffect { Afflictions = [new()] };
        attack.StatusEffects.Add(radiation);
        EnterHit(p, out int collision);
        EnterHit(attack, out int outer);
        Hit(true);
        Check(!Allowed(radiation, shooter) && Allowed(burn, item), "only attack-owned effects");
        EnterHit(attack, out int nested);
        Hit(false, noAttacker: true);
        Check(Allowed(radiation, shooter), "nested unblocked hit");
        ExitHit(nested);
        Check(!Allowed(radiation, shooter), "outer hit restored");
        ExitHit(outer);
        Check(!Allowed(explosion, item) && Allowed(explosion, shooter), "only projectile-owned explosion");
        Check(!Allowed(burn, item) && Allowed(new(), item), "projectile affliction and harmless effect");
        ExitHit(collision);
        Check(Allowed(explosion, item) && Allowed(radiation, shooter), "stack cleared");
        EnterHit(attack, out outer);
        EnterHit(attack, out nested);
        Hit(true); ExitHit(nested);
        Check(Allowed(radiation, item), "inner block must not contaminate outer hit");
        Hit(true); ClearRound(); ExitHit(outer);
        Check(Allowed(radiation, item), "round ended inside hit");
    }
}
