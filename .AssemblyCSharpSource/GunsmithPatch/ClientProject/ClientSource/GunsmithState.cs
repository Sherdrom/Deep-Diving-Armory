namespace GunsmithPatch
{
    public sealed class GunsmithLayer
    {
        public string TexturePath { get; init; } = string.Empty;
        public Rectangle SourceRect { get; init; }
        public Vector2 Offset { get; init; }
        public int Order { get; init; }
    }

    internal sealed class GunsmithSpriteState
    {
        public string Signature { get; init; } = string.Empty;
        public Texture2D Texture { get; init; } = null!;
        public Sprite WorldSprite { get; init; } = null!;
        public Sprite InventorySprite { get; init; } = null!;
    }
}
