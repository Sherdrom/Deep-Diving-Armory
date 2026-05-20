using Barotrauma.Items.Components;
using FarseerPhysics;

namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithQuickSlotLayoutPatch
    {
        private static readonly ConcurrentDictionary<Item, Dictionary<int, QuickSlotLayoutRule>> RulesByItem = new();
        private static readonly HashSet<Item> SuspendedItems = new();
        private static readonly object SuspendedItemsLock = new();

        public static void ClearLayouts(Item item)
        {
            if (item == null) { return; }
            RulesByItem.TryRemove(item, out _);
        }

        public static void RegisterLayout(Item item, int slotIndex, Vector2 canvasAnchor, Vector2 canvasOrigin, Vector2 itemPosOffset, float rotation, bool hide)
        {
            if (item == null || item.Removed || slotIndex < 0)
            {
                return;
            }

            Dictionary<int, QuickSlotLayoutRule> rules = RulesByItem.GetOrAdd(item, _ => new Dictionary<int, QuickSlotLayoutRule>());
            lock (rules)
            {
                rules[slotIndex] = new QuickSlotLayoutRule(canvasAnchor, canvasOrigin, itemPosOffset, rotation);
            }
        }

        internal static bool TryGetLayoutRule(Item item, int slotIndex, out QuickSlotLayoutRule rule)
        {
            rule = default;
            if (item == null || item.Removed || slotIndex < 0)
            {
                return false;
            }

            if (!RulesByItem.TryGetValue(item, out Dictionary<int, QuickSlotLayoutRule>? rules))
            {
                return false;
            }

            lock (rules)
            {
                return rules.TryGetValue(slotIndex, out rule);
            }
        }

        public static void ApplyLayouts(Item item)
        {
            if (item == null || item.Removed || item.OwnInventory == null || IsSuspended(item))
            {
                return;
            }

            if (!RulesByItem.TryGetValue(item, out Dictionary<int, QuickSlotLayoutRule>? rules) || rules.Count == 0)
            {
                return;
            }

            KeyValuePair<int, QuickSlotLayoutRule>[] snapshot;
            lock (rules)
            {
                snapshot = rules.ToArray();
            }

            foreach ((int slotIndex, QuickSlotLayoutRule rule) in snapshot)
            {
                if (slotIndex < 0 || slotIndex >= item.OwnInventory.slots.Length)
                {
                    continue;
                }

                foreach (Item containedItem in item.OwnInventory.slots[slotIndex].Items.ToArray())
                {
                    ApplyLayoutToContainedItem(item, containedItem, slotIndex, rule);
                }
            }
        }

        public static void SuspendLayouts(Item item)
        {
            if (item == null || item.Removed) { return; }
            lock (SuspendedItemsLock)
            {
                SuspendedItems.Add(item);
            }
            item.SetContainedItemPositions();
        }

        public static void ResumeLayouts(Item item)
        {
            if (item == null || item.Removed) { return; }
            lock (SuspendedItemsLock)
            {
                SuspendedItems.Remove(item);
            }
            ApplyLayouts(item);
        }

        [HarmonyPatch(typeof(Item), nameof(Item.SetContainedItemPositions))]
        [HarmonyPostfix]
        private static void ApplyGunsmithQuickSlotLayouts(Item __instance)
        {
            ApplyLayouts(__instance);
        }

        private static bool IsSuspended(Item item)
        {
            lock (SuspendedItemsLock)
            {
                return SuspendedItems.Contains(item);
            }
        }

        private static void ApplyLayoutToContainedItem(Item owner, Item containedItem, int slotIndex, QuickSlotLayoutRule rule)
        {
            if (containedItem == null || containedItem.Removed)
            {
                return;
            }

            if (!GunsmithQuickAttachmentTransformService.TryCreateTransform(owner, containedItem, slotIndex, rule, out GunsmithQuickAttachmentTransform transform))
            {
                return;
            }

            if (containedItem.body != null)
            {
                Vector2 simPos = ConvertUnits.ToSimUnits(transform.WorldPosition);
                containedItem.body.FarseerBody.SetTransformIgnoreContacts(ref simPos, transform.WorldRotation);
                containedItem.body.UpdateDrawPosition(interpolate: false);
                containedItem.body.Submarine = owner.Submarine;
            }

            containedItem.Rect = new Rectangle(
                (int)(transform.WorldPosition.X - containedItem.Rect.Width / 2.0f),
                (int)(transform.WorldPosition.Y + containedItem.Rect.Height / 2.0f),
                containedItem.Rect.Width,
                containedItem.Rect.Height);
            containedItem.Submarine = owner.Submarine;
            containedItem.CurrentHull = owner.CurrentHull;

            foreach (LightComponent lightComponent in containedItem.GetComponents<LightComponent>())
            {
                lightComponent.SetLightSourceTransform();
            }
        }

        internal readonly record struct QuickSlotLayoutRule(Vector2 CanvasAnchor, Vector2 CanvasOrigin, Vector2 ItemPosOffset, float RotationDegrees);
    }
}
