using Barotrauma.Items.Components;
using VCE_VirtualizedMagazine;

namespace DeepDivingArmory;

internal static class ContractNoHighPenetration
{
    private static readonly Identifier contract = new("deep_contract_no_high_penetration_detect");
    private static readonly Identifier virtualRound = new("VCE_VirtualizedProjectile");
    private static readonly Identifier roundTag = new("deep_round");
    private static readonly Identifier shotgunTag = new("shotgunammo");
    private static readonly Identifier rifleTag = new("riflemanbonus");
    [ThreadStatic] private static List<(object Owner, bool Blocked)>? hits;

    internal static void ClearRound() => hits?.Clear();

    internal static void EnterHit(object __instance, out int __state)
    {
        (hits ??= []).Add((__instance, false));
        __state = hits.Count;
    }

    internal static void ExitHit(int __state)
    {
        if (__state > 0 && hits?.Count == __state) { hits.RemoveAt(__state - 1); }
    }

    internal static void CapturePenetration(float penetration, out float __state) => __state = penetration;

    internal static bool ApplyAttack(Attack attack, Character attacker, Limb targetLimb, float penetration,
        float __state, ref AttackResult __result)
    {
        if (attack?.SourceItem is not { Removed: false } item ||
            !(attacker?.CharacterHealth?.GetAfflictionStrengthByIdentifier(contract) > 0) ||
            item.GetComponent<Projectile>() is not { } projectile || projectile.Attack != attack ||
            !(item.HasTag(roundTag) || item.HasTag(shotgunTag) ||
              (projectile.Hitscan && item.HasTag(rifleTag)))) { return true; }

        double effective = penetration;
        // DoDamage(character) omits both components. A normal-priority chip may already have changed penetration.
        if (targetLimb == null && __state == 0)
        {
            effective += (double)attack.Penetration + (projectile.Launcher?.GetComponent<RangedWeapon>()?.Penetration ?? 0);
        }
        if (Math.Floor((effective + 0.00001) * 10) < 9) { return true; }

        var prefab = item.Prefab;
        if (prefab.Identifier == virtualRound)
        {
            // TopIdentifier is the last entry of VCE's serialized LoadedAmmoIdentifiersArray.
            if (item.ParentInventory is not ItemInventory { Container: VirtualizedMagazine magazine } ||
                !ItemPrefab.Prefabs.TryGet(magazine.TopIdentifier, out prefab)) { return true; }
        }
        if (prefab.ContentPackage?.Name != "Deep-Diving-Armory") { return true; }

        if (hits is { Count: > 0 })
        {
            int i = hits.Count - 1;
            if (hits[i].Owner == attack) { hits[i--] = (attack, true); }
            if (i >= 0 && hits[i].Owner == projectile) { hits[i] = (projectile, true); }
        }
        __result = default;
        return false;
    }

    internal static bool HasRequiredItems(StatusEffect __instance, Entity entity, ref bool __result)
    {
        if (hits is not { Count: > 0 } || !hits[^1].Blocked) { return true; }
        bool blocked = hits[^1].Owner switch
        {
            Attack attack => attack.StatusEffects.Contains(__instance),
            Projectile projectile when projectile.Item == entity => __instance.Afflictions.Count > 0 || __instance.Explosions.Any(),
            _ => false
        };
        if (blocked) { __result = false; }
        return !blocked;
    }
}
