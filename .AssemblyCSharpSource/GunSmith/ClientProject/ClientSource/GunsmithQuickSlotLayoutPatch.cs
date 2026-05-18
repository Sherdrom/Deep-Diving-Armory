using Barotrauma.Items.Components;
using FarseerPhysics;

namespace GunSmith
{
    [HarmonyPatch]
    public static class GunsmithQuickSlotLayoutPatch
    {
        private static readonly ConcurrentDictionary<Item, Dictionary<int, QuickSlotLayoutRule>> RulesByItem = new();

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
                rules[slotIndex] = new QuickSlotLayoutRule(canvasAnchor, canvasOrigin, itemPosOffset, rotation, hide);
            }
        }

        public static void ApplyLayouts(Item item)
        {
            if (item == null || item.Removed || item.OwnInventory == null)
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
                    ApplyLayoutToContainedItem(item, containedItem, rule);
                }
            }
        }

        [HarmonyPatch(typeof(ItemContainer), nameof(ItemContainer.SetContainedItemPositions))]
        [HarmonyPostfix]
        private static void ApplyGunsmithQuickSlotLayouts(ItemContainer __instance)
        {
            if (__instance?.Item != null)
            {
                ApplyLayouts(__instance.Item);
            }
        }

        private static void ApplyLayoutToContainedItem(Item owner, Item containedItem, QuickSlotLayoutRule rule)
        {
            if (containedItem == null || containedItem.Removed)
            {
                return;
            }

            if (!GunsmithApi.TryCanvasPointToItemLocal(owner, rule.CanvasAnchor, rule.CanvasOrigin, out Vector2 itemLocalPos))
            {
                return;
            }

            itemLocalPos += rule.ItemPosOffset;
            Vector2 worldPos = ToWorldPosition(owner, itemLocalPos);
            float rotation = ToWorldRotation(owner, rule.RotationDegrees);

            if (containedItem.body != null)
            {
                try
                {
                    Vector2 simPos = ConvertUnits.ToSimUnits(worldPos);
                    containedItem.body.FarseerBody.SetTransformIgnoreContacts(ref simPos, rotation);
                    containedItem.body.UpdateDrawPosition(interpolate: false);
                    containedItem.body.Submarine = owner.Submarine;
                }
                catch (Exception ex)
                {
                    LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to apply quick slot layout to '{containedItem.Prefab?.Identifier.Value}': {ex.Message}");
                }
            }

            containedItem.Rect = new Rectangle(
                (int)(worldPos.X - containedItem.Rect.Width / 2.0f),
                (int)(worldPos.Y + containedItem.Rect.Height / 2.0f),
                containedItem.Rect.Width,
                containedItem.Rect.Height);
            containedItem.Submarine = owner.Submarine;
            containedItem.CurrentHull = owner.CurrentHull;
            containedItem.SetContainedItemPositions();

            foreach (LightComponent lightComponent in containedItem.GetComponents<LightComponent>())
            {
                lightComponent.SetLightSourceTransform();
            }
        }

        private static Vector2 ToWorldPosition(Item owner, Vector2 itemLocalPos)
        {
            PhysicsBody? rootBody = owner.RootContainer?.body ?? owner.body;
            if (owner.body != null)
            {
                Vector2 pos = itemLocalPos;
                pos.X *= rootBody?.Dir ?? owner.body.Dir;
                return Vector2.Transform(pos, Matrix.CreateRotationZ(owner.body.Rotation)) + owner.body.Position;
            }

            return owner.Position + itemLocalPos;
        }

        private static float ToWorldRotation(Item owner, float localRotationDegrees)
        {
            float rotation = MathHelper.ToRadians(localRotationDegrees);
            PhysicsBody? rootBody = owner.RootContainer?.body ?? owner.body;
            if (owner.body != null)
            {
                rotation *= rootBody?.Dir ?? owner.body.Dir;
                rotation += owner.body.Rotation;
            }
            else
            {
                rotation += -owner.RotationRad;
            }

            return rotation;
        }

        private readonly record struct QuickSlotLayoutRule(Vector2 CanvasAnchor, Vector2 CanvasOrigin, Vector2 ItemPosOffset, float RotationDegrees, bool Hide);
    }
}
