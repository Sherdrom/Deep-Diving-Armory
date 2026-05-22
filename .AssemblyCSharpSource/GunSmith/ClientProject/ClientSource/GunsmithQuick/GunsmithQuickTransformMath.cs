namespace GunSmith
{
    internal static class GunsmithQuickTransformMath
    {
        public static bool TryItemLocalToWorldPosition(Item item, Vector2 itemLocalDisplayPos, bool drawPosition, out Vector2 position)
        {
            position = Vector2.Zero;
            if (item == null || item.Removed || !IsFinite(itemLocalDisplayPos) || !float.IsFinite(item.Scale))
            {
                return false;
            }

            Vector2 localOffset = itemLocalDisplayPos * item.Scale;
            if (item.body != null)
            {
                if (item.body.Dir < 0.0f)
                {
                    localOffset.X = -localOffset.X;
                }

                float rotation = drawPosition ? item.body.DrawRotation : item.body.Rotation;
                Vector2 bodyPosition = drawPosition ? item.body.DrawPosition : item.body.Position;
                position = bodyPosition + Vector2.Transform(localOffset, Matrix.CreateRotationZ(rotation));
            }
            else
            {
                float rotation = item.RotationRad;
                position = (drawPosition ? item.DrawPosition : item.Position) + Vector2.Transform(localOffset, Matrix.CreateRotationZ(rotation));
            }

            return IsFinite(position);
        }

        public static bool IsFinite(Vector2 value)
            => float.IsFinite(value.X) && float.IsFinite(value.Y);
    }
}
