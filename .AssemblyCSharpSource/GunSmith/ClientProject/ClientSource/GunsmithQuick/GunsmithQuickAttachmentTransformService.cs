namespace GunSmith
{
    public readonly record struct GunsmithQuickAttachmentTransform(
        Item WeaponItem,
        Item AttachmentItem,
        int QuickSlotIndex,
        Vector2 WorldPosition,
        Vector2 DrawPosition,
        float WorldRotation,
        float DrawRotation,
        Vector2 Direction,
        float FacingDirection,
        Submarine? Submarine,
        Hull? CurrentHull);

    public static class GunsmithQuickAttachmentTransformService
    {
        public static bool TryGetTransform(Item attachmentItem, out GunsmithQuickAttachmentTransform transform)
        {
            transform = default;
            if (attachmentItem == null || attachmentItem.Removed)
            {
                return false;
            }

            if (attachmentItem.ParentInventory?.Owner is not Item weaponItem)
            {
                return false;
            }

            return TryGetTransform(weaponItem, attachmentItem, out transform);
        }

        public static bool TryGetTransform(Item weaponItem, Item attachmentItem, out GunsmithQuickAttachmentTransform transform)
        {
            transform = default;
            if (!TryGetDirectQuickSlotIndex(weaponItem, attachmentItem, out int quickSlotIndex))
            {
                return false;
            }

            return TryGetTransform(weaponItem, attachmentItem, quickSlotIndex, out transform);
        }

        public static bool TryGetTransform(Item weaponItem, Item attachmentItem, int quickSlotIndex, out GunsmithQuickAttachmentTransform transform)
        {
            transform = default;
            if (!IsValidQuickSlotAttachment(weaponItem, attachmentItem, quickSlotIndex))
            {
                return false;
            }

            if (!GunsmithQuickSlotLayoutPatch.TryGetLayoutRule(weaponItem, quickSlotIndex, out GunsmithQuickSlotLayoutPatch.QuickSlotLayoutRule rule))
            {
                return false;
            }

            return TryCreateTransform(weaponItem, attachmentItem, quickSlotIndex, rule, out transform);
        }

        internal static bool TryCreateTransform(
            Item weaponItem,
            Item attachmentItem,
            int quickSlotIndex,
            GunsmithQuickSlotLayoutPatch.QuickSlotLayoutRule rule,
            out GunsmithQuickAttachmentTransform transform)
        {
            transform = default;
            if (weaponItem == null || weaponItem.Removed || attachmentItem == null || attachmentItem.Removed)
            {
                return false;
            }

            if (!GunsmithApi.TryCanvasPointToItemLocal(weaponItem, rule.CanvasAnchor, out Vector2 itemLocalPos))
            {
                return false;
            }

            itemLocalPos += rule.ItemPosOffset;

            bool hasWorldPosition = GunsmithQuickTransformMath.TryItemLocalToWorldPosition(
                weaponItem,
                itemLocalPos,
                drawPosition: false,
                out Vector2 worldPosition);
            bool hasDrawPosition = GunsmithQuickTransformMath.TryItemLocalToWorldPosition(
                weaponItem,
                itemLocalPos,
                drawPosition: true,
                out Vector2 drawPosition);
            float worldRotation = ToWorldRotation(weaponItem, rule.RotationDegrees, drawPosition: false);
            float drawRotation = ToWorldRotation(weaponItem, rule.RotationDegrees, drawPosition: true);
            Vector2 direction = ToForwardDirection(weaponItem, rule.RotationDegrees, drawPosition: true);
            if (!hasWorldPosition ||
                !hasDrawPosition ||
                !float.IsFinite(worldRotation) ||
                !float.IsFinite(drawRotation) ||
                !GunsmithQuickTransformMath.IsFinite(direction) ||
                direction.LengthSquared() < 0.0001f)
            {
                DebugConsole.ThrowError(
                    $"GunSmith QAT produced an invalid quick attachment transform. " +
                    $"weapon={weaponItem.Prefab.Identifier.Value}, " +
                    $"attachment={attachmentItem.Prefab.Identifier.Value}, " +
                    $"slot={quickSlotIndex}, " +
                    $"worldPosition={worldPosition}, drawPosition={drawPosition}, " +
                    $"worldRotation={worldRotation}, drawRotation={drawRotation}, direction={direction}");
                return false;
            }
            direction.Normalize();

            transform = new GunsmithQuickAttachmentTransform(
                weaponItem,
                attachmentItem,
                quickSlotIndex,
                worldPosition,
                drawPosition,
                worldRotation,
                drawRotation,
                direction,
                GetFacingDirection(weaponItem),
                weaponItem.Submarine,
                weaponItem.CurrentHull);
            return true;
        }

        private static bool TryGetDirectQuickSlotIndex(Item weaponItem, Item attachmentItem, out int quickSlotIndex)
        {
            quickSlotIndex = -1;
            if (weaponItem == null || weaponItem.Removed || attachmentItem == null || attachmentItem.Removed || weaponItem.OwnInventory == null)
            {
                return false;
            }

            for (int i = 0; i < weaponItem.OwnInventory.slots.Length; i++)
            {
                if (weaponItem.OwnInventory.slots[i].Items.Contains(attachmentItem))
                {
                    quickSlotIndex = i;
                    return true;
                }
            }

            return false;
        }

        private static bool IsValidQuickSlotAttachment(Item weaponItem, Item attachmentItem, int quickSlotIndex)
        {
            if (weaponItem == null || weaponItem.Removed || attachmentItem == null || attachmentItem.Removed || weaponItem.OwnInventory == null)
            {
                return false;
            }

            return quickSlotIndex >= 0 &&
                   quickSlotIndex < weaponItem.OwnInventory.slots.Length &&
                   weaponItem.OwnInventory.slots[quickSlotIndex].Items.Contains(attachmentItem);
        }

        private static float ToWorldRotation(Item owner, float localRotationDegrees, bool drawPosition)
        {
            float rotation = MathHelper.ToRadians(localRotationDegrees);
            PhysicsBody? rootBody = owner.RootContainer?.body ?? owner.body;
            if (owner.body != null)
            {
                rotation *= rootBody?.Dir ?? owner.body.Dir;
                rotation += drawPosition ? owner.body.DrawRotation : owner.body.Rotation;
            }
            else
            {
                rotation += -owner.RotationRad;
            }

            return rotation;
        }

        private static Vector2 ToForwardDirection(Item owner, float localRotationDegrees, bool drawPosition)
        {
            float localRotation = MathHelper.ToRadians(localRotationDegrees);
            float rotation;
            PhysicsBody? rootBody = owner.RootContainer?.body ?? owner.body;
            if (owner.body != null)
            {
                float dir = rootBody?.Dir ?? owner.body.Dir;
                rotation = drawPosition ? owner.body.DrawRotation : owner.body.Rotation;
                rotation += dir >= 0.0f ? localRotation : -localRotation - MathHelper.Pi;
            }
            else
            {
                rotation = -owner.RotationRad + localRotation;
                if (owner.FlippedX && owner.Prefab.CanSpriteFlipX)
                {
                    rotation -= MathHelper.Pi;
                }
            }

            return new Vector2(MathF.Cos(rotation), MathF.Sin(rotation));
        }

        private static float GetFacingDirection(Item owner)
        {
            PhysicsBody? rootBody = owner.RootContainer?.body ?? owner.body;
            if (rootBody != null)
            {
                return rootBody.Dir >= 0.0f ? 1.0f : -1.0f;
            }

            return owner.FlippedX && owner.Prefab.CanSpriteFlipX ? -1.0f : 1.0f;
        }
    }
}
