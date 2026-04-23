namespace GunsmithPatch
{
    public static partial class GunsmithApi
    {
        private static readonly ConcurrentDictionary<Item, GunsmithSpriteState> itemStates = new();
        private static readonly ConcurrentDictionary<string, Texture2D> textureCache = new(StringComparer.OrdinalIgnoreCase);
        private static GraphicsDevice? graphicsDevice;
        private static SpriteBatch? spriteBatch;

        public static bool IsReady => graphicsDevice != null && spriteBatch != null;

        public static void Initialize(GraphicsDevice graphics)
        {
            graphicsDevice = graphics;
            spriteBatch = new SpriteBatch(graphics);
        }

        public static void ApplyFromLua(Item item, string signature, string layerSpec, int width, int height)
        {
            if (!IsReady || item == null || item.Removed) { return; }
            if (string.IsNullOrWhiteSpace(signature) || string.IsNullOrWhiteSpace(layerSpec)) { return; }

            if (itemStates.TryGetValue(item, out GunsmithSpriteState? existing) && existing.Signature == signature)
            {
                ApplyState(item, existing);
                return;
            }

            List<GunsmithLayer> layers = ParseLayers(layerSpec);
            if (layers.Count == 0) { return; }

            Texture2D texture = ComposeTexture(layers, Math.Max(width, 1), Math.Max(height, 1));
            Sprite? worldSprite = CreateSprite(item.Prefab.Sprite, texture, width, height);
            Sprite? inventorySprite = CreateSprite(item.Prefab.InventoryIcon ?? item.Prefab.Sprite, texture, width, height);
            if (worldSprite == null || inventorySprite == null)
            {
                texture.Dispose();
                return;
            }

            GunsmithSpriteState state = new()
            {
                Signature = signature,
                Texture = texture,
                WorldSprite = worldSprite,
                InventorySprite = inventorySprite
            };

            if (itemStates.TryGetValue(item, out GunsmithSpriteState? oldState))
            {
                oldState.Texture.Dispose();
            }

            itemStates[item] = state;
            ApplyState(item, state);
        }

        public static void ClearFromLua(Item item)
        {
            if (item == null) { return; }
            RemoveState(item);
            item.OverrideInventorySprite = null;
            if (ReferenceEquals(item.activeSprite, item.Prefab.Sprite) == false)
            {
                item.SetActiveSprite();
            }
        }

        internal static bool TryGetState(Item item, out GunsmithSpriteState state)
            => itemStates.TryGetValue(item, out state!);

        internal static void RemoveState(Item item)
        {
            if (itemStates.TryRemove(item, out GunsmithSpriteState? state))
            {
                state.Texture.Dispose();
            }
        }

        internal static void ApplyState(Item item, GunsmithSpriteState state)
        {
            item.OverrideInventorySprite = state.InventorySprite;
            if (ReferenceEquals(item.activeSprite, item.Prefab.Sprite))
            {
                item.activeSprite = state.WorldSprite;
            }
        }

        public static void Dispose()
        {
            CloseWindow();

            foreach (GunsmithSpriteState state in itemStates.Values)
            {
                state.Texture.Dispose();
            }
            itemStates.Clear();

            foreach (Texture2D texture in textureCache.Values)
            {
                texture.Dispose();
            }
            textureCache.Clear();

            spriteBatch?.Dispose();
            spriteBatch = null;
            graphicsDevice = null;
        }
    }
}
