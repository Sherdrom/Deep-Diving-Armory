using Barotrauma.Items.Components;

namespace DeepDivingArmory;

internal static class FriendlyFireProjectile
{
    private static readonly Identifier marker = new("deep_firendlyfire_avoid_tac_detect");
    private static readonly Identifier chip = new("deep_firendlyfire_avoid_tac");
    private sealed class MarkerState { internal double Expires; internal bool Value; }
    private static readonly ConditionalWeakTable<Character, MarkerState> markers = new();

    internal static void ClearRound() => markers.Clear();

    private static bool ContainsChip(Inventory? inventory, int depth)
    {
        if (inventory == null) { return false; }
        foreach (var item in inventory.AllItems)
        {
            if (item.Removed) { continue; }
            if (item.Prefab.Identifier == chip || (depth < 6 && ContainsChip(item.OwnInventory, depth + 1))) { return true; }
        }
        return false;
    }

    private static bool HasMarker(Character character)
    {
        if (character.Removed) { return false; }
        var entry = markers.GetOrCreateValue(character);
        double now = Timing.TotalTime;
        if (now >= entry.Expires)
        {
            entry.Value = character.Info?.GetSavedStatValue(StatTypes.None, marker) > 0 ||
                character.CharacterHealth?.GetAfflictionStrengthByIdentifier(marker) > 0 || ContainsChip(character.Inventory, 0);
            entry.Expires = now + 0.5;
        }
        return entry.Value;
    }

    internal static void Shoot(Projectile __instance, Character user)
    {
        if (user is { IsHuman: true } && HasMarker(user)) { __instance.FriendlyFire = false; }
    }

    internal static bool IgnoreFriendly(Projectile __instance, Character character, ref bool __result)
    {
        if (character == null || __instance.User is not { } user || character == user ||
            !character.IsFriendly(user) || !HasMarker(character)) { return true; }
        __result = true;
        return false;
    }
}
