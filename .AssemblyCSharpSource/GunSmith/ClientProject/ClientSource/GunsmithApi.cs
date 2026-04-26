namespace GunSmith
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

        public static void ApplyFromLua(Item item, string signature, string layerSpec, string inventorySpec, int width, int height)
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
            GunsmithInventorySettings inventorySettings = ParseInventorySettings(inventorySpec);

            bool shouldOwnWorldSprite = item.HasTag("deep_gunsmith");
            bool shouldReplaceActiveSprite =
                shouldOwnWorldSprite ||
                ReferenceEquals(item.activeSprite, item.Prefab.Sprite) ||
                (existing != null && ReferenceEquals(item.activeSprite, existing.WorldSprite));

            Texture2D texture;
            try
            {
                texture = ComposeTexture(layers, Math.Max(width, 1), Math.Max(height, 1));
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to compose runtime texture: {ex.Message}");
                return;
            }

            Rectangle contentBounds = CalculateContentBounds(layers, Math.Max(width, 1), Math.Max(height, 1));
            Texture2D inventoryTexture = CreateInventoryTexture(texture, contentBounds, inventorySettings);
            Sprite? worldSprite = CreateWorldSprite(item.Prefab.Sprite, texture);
            Sprite? inventorySprite = CreateInventorySprite(item.Prefab.InventoryIcon ?? item.Prefab.Sprite, inventoryTexture);
            if (worldSprite == null || inventorySprite == null)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to create runtime sprites for '{item.Prefab.Identifier.Value}'.");
                texture.Dispose();
                inventoryTexture.Dispose();
                return;
            }

            GunsmithSpriteState state = new()
            {
                Signature = signature,
                Texture = texture,
                InventoryTexture = inventoryTexture,
                WorldSprite = worldSprite,
                InventorySprite = inventorySprite,
                ContentBounds = contentBounds,
                Layers = layers
            };

            itemStates[item] = state;
            ApplyState(item, state, shouldReplaceActiveSprite);

            if (existing != null && ReferenceEquals(item.activeSprite, existing.WorldSprite))
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to apply updated world sprite for '{item.Prefab.Identifier.Value}'.");
            }

            if (existing != null)
            {
                existing.Texture.Dispose();
                existing.InventoryTexture.Dispose();
            }
        }

        public static void ClearFromLua(Item item)
        {
            if (item == null) { return; }
            RemoveState(item);
            RestoreVanillaSprite(item);
        }

        internal static bool TryGetState(Item item, out GunsmithSpriteState state)
            => itemStates.TryGetValue(item, out state!);

        internal static bool TryGetValidState(Item item, out GunsmithSpriteState state)
        {
            if (itemStates.TryGetValue(item, out state!) && IsStateUsable(state))
            {
                return true;
            }

            if (state != null)
            {
                ClearFromLua(item);
            }
            return false;
        }

        internal static void RemoveState(Item item)
        {
            if (itemStates.TryRemove(item, out GunsmithSpriteState? state))
            {
                if (!state.Texture.IsDisposed)
                {
                    state.Texture.Dispose();
                }
                if (!state.InventoryTexture.IsDisposed)
                {
                    state.InventoryTexture.Dispose();
                }
            }
        }

        internal static void ApplyState(Item item, GunsmithSpriteState state, bool forceWorldSprite = false)
        {
            if (!IsStateUsable(state))
            {
                ClearFromLua(item);
                return;
            }

            item.OverrideInventorySprite = state.InventorySprite;
            if (item.HasTag("deep_gunsmith") || forceWorldSprite || ReferenceEquals(item.activeSprite, item.Prefab.Sprite))
            {
                item.activeSprite = state.WorldSprite;
            }
        }

        internal static void EnsureSafeSprite(Item item)
        {
            if (itemStates.TryGetValue(item, out GunsmithSpriteState? state) && !IsStateUsable(state))
            {
                ClearFromLua(item);
            }
        }

        private static bool IsStateUsable(GunsmithSpriteState state)
            => state.Texture != null && !state.Texture.IsDisposed && state.InventoryTexture != null && !state.InventoryTexture.IsDisposed;

        private static void RestoreVanillaSprite(Item item)
        {
            item.OverrideInventorySprite = null;
            item.activeSprite = item.Prefab.Sprite;
            item.SetActiveSprite();
        }

        public static void Dispose()
        {
            CloseWindow();

            foreach (KeyValuePair<Item, GunsmithSpriteState> pair in itemStates.ToArray())
            {
                if (itemStates.TryRemove(pair.Key, out GunsmithSpriteState? state))
                {
                    if (!state.Texture.IsDisposed)
                    {
                        state.Texture.Dispose();
                    }
                    if (!state.InventoryTexture.IsDisposed)
                    {
                        state.InventoryTexture.Dispose();
                    }
                }
                RestoreVanillaSprite(pair.Key);
            }

            foreach (Texture2D texture in textureCache.Values)
            {
                if (!texture.IsDisposed)
                {
                    texture.Dispose();
                }
            }
            textureCache.Clear();

            spriteBatch?.Dispose();
            spriteBatch = null;
            graphicsDevice = null;
        }
    }
}
