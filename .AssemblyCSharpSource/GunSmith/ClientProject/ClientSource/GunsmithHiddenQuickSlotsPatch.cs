namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithHiddenQuickSlotsPatch
    {
        private static readonly Dictionary<string, HashSet<int>> HiddenSlotsByItemIdentifier = new(StringComparer.OrdinalIgnoreCase);
        private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<Inventory, LayoutCache> OriginalLayoutsByInventory = new();

        public static void RegisterHiddenSlots(string itemIdentifier, string slotSpec)
        {
            if (string.IsNullOrWhiteSpace(itemIdentifier))
            {
                return;
            }

            HashSet<int> slots = new();
            foreach (string rawSlot in slotSpec.Split(','))
            {
                if (int.TryParse(rawSlot.Trim(), out int slotIndex) && slotIndex >= 0)
                {
                    slots.Add(slotIndex);
                }
            }

            if (slots.Count == 0)
            {
                HiddenSlotsByItemIdentifier.Remove(itemIdentifier);
                return;
            }

            HiddenSlotsByItemIdentifier[itemIdentifier] = slots;
        }

        [HarmonyPatch(typeof(Inventory), nameof(Inventory.HideSlot))]
        [HarmonyPrefix]
        private static bool HideManagedQuickSlots(Inventory __instance, int __0, ref bool __result)
        {
            if (!__instance.isSubInventory)
            {
                PackVisibleSlotsFirst(__instance);
            }

            if (IsManagedQuickSlot(__instance, __0))
            {
                __result = true;
                return false;
            }
            return true;
        }

        [HarmonyPatch(typeof(Inventory), nameof(Inventory.Update))]
        [HarmonyPrefix]
        private static void PackSubInventoryBeforeSlotUpdate(Inventory __instance, bool subInventory)
        {
            if (!subInventory)
            {
                return;
            }

            if (__instance.visualSlots == null || __instance.visualSlots.Length == 0)
            {
                return;
            }

            CaptureOriginalLayouts(__instance);
            PackVisibleSlotsFirst(__instance);
            Inventory.RefreshMouseOnInventory();
        }

        private static void CaptureOriginalLayouts(Inventory inventory)
        {
            if (inventory.visualSlots == null || inventory.visualSlots.Length == 0)
            {
                return;
            }

            OriginalLayoutsByInventory.Remove(inventory);
            OriginalLayoutsByInventory.Add(inventory, new LayoutCache(inventory.visualSlots, inventory.visualSlots.Select(SlotLayout.FromVisualSlot).ToArray()));
        }

        private static void PackVisibleSlotsFirst(Inventory __instance)
        {
            if (__instance.visualSlots == null || __instance.visualSlots.Length == 0)
            {
                return;
            }

            HashSet<int>? hiddenSlots = GetManagedHiddenSlots(__instance);
            if (hiddenSlots == null || hiddenSlots.Count == 0)
            {
                return;
            }

            List<int> visibleIndices = new();
            for (int i = 0; i < __instance.visualSlots.Length; i++)
            {
                if (!hiddenSlots.Contains(i))
                {
                    visibleIndices.Add(i);
                }
            }

            if (visibleIndices.Count == 0 || visibleIndices.Count == __instance.visualSlots.Length)
            {
                return;
            }

            if (!OriginalLayoutsByInventory.TryGetValue(__instance, out LayoutCache? layoutCache) ||
                layoutCache.VisualSlots != __instance.visualSlots ||
                layoutCache.Layouts.Length != __instance.visualSlots.Length)
            {
                CaptureOriginalLayouts(__instance);
                if (!OriginalLayoutsByInventory.TryGetValue(__instance, out layoutCache) ||
                    layoutCache.VisualSlots != __instance.visualSlots ||
                    layoutCache.Layouts.Length != __instance.visualSlots.Length)
                {
                    return;
                }
            }

            SlotLayout[] originalLayouts = layoutCache.Layouts;
            for (int displayIndex = 0; displayIndex < visibleIndices.Count; displayIndex++)
            {
                originalLayouts[displayIndex].ApplyTo(__instance.visualSlots[visibleIndices[displayIndex]]);
            }

            SlotLayout hiddenLayout = originalLayouts[0];
            foreach (int hiddenIndex in hiddenSlots)
            {
                if (hiddenIndex >= 0 && hiddenIndex < __instance.visualSlots.Length)
                {
                    hiddenLayout.ApplyTo(__instance.visualSlots[hiddenIndex]);
                }
            }
        }

        private static bool IsManagedQuickSlot(Inventory inventory, int slotIndex)
        {
            return GetManagedHiddenSlots(inventory) is HashSet<int> hiddenSlots
                && hiddenSlots.Contains(slotIndex);
        }

        private static HashSet<int>? GetManagedHiddenSlots(Inventory inventory)
        {
            if (inventory.Owner is not Item item || item.Removed || item.Prefab == null) { return null; }
            string itemIdentifier = item.Prefab.Identifier.Value;
            return HiddenSlotsByItemIdentifier.TryGetValue(itemIdentifier, out HashSet<int>? hiddenSlots) ? hiddenSlots : null;
        }

        private sealed class LayoutCache
        {
            public readonly VisualSlot[] VisualSlots;
            public readonly SlotLayout[] Layouts;

            public LayoutCache(VisualSlot[] visualSlots, SlotLayout[] layouts)
            {
                VisualSlots = visualSlots;
                Layouts = layouts;
            }
        }

        private readonly struct SlotLayout
        {
            private readonly Rectangle rect;
            private readonly Rectangle interactRect;
            private readonly int subInventoryDir;

            private SlotLayout(Rectangle rect, Rectangle interactRect, int subInventoryDir)
            {
                this.rect = rect;
                this.interactRect = interactRect;
                this.subInventoryDir = subInventoryDir;
            }

            public static SlotLayout FromVisualSlot(VisualSlot slot)
            {
                return new SlotLayout(slot.Rect, slot.InteractRect, slot.SubInventoryDir);
            }

            public void ApplyTo(VisualSlot slot)
            {
                slot.Rect = rect;
                slot.InteractRect = interactRect;
                slot.SubInventoryDir = subInventoryDir;
            }
        }
    }
}
