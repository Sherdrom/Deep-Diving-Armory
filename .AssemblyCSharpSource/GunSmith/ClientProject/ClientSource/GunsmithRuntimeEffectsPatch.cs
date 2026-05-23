using Barotrauma.Items.Components;

namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithRuntimeEffectsPatch
    {
        private static readonly Dictionary<Character, HeldGunsmithStateCache> HeldStateCacheByCharacter = new();

        [HarmonyPatch(typeof(Character), nameof(Character.GetStatValue), new[] { typeof(StatTypes), typeof(bool) })]
        [HarmonyPostfix]
        private static void ApplyGunsmithCharacterStats(Character __instance, StatTypes statType, ref float __result)
        {
            if (!TryGetHeldGunsmithState(__instance, out GunsmithRuntimeState? state) ||
                !state.Stats.TryGet(statType, out float value))
            {
                return;
            }

            __result += value;
        }

        internal static void InvalidateItem(Item item)
            => HeldStateCacheByCharacter.Clear();

        internal static void ClearCaches()
            => HeldStateCacheByCharacter.Clear();

        internal static bool ShouldSuppressManagedQuickSlotAfflictions(StatusEffect statusEffect, ISerializableEntity target)
        {
            if (!CanSuppressManagedQuickSlotAfflictions(statusEffect))
            {
                return false;
            }

            return TryGetTargetItem(target, out Item? item) && IsContainedInGunsmithItem(item);
        }

        internal static bool ShouldSuppressManagedQuickSlotAfflictions(StatusEffect statusEffect, IReadOnlyList<ISerializableEntity> targets)
        {
            if (!CanSuppressManagedQuickSlotAfflictions(statusEffect) || targets == null || targets.Count == 0)
            {
                return false;
            }

            foreach (ISerializableEntity target in targets)
            {
                if (TryGetTargetItem(target, out Item? item) && IsContainedInGunsmithItem(item))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool CanSuppressManagedQuickSlotAfflictions(StatusEffect statusEffect)
        {
            if (!GunsmithApi.HasManagedRuntimeItems)
            {
                return false;
            }

            if (statusEffect.Afflictions == null || statusEffect.Afflictions.Count == 0)
            {
                return false;
            }

            return true;
        }

        private static bool TryGetHeldGunsmithState(Character character, out GunsmithRuntimeState state)
        {
            state = null!;
            if (character == null || character.Removed || character.HeldItems == null)
            {
                return false;
            }

            double cacheTime = Timing.TotalTime;
            if (HeldStateCacheByCharacter.TryGetValue(character, out HeldGunsmithStateCache cache) &&
                cache.TotalTime == cacheTime)
            {
                state = cache.State!;
                return cache.Found;
            }

            foreach (Item item in character.HeldItems)
            {
                if (GunsmithApi.TryGetRuntimeState(item, out state))
                {
                    HeldStateCacheByCharacter[character] = new HeldGunsmithStateCache(cacheTime, true, state);
                    return true;
                }
            }

            HeldStateCacheByCharacter[character] = new HeldGunsmithStateCache(cacheTime, false, null);
            return false;
        }

        private static bool TryGetTargetItem(ISerializableEntity target, out Item item)
        {
            item = null!;
            switch (target)
            {
                case Item targetItem:
                    item = targetItem;
                    return true;
                case ItemComponent itemComponent when itemComponent.Item != null:
                    item = itemComponent.Item;
                    return true;
                default:
                    return false;
            }
        }

        private static bool IsContainedInGunsmithItem(Item item)
        {
            string itemIdentifier = item.Prefab.Identifier.Value;
            Inventory? inventory = item.ParentInventory;
            while (inventory != null)
            {
                if (inventory.Owner is Item ownerItem && IsManagedByGunsmithState(ownerItem, itemIdentifier))
                {
                    return true;
                }

                inventory = inventory.Owner is Item parentItem ? parentItem.ParentInventory : null;
            }

            return false;
        }

        private static bool IsManagedByGunsmithState(Item ownerItem, string itemIdentifier)
            => GunsmithApi.TryGetRuntimeState(ownerItem, out GunsmithRuntimeState? state) &&
               state.ManagedItemIdentifiers.Contains(itemIdentifier);

        private readonly record struct HeldGunsmithStateCache(double TotalTime, bool Found, GunsmithRuntimeState? State);
    }

    [HarmonyPatch(typeof(StatusEffect), nameof(StatusEffect.Apply), new[]
    {
        typeof(ActionType),
        typeof(float),
        typeof(Entity),
        typeof(ISerializableEntity),
        typeof(Vector2?)
    })]
    public static class GunsmithManagedSingleItemAfflictionSuppressionPatch
    {
        [HarmonyPrefix]
        private static bool Prefix(StatusEffect __instance, ISerializableEntity target)
            => !GunsmithRuntimeEffectsPatch.ShouldSuppressManagedQuickSlotAfflictions(__instance, target);
    }

    [HarmonyPatch(typeof(StatusEffect), nameof(StatusEffect.Apply), new[]
    {
        typeof(ActionType),
        typeof(float),
        typeof(Entity),
        typeof(IReadOnlyList<ISerializableEntity>),
        typeof(Vector2?)
    })]
    public static class GunsmithManagedTargetListAfflictionSuppressionPatch
    {
        [HarmonyPrefix]
        private static bool Prefix(StatusEffect __instance, IReadOnlyList<ISerializableEntity> targets)
            => !GunsmithRuntimeEffectsPatch.ShouldSuppressManagedQuickSlotAfflictions(__instance, targets);
    }
}
