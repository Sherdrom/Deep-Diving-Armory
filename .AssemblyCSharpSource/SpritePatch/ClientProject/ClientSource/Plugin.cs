using Barotrauma;
using HarmonyLib;
using System.Collections.Concurrent;

namespace SpritePatch
{
    [HarmonyPatch]
    public static class UniversalSpritePatch
    {
        private sealed class ItemSpriteState
        {
            public Sprite? WorldSprite { get; init; }
            public Sprite? InventorySprite { get; init; }
        }

        private static readonly ConcurrentDictionary<Item, ItemSpriteState> itemSprites = new();

        [HarmonyPatch(typeof(Item), nameof(Item.Update))]
        [HarmonyPostfix]
        private static void EnsureSpriteInitialized(Item __instance)
        {
            if (!ShouldPatch(__instance)) { return; }

            ItemSpriteState state = itemSprites.GetOrAdd(__instance, CreateSpriteState);
            if (state.InventorySprite != null && __instance.OverrideInventorySprite != state.InventorySprite)
            {
                __instance.OverrideInventorySprite = state.InventorySprite;
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.SetActiveSprite))]
        [HarmonyPostfix]
        private static void UseIndependentWorldSprite(Item __instance)
        {
            if (!itemSprites.TryGetValue(__instance, out ItemSpriteState? state) || state.WorldSprite == null) { return; }

            if (ReferenceEquals(__instance.activeSprite, __instance.Prefab.Sprite))
            {
                __instance.activeSprite = state.WorldSprite;
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.Sprite), MethodType.Getter)]
        [HarmonyPostfix]
        private static void OverrideSpriteGetter(Item __instance, ref Sprite __result)
        {
            if (itemSprites.TryGetValue(__instance, out ItemSpriteState? state) && state.WorldSprite != null)
            {
                __result = state.WorldSprite;
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.Remove))]
        [HarmonyPrefix]
        private static void RemoveSpriteState(Item __instance)
        {
            itemSprites.TryRemove(__instance, out _);
        }

        private static bool ShouldPatch(Item? item)
        {
            ItemPrefab? prefab = item?.Prefab;
            if (prefab == null) { return false; }

            return prefab.ContentPackage == SpritePatch.Package
                && (prefab.Sprite != null || prefab.InventoryIcon != null);
        }

        private static ItemSpriteState CreateSpriteState(Item item)
        {
            Sprite? worldSprite = CloneSprite(item.Prefab.Sprite);
            Sprite? inventorySprite = CloneSprite(item.Prefab.InventoryIcon ?? item.Prefab.Sprite);

            if (inventorySprite != null)
            {
                item.OverrideInventorySprite = inventorySprite;
            }

            return new ItemSpriteState
            {
                WorldSprite = worldSprite,
                InventorySprite = inventorySprite
            };
        }

        private static Sprite? CloneSprite(Sprite? original)
        {
            if (original == null) { return null; }

            Sprite clone = new Sprite(original)
            {
                Origin = original.Origin,
                RelativeOrigin = original.RelativeOrigin,
                Depth = original.Depth,
                SourceRect = original.SourceRect,
                RelativeSize = original.RelativeSize,
                SourceElement = original.SourceElement,
                EntityIdentifier = original.EntityIdentifier,
                FilePath = original.FilePath
            };

            return clone;
        }
    }
}
