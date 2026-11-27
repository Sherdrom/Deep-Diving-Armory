using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;

namespace DeepDivingArmory;

internal static class ProjectileCollisions
{
    private static readonly ConditionalWeakTable<Projectile, StrongBox<int>> pristine = new();

    internal static void ClearRound() => pristine.Clear();

    private static bool AllowArmHit(Projectile projectile, Fixture target, ref bool result)
    {
        if (target?.Body.UserData is not Limb { character.IsHuman: true } limb ||
            limb.type is not (LimbType.RightHand or LimbType.LeftHand or LimbType.LeftForearm or
                LimbType.RightForearm or LimbType.LeftArm or LimbType.RightArm)) { return true; }

        // Lua numbers are doubles. Integer overflow arithmetic changes the hash for longer rounds.
        double seed = Math.Floor(Timing.TotalTime * 1000);
        if (projectile.Item is { } item) { seed = seed * 31 + item.ID; }
        seed = seed * 37 + limb.character.ID;
        if (seed * 2654435761d % 4294967296d % 10000 >= 6000) { return true; }
        result = false;
        return false;
    }

    private static void RestoreLimit(Projectile projectile) =>
        projectile.MaxTargetsToHit = pristine.GetValue(projectile, static p => new(p.MaxTargetsToHit)).Value;

    internal static bool OnCollision(Projectile __instance, Fixture target, ref bool __result)
    {
        if (!AllowArmHit(__instance, target, ref __result)) { return false; }
        RestoreLimit(__instance);
        return true;
    }

    internal static bool HandleVanilla(Projectile __instance, Fixture target, ref bool __result)
    {
        if (!OnCollision(__instance, target, ref __result)) { return false; }
        BlockShield(__instance, target);
        return true;
    }

    internal static bool HandleVirtual(Projectile __instance, Fixture target, ref bool __result)
    {
        if (!AllowArmHit(__instance, target, ref __result)) { return false; }
        BlockShield(__instance, target);
        return true;
    }

    private static void BlockShield(Projectile projectile, Fixture target)
    {
        var shield = target?.Body.UserData switch { Item item => item, ItemComponent component => component.Item, _ => null };
        int block = shield?.Prefab.Identifier.Value switch
        {
            "deep_double_handed_shield_heavy" or "deep_wuchuan" => 2,
            "deep_mobile_shield" or "deep_single_handed_shield" => 1,
            _ => 0
        };
        if (block == 0) { return; }
        if (shield!.OwnInventory is { } inventory)
        {
            for (int i = 0; i < inventory.Capacity; i++)
            {
                if (inventory.GetItemAt(i) is not { Condition: > 0 } plate) { continue; }
                block += plate.Prefab.Identifier.Value switch
                {
                    "deep_mobile_shield_fix_plate_phy" => 1,
                    "deep_mobile_shield_fix_plate_tun" => 2,
                    _ => 0
                };
            }
        }
        projectile.MaxTargetsToHit = Math.Max(1, projectile.MaxTargetsToHit - block + 1);
    }
}
