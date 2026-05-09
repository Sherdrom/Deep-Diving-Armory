namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithHiddenQuickSlotsPatch
    {
        private static readonly Dictionary<string, HashSet<int>> ManagedSlotsByItemIdentifier = new(StringComparer.OrdinalIgnoreCase);
        private static readonly Dictionary<string, Dictionary<int, HashSet<string>>> VisibleWhenContainedByItemIdentifier = new(StringComparer.OrdinalIgnoreCase);
        private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<Inventory, LayoutCache> OriginalLayoutsByInventory = new();
        private static readonly HashSet<Item> QuickMutationItems = new();

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
                ManagedSlotsByItemIdentifier.Remove(itemIdentifier);
                return;
            }

            ManagedSlotsByItemIdentifier[itemIdentifier] = slots;
        }

        public static void RegisterVisibleWhenContained(string itemIdentifier, int slotIndex, string identifierSpec)
        {
            if (string.IsNullOrWhiteSpace(itemIdentifier) || slotIndex < 0)
            {
                return;
            }

            HashSet<string> identifiers = new(StringComparer.OrdinalIgnoreCase);
            foreach (string rawIdentifier in identifierSpec.Split(','))
            {
                string identifier = rawIdentifier.Trim();
                if (!string.IsNullOrWhiteSpace(identifier))
                {
                    identifiers.Add(identifier);
                }
            }

            if (!VisibleWhenContainedByItemIdentifier.TryGetValue(itemIdentifier, out Dictionary<int, HashSet<string>>? rules))
            {
                rules = new Dictionary<int, HashSet<string>>();
                VisibleWhenContainedByItemIdentifier[itemIdentifier] = rules;
            }

            if (identifiers.Count == 0)
            {
                rules.Remove(slotIndex);
                if (rules.Count == 0)
                {
                    VisibleWhenContainedByItemIdentifier.Remove(itemIdentifier);
                }
                return;
            }

            rules[slotIndex] = identifiers;
        }

        public static void BeginQuickSlotMutation(Item item)
        {
            if (item == null || item.Removed) { return; }
            QuickMutationItems.Add(item);
        }

        public static void EndQuickSlotMutation(Item item)
        {
            if (item == null) { return; }
            QuickMutationItems.Remove(item);
        }

        [HarmonyPatch(typeof(Inventory), nameof(Inventory.HideSlot))]
        [HarmonyPrefix]
        private static bool HideManagedQuickSlots(Inventory __instance, int __0, ref bool __result)
        {
            if (!__instance.isSubInventory)
            {
                PackVisibleSlotsFirst(__instance);
            }

            if (IsManagedSlot(__instance, __0) && !ShouldShowManagedSlot(__instance, __0))
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

        [HarmonyPatch(typeof(Inventory), nameof(Inventory.UpdateDragging))]
        [HarmonyPrefix]
        private static bool HandleQuickOverlayDraggingBeforeWorldDrop()
            => !GunsmithApi.TryHandleQuickOverlayDragging();

        [HarmonyPatch(typeof(Character), nameof(Character.ControlLocalPlayer))]
        [HarmonyPrefix]
        private static bool BlockGunsmithWindowCharacterInput(Character __instance, ref bool moveCam)
        {
            if (__instance == Character.Controlled && GunsmithApi.IsGunsmithWindowBlockingInput && GunsmithApi.ActiveWindowForInputBlock != null)
            {
                moveCam = false;
            }
            return true;
        }

        [HarmonyPatch(typeof(Character), nameof(Character.ControlLocalPlayer))]
        [HarmonyPostfix]
        private static void BlockGunsmithWindowMouseInput(Character __instance)
        {
            if (__instance != Character.Controlled || !GunsmithApi.IsGunsmithWindowBlockingInput || GunsmithApi.ActiveWindowForInputBlock == null)
            {
                return;
            }

            __instance.ClearInput(InputType.Aim);
            __instance.ClearInput(InputType.Shoot);
            __instance.ClearInput(InputType.Use);
            __instance.ClearInput(InputType.Select);

            Vector2 cursorOffset = PlayerInput.MouseSpeed;
            if (cursorOffset.LengthSquared() > 100.0f)
            {
                cursorOffset.Normalize();
                cursorOffset *= 10.0f;
            }
            __instance.CursorPosition = __instance.Position + cursorOffset;
            __instance.SmoothedCursorPosition = __instance.CursorPosition;
        }

        [HarmonyPatch(typeof(ItemInventory), nameof(ItemInventory.FindAllowedSlot))]
        [HarmonyPrefix]
        private static bool SkipManagedSlotsWhenAutoPutting(ItemInventory __instance, Item item, bool ignoreCondition, ref int __result)
        {
            if (!HasManagedSlots(__instance) || IsQuickMutationAllowed(__instance))
            {
                return true;
            }

            __result = FindAllowedNonManagedSlot(__instance, item, ignoreCondition);
            return false;
        }

        [HarmonyPatch(typeof(ItemInventory), nameof(ItemInventory.TryPutItem), typeof(Item), typeof(int), typeof(bool), typeof(bool), typeof(Character), typeof(bool), typeof(bool), typeof(bool))]
        [HarmonyPrefix]
        private static bool BlockDirectManagedSlotPut(ItemInventory __instance, Item item, int i, Character user, bool createNetworkEvent, bool ignoreCondition, bool triggerOnInsertedEffects, ref bool __result)
        {
            if (!IsManagedSlot(__instance, i) || IsQuickMutationAllowed(__instance))
            {
                return true;
            }

            Item? containedItem = i >= 0 && i < __instance.slots.Length ? __instance.slots[i].FirstOrDefault() : null;
            ItemInventory? containedInventory = containedItem?.OwnInventory;
            if (containedInventory != null && containedInventory.CanBePut(item))
            {
                __result = containedInventory.TryPutItem(item, user, null, createNetworkEvent, ignoreCondition, triggerOnInsertedEffects);
                return false;
            }

            __result = false;
            return false;
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
            List<int> hiddenIndices = new();
            for (int i = 0; i < __instance.visualSlots.Length; i++)
            {
                if (!hiddenSlots.Contains(i) || ShouldShowManagedSlot(__instance, i))
                {
                    visibleIndices.Add(i);
                }
                else
                {
                    hiddenIndices.Add(i);
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
            foreach (int hiddenIndex in hiddenIndices)
            {
                if (hiddenIndex >= 0 && hiddenIndex < __instance.visualSlots.Length)
                {
                    hiddenLayout.ApplyTo(__instance.visualSlots[hiddenIndex]);
                }
            }
        }

        private static bool IsManagedSlot(Inventory inventory, int slotIndex)
        {
            return GetManagedHiddenSlots(inventory) is HashSet<int> hiddenSlots
                && hiddenSlots.Contains(slotIndex);
        }

        private static bool HasManagedSlots(Inventory inventory)
        {
            return GetManagedHiddenSlots(inventory) is HashSet<int> hiddenSlots
                && hiddenSlots.Count > 0;
        }

        private static bool IsQuickMutationAllowed(Inventory inventory)
        {
            return inventory.Owner is Item item && QuickMutationItems.Contains(item);
        }

        private static int FindAllowedNonManagedSlot(ItemInventory inventory, Item item, bool ignoreCondition)
        {
            if (inventory.ItemOwnsSelf(item) || inventory.Contains(item) || !inventory.container.CanBeContained(item))
            {
                return -1;
            }

            for (int i = 0; i < inventory.capacity; i++)
            {
                if (!IsManagedSlot(inventory, i) && inventory.slots[i].Any() && inventory.CanBePutInSlot(item, i, ignoreCondition))
                {
                    return i;
                }
            }

            for (int i = 0; i < inventory.capacity; i++)
            {
                if (!IsManagedSlot(inventory, i) && inventory.CanBePutInSlot(item, i, ignoreCondition))
                {
                    return i;
                }
            }

            return -1;
        }

        private static bool ShouldShowManagedSlot(Inventory inventory, int slotIndex)
        {
            if (inventory.Owner is not Item ownerItem || ownerItem.Removed || ownerItem.Prefab == null) { return false; }
            string ownerIdentifier = ownerItem.Prefab.Identifier.Value;
            if (!VisibleWhenContainedByItemIdentifier.TryGetValue(ownerIdentifier, out Dictionary<int, HashSet<string>>? rules) ||
                !rules.TryGetValue(slotIndex, out HashSet<string>? identifiers) ||
                identifiers.Count == 0 ||
                slotIndex < 0 ||
                slotIndex >= inventory.slots.Length)
            {
                return false;
            }

            foreach (Item contained in inventory.slots[slotIndex].Items)
            {
                if (contained?.Prefab == null || contained.Removed) { continue; }
                string containedIdentifier = contained.Prefab.Identifier.Value;
                if (identifiers.Contains(containedIdentifier))
                {
                    return true;
                }

                foreach (string identifierOrTag in identifiers)
                {
                    if (contained.HasTag(identifierOrTag))
                    {
                        return true;
                    }
                }
            }

            return false;
        }

        private static HashSet<int>? GetManagedHiddenSlots(Inventory inventory)
        {
            if (inventory.Owner is not Item item || item.Removed || item.Prefab == null) { return null; }
            string itemIdentifier = item.Prefab.Identifier.Value;
            return ManagedSlotsByItemIdentifier.TryGetValue(itemIdentifier, out HashSet<int>? hiddenSlots) ? hiddenSlots : null;
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
