using Barotrauma.Items.Components;

namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithRuntimeEffectsPatch
    {
        [HarmonyPatch(typeof(Character), nameof(Character.GetStatValue), new[] { typeof(StatTypes), typeof(bool) })]
        [HarmonyPostfix]
        private static void ApplyGunsmithCharacterStats(Character __instance, StatTypes statType, ref float __result)
        {
            if (!TryGetHeldGunsmithState(__instance, out GunsmithRuntimeState? state))
            {
                return;
            }

            __result += statType switch
            {
                StatTypes.RangedSpreadReduction => state.Stats.RangedSpreadReduction ,
                StatTypes.RangedAttackMultiplier => state.Stats.RangedAttackMultiplier,
                StatTypes.RangedAttackSpeed => state.Stats.RangedAttackSpeed,
                StatTypes.WeaponsSkillBonus => state.Stats.WeaponsSkillBonus,
                StatTypes.WalkingSpeed => state.Stats.WalkingSpeed,
                StatTypes.MovementSpeed => state.Stats.MovementSpeed,
                StatTypes.FlowResistance => state.Stats.FlowResistance,
                StatTypes.WeaponsSkillGainSpeed => state.Stats.WeaponsSkillGainSpeed,
                StatTypes.ExperienceGainMultiplier => state.Stats.ExperienceGainMultiplier,
                StatTypes.SoundRangeMultiplier => state.Stats.SoundRangeMultiplier,
                StatTypes.MaximumHealthMultiplier => state.Stats.MaximumHealthMultiplier,
                _ => 0.0f
            };
        }

        internal static bool ShouldSuppressManagedQuickSlotAfflictions(StatusEffect statusEffect, object[] args)
        {
            if (statusEffect.Afflictions == null || statusEffect.Afflictions.Count == 0)
            {
                return false;
            }

            foreach (object arg in args)
            {
                if (arg is Item item && IsContainedInGunsmithItem(item))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool TryGetHeldGunsmithState(Character character, out GunsmithRuntimeState state)
        {
            state = null!;
            if (character == null || character.Removed || character.HeldItems == null)
            {
                return false;
            }

            foreach (Item item in character.HeldItems)
            {
                if (GunsmithApi.TryGetRuntimeState(item, out state))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool IsContainedInGunsmithItem(Item item)
        {
            string itemIdentifier = item.Prefab.Identifier.Value;
            Inventory? inventory = item.ParentInventory;
            while (inventory != null)
            {
                if (inventory.Owner is Item ownerItem &&
                    GunsmithApi.TryGetRuntimeState(ownerItem, out GunsmithRuntimeState? state) &&
                    state.ManagedItemIdentifiers.Contains(itemIdentifier))
                {
                    return true;
                }

                inventory = inventory.Owner is Item parentItem ? parentItem.ParentInventory : null;
            }

            return false;
        }
    }

    [HarmonyPatch]
    public static class GunsmithManagedItemAfflictionSuppressionPatch
    {
        private static IEnumerable<MethodBase> TargetMethods()
            => AccessTools.GetDeclaredMethods(typeof(StatusEffect))
                .Where(method => method.Name == nameof(StatusEffect.Apply));

        [HarmonyPrefix]
        private static bool Prefix(StatusEffect __instance, object[] __args)
            => !GunsmithRuntimeEffectsPatch.ShouldSuppressManagedQuickSlotAfflictions(__instance, __args);
    }
}
