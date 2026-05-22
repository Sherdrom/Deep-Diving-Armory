namespace GunSmith
{
    public static partial class GunsmithApi
    {
        private static readonly ConcurrentDictionary<Item, GunsmithSpriteState> spriteStates = new();
        private static readonly ConcurrentDictionary<Item, GunsmithRuntimeState> runtimeStates = new();
        private static readonly ConcurrentDictionary<string, Texture2D> textureCache = new(StringComparer.OrdinalIgnoreCase);
        private static GraphicsDevice? graphicsDevice;
        private static SpriteBatch? spriteBatch;

        public static bool IsReady => graphicsDevice != null && spriteBatch != null;

        public static void Initialize(GraphicsDevice graphics)
        {
            graphicsDevice = graphics;
            spriteBatch = new SpriteBatch(graphics);
        }

        public static void ApplyFromLua(Item item, string signature, string layerSpec, string inventorySpec, string worldSpec, string statsSpec, string managedItemSpec, int width, int height)
        {
            if (!IsReady || item == null || item.Removed) { return; }
            if (string.IsNullOrWhiteSpace(signature) || string.IsNullOrWhiteSpace(layerSpec)) { return; }

            GunsmithRuntimeStats stats = ParseRuntimeStats(statsSpec);
            IReadOnlySet<string> managedItemIdentifiers = ParseIdentifierSet(managedItemSpec);
            GunsmithRuntimeState runtimeState = new()
            {
                Signature = signature,
                Stats = stats,
                ManagedItemIdentifiers = managedItemIdentifiers
            };

            string spriteSignature = BuildSpriteSignature(layerSpec, inventorySpec, worldSpec, width, height);
            if (spriteStates.TryGetValue(item, out GunsmithSpriteState? existing) && existing.Signature == spriteSignature)
            {
                runtimeStates[item] = runtimeState;
                ApplyState(item, existing);
                return;
            }

            List<GunsmithLayer> layers = ParseLayers(layerSpec);
            if (layers.Count == 0) { return; }
            GunsmithInventorySettings inventorySettings = ParseInventorySettings(inventorySpec);
            GunsmithWorldSettings worldSettings = ParseWorldSettings(worldSpec);

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
            Sprite? originalWorldSprite = item.Prefab.Sprite;
            Vector2 canvasOrigin = originalWorldSprite != null
                ? new Vector2(texture.Width * originalWorldSprite.RelativeOrigin.X, texture.Height * originalWorldSprite.RelativeOrigin.Y)
                : new Vector2(texture.Width * 0.5f, texture.Height * 0.5f);
            Texture2D worldTexture = CreateWorldTexture(texture, contentBounds, worldSettings, canvasOrigin, out Vector2 worldOrigin);
            Texture2D inventoryTexture = CreateInventoryTexture(texture, contentBounds, inventorySettings);
            Sprite? worldSprite = CreateWorldSprite(originalWorldSprite, worldTexture, worldOrigin);
            Sprite? inventorySprite = CreateInventorySprite(item.Prefab.InventoryIcon ?? item.Prefab.Sprite, inventoryTexture);
            if (worldSprite == null || inventorySprite == null)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to create runtime sprites for '{item.Prefab.Identifier.Value}'.");
                texture.Dispose();
                worldTexture.Dispose();
                inventoryTexture.Dispose();
                return;
            }

            GunsmithSpriteState state = new()
            {
                Signature = spriteSignature,
                Texture = texture,
                WorldTexture = worldTexture,
                InventoryTexture = inventoryTexture,
                WorldSprite = worldSprite,
                InventorySprite = inventorySprite,
                ContentBounds = contentBounds,
                Layers = layers,
                CanvasOrigin = canvasOrigin,
                WorldSettings = worldSettings
            };

            spriteStates[item] = state;
            runtimeStates[item] = runtimeState;
            ApplyState(item, state, shouldReplaceActiveSprite);

            if (existing != null && ReferenceEquals(item.activeSprite, existing.WorldSprite))
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to apply updated world sprite for '{item.Prefab.Identifier.Value}'.");
            }

            if (existing != null)
            {
                existing.Texture.Dispose();
                existing.WorldTexture.Dispose();
                existing.InventoryTexture.Dispose();
            }
        }

        public static void ClearFromLua(Item item)
        {
            if (item == null) { return; }
            RemoveState(item);
            RestoreVanillaSprite(item);
        }

        internal static bool TryGetValidState(Item item, out GunsmithSpriteState state)
        {
            if (spriteStates.TryGetValue(item, out state!) && IsStateUsable(state))
            {
                return true;
            }

            if (state != null)
            {
                ClearFromLua(item);
            }
            return false;
        }

        internal static bool TryGetRuntimeState(Item? item, out GunsmithRuntimeState state)
        {
            state = null!;
            return item != null && !item.Removed && runtimeStates.TryGetValue(item, out state!);
        }

        internal static bool TryCanvasPointToItemLocal(Item item, Vector2 canvasPoint, out Vector2 localPoint)
        {
            localPoint = Vector2.Zero;
            if (!TryGetValidState(item, out GunsmithSpriteState state))
            {
                return false;
            }

            Vector2 delta = (canvasPoint - state.CanvasOrigin) * Math.Max(state.WorldSettings.Scale, 0.01f);
            Vector2 textureOffset = state.WorldSettings.Offset + Rotate(delta, MathHelper.ToRadians(state.WorldSettings.RotationDegrees));
            localPoint = new Vector2(textureOffset.X, -textureOffset.Y);
            return true;
        }

        internal static void RemoveState(Item item)
        {
            runtimeStates.TryRemove(item, out _);
            GunsmithQuickSlotLayoutPatch.ClearLayouts(item);
            if (spriteStates.TryRemove(item, out GunsmithSpriteState? state))
            {
                if (!state.Texture.IsDisposed)
                {
                    state.Texture.Dispose();
                }
                if (!state.InventoryTexture.IsDisposed)
                {
                    state.InventoryTexture.Dispose();
                }
                if (!state.WorldTexture.IsDisposed)
                {
                    state.WorldTexture.Dispose();
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
            if (spriteStates.TryGetValue(item, out GunsmithSpriteState? state) && !IsStateUsable(state))
            {
                ClearFromLua(item);
            }
        }

        private static bool IsStateUsable(GunsmithSpriteState state)
            => state.Texture != null && !state.Texture.IsDisposed &&
               state.WorldTexture != null && !state.WorldTexture.IsDisposed &&
               state.InventoryTexture != null && !state.InventoryTexture.IsDisposed;

        private static void RestoreVanillaSprite(Item item)
        {
            item.OverrideInventorySprite = null;
            item.activeSprite = item.Prefab.Sprite;
            item.SetActiveSprite();
        }

        public static void Dispose()
        {
            GunsmithGui.CloseWindow();

            runtimeStates.Clear();
            foreach (KeyValuePair<Item, GunsmithSpriteState> pair in spriteStates.ToArray())
            {
                if (spriteStates.TryRemove(pair.Key, out GunsmithSpriteState? state))
                {
                    if (!state.Texture.IsDisposed)
                    {
                        state.Texture.Dispose();
                    }
                    if (!state.InventoryTexture.IsDisposed)
                    {
                        state.InventoryTexture.Dispose();
                    }
                    if (!state.WorldTexture.IsDisposed)
                    {
                        state.WorldTexture.Dispose();
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
