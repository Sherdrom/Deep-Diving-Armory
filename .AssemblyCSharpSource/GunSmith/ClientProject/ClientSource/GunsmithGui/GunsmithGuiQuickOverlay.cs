namespace GunSmith
{
    public static partial class GunsmithGui
    {
        private sealed class PendingQuickDrag
        {
            public readonly Item WeaponItem;
            public readonly string SlotPath;
            public readonly int SlotIndex;
            public readonly Item DraggedItem;
            public readonly string? OriginalPartId;

            public PendingQuickDrag(Item weaponItem, string slotPath, int slotIndex, Item draggedItem, string? originalPartId)
            {
                WeaponItem = weaponItem;
                SlotPath = slotPath;
                SlotIndex = slotIndex;
                DraggedItem = draggedItem;
                OriginalPartId = originalPartId;
            }
        }

        private sealed class QuickOverlayFrame : GUIFrame
        {
            private const int QuickSlotSize = 54;
            private const int QuickSlotGap = 74;
            private readonly Item? item;
            private readonly GunsmithPreviewSettings settings;
            private readonly List<GunsmithGuiSlot> slots;
            private readonly Dictionary<string, float> failedDropTimers = new(StringComparer.Ordinal);
            private static Texture2D? lineTexture;

            public QuickOverlayFrame(RectTransform rectT, Item? item, GunsmithPreviewSettings settings, List<GunsmithGuiSlot> slots)
                : base(rectT, style: null, color: Color.Transparent)
            {
                this.item = item;
                this.settings = settings;
                this.slots = slots;
                CanBeFocused = true;
            }

            public override void Update(float deltaTime)
            {
                base.Update(deltaTime);
                if (!Visible || item == null || item.Removed || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return;
                }

                if (Inventory.DraggingItems.Any() && PlayerInput.PrimaryMouseButtonReleased() && TryHandleDraggingRelease(geometry))
                {
                    return;
                }

                foreach (string key in failedDropTimers.Keys.ToList())
                {
                    failedDropTimers[key] -= deltaTime;
                    if (failedDropTimers[key] <= 0.0f)
                    {
                        failedDropTimers.Remove(key);
                    }
                }

                foreach (QuickSlotLayout layout in BuildSlotLayouts(geometry))
                {
                    if (!layout.Rect.Contains(PlayerInput.MousePosition) || string.IsNullOrWhiteSpace(layout.Slot.CurrentPartId))
                    {
                        continue;
                    }

                    Item? containedItem = GetContainedQuickItem(layout.Slot);
                    if (containedItem == null)
                    {
                        continue;
                    }

                    GUI.MouseCursor = CursorState.Hand;
                    if (Inventory.DraggingItems.Any() || !PlayerInput.PrimaryMouseButtonDown())
                    {
                        continue;
                    }

                    BeginDraggingQuickItem(layout.Slot, containedItem);
                    return;
                }

                if (suppressQuickUninstallRelease && !PlayerInput.PrimaryMouseButtonHeld())
                {
                    suppressQuickUninstallRelease = false;
                }
            }

            public bool IsMouseOnBufferInventory()
            {
                if (!Visible || item == null || item.Removed || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return false;
                }

                return BuildSlotLayouts(geometry).Any(layout => layout.Rect.Contains(PlayerInput.MousePosition));
            }

            public void RestoreBuffersToWeapon()
            {
                Item? restoredItem = pendingQuickDrag?.DraggedItem;
                if (RestorePendingQuickDragToSource(syncLua: false) && restoredItem != null)
                {
                    Inventory.DraggingItems.Remove(restoredItem);
                    Inventory.DraggingSlot = null;
                }
            }

            public bool TryHandleDraggingRelease()
            {
                if (!Visible || item == null || item.Removed || !Inventory.DraggingItems.Any() || !PlayerInput.PrimaryMouseButtonReleased() || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return false;
                }

                return TryHandleDraggingRelease(geometry);
            }

            private bool TryHandleDraggingRelease(QuickGeometry geometry)
            {
                if (item == null)
                {
                    return false;
                }
                Item weaponItem = item;

                foreach (QuickSlotLayout layout in BuildSlotLayouts(geometry))
                {
                    if (!layout.Rect.Contains(PlayerInput.MousePosition))
                    {
                        continue;
                    }

                    Item? draggedItem = Inventory.DraggingItems.FirstOrDefault();
                    if (draggedItem != null)
                    {
                        if (TryPlaceQuickDraggedItem(weaponItem, layout.Slot, draggedItem))
                        {
                            suppressQuickUninstallRelease = true;
                            Inventory.DraggingItems.Clear();
                            SoundPlayer.PlayUISound(GUISoundType.PickItem);
                        }
                        else
                        {
                            RestorePendingQuickDragToSource(syncLua: true);
                            Inventory.DraggingItems.Clear();
                            Inventory.DraggingSlot = null;
                            suppressQuickUninstallRelease = true;
                            failedDropTimers[layout.Slot.Path] = 0.45f;
                            SoundPlayer.PlayUISound(GUISoundType.PickItemFail);
                        }
                        return true;
                    }
                }

                FlushPendingQuickDragClear(syncLua: true);
                return false;
            }

            public bool ContainsMouseOrSlot(Point mousePosition)
            {
                if (!Visible || item == null || item.Removed || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return false;
                }

                return BuildSlotLayouts(geometry).Any(layout => layout.Rect.Contains(mousePosition));
            }

            public override void Draw(SpriteBatch spriteBatch)
            {
                if (!Visible || item == null || item.Removed || !GunsmithApi.TryGetValidState(item, out GunsmithSpriteState state))
                {
                    base.Draw(spriteBatch);
                    return;
                }

                base.Draw(spriteBatch);
                if (!TryCreateQuickGeometry(state, out QuickGeometry geometry))
                {
                    return;
                }

                spriteBatch.Draw(state.Texture, geometry.Destination, geometry.SourceRect, Color.White);
                Texture2D line = GetLineTexture();

                foreach (QuickSlotLayout layout in BuildSlotLayouts(geometry))
                {
                    Color lineColor = layout.AnchorValid ? Color.LightGreen * 0.55f : Color.Yellow * 0.55f;
                    DrawLine(spriteBatch, line, layout.Anchor, new Vector2(layout.Rect.Center.X, layout.Rect.Center.Y), lineColor, 1.0f);
                    DrawQuickSlot(spriteBatch, layout);
                    DrawSlotLabel(spriteBatch, layout.Rect, LocalizeKey(layout.Slot.NameKey));

                    if (!layout.AnchorValid && warnedQuickAnchorPaths.Add(layout.Slot.Path))
                    {
                        LuaCsSetup.PrintCsMessage($"[Gunsmith] Quick slot '{layout.Slot.Path}' has no resolved anchor; using fallback UI position.");
                    }
                }
            }

            private bool TryCreateQuickGeometry(out QuickGeometry geometry)
            {
                geometry = default;
                return item != null && GunsmithApi.TryGetValidState(item, out GunsmithSpriteState state) && TryCreateQuickGeometry(state, out geometry);
            }

            private bool TryCreateQuickGeometry(GunsmithSpriteState state, out QuickGeometry geometry)
            {
                geometry = default;
                Rectangle previewRect = Rect;
                previewRect.Inflate(-(int)(48 * GUI.xScale), -(int)(28 * GUI.yScale));
                Rectangle sourceRect = CreateQuickSourceRect(state, settings);
                if (!TryCreateQuickPreviewGeometry(previewRect, state, sourceRect, out Rectangle destination, out float scale))
                {
                    return false;
                }

                geometry = new QuickGeometry(sourceRect, destination, scale);
                return true;
            }

            private bool TryCreateQuickPreviewGeometry(Rectangle rect, GunsmithSpriteState state, Rectangle sourceRect, out Rectangle destination, out float scale)
            {
                destination = Rectangle.Empty;
                scale = 1.0f;
                if (sourceRect.Width <= 0 || sourceRect.Height <= 0 || rect.Width <= 0 || rect.Height <= 0)
                {
                    return false;
                }

                sourceRect = Rectangle.Intersect(sourceRect, new Rectangle(0, 0, state.Texture.Width, state.Texture.Height));
                if (sourceRect.Width <= 0 || sourceRect.Height <= 0)
                {
                    return false;
                }

                scale = Math.Min(rect.Width / (float)sourceRect.Width, rect.Height / (float)sourceRect.Height);
                int width = Math.Max((int)Math.Round(sourceRect.Width * scale), 1);
                int height = Math.Max((int)Math.Round(sourceRect.Height * scale), 1);
                Vector2 stableCenter = StableQuickContentBounds(state, sourceRect).Center.ToVector2();
                int x = (int)Math.Round(rect.Center.X - (stableCenter.X - sourceRect.X) * scale);
                int y = (int)Math.Round(rect.Center.Y - (stableCenter.Y - sourceRect.Y) * scale);
                destination = new Rectangle(x, y, width, height);
                return true;
            }

            private Rectangle StableQuickContentBounds(GunsmithSpriteState state, Rectangle fallbackBounds)
            {
                HashSet<string> quickPaths = slots
                    .Where(slot => slot.QuickMeta.SlotIndex >= 0)
                    .Select(slot => slot.Path)
                    .ToHashSet(StringComparer.OrdinalIgnoreCase);

                Rectangle? bounds = null;
                foreach (GunsmithLayer layer in state.Layers)
                {
                    if (quickPaths.Contains(layer.SlotPath))
                    {
                        continue;
                    }

                    Rectangle layerBounds = layer.DrawBounds;
                    bounds = bounds == null ? layerBounds : Rectangle.Union(bounds.Value, layerBounds);
                }

                if (bounds == null)
                {
                    return state.ContentBounds.Width > 0 && state.ContentBounds.Height > 0 ? state.ContentBounds : fallbackBounds;
                }

                Rectangle clipped = Rectangle.Intersect(bounds.Value, fallbackBounds);
                return clipped.Width > 0 && clipped.Height > 0 ? clipped : bounds.Value;
            }

            private static Rectangle CreateQuickSourceRect(GunsmithSpriteState state, GunsmithPreviewSettings settings)
            {
                Rectangle textureRect = new(0, 0, state.Texture.Width, state.Texture.Height);
                int padding = (int)Math.Round(settings.Padding);
                int x = -padding + (int)Math.Round(settings.Offset.X);
                int y = -padding + (int)Math.Round(settings.Offset.Y);
                int width = Math.Max((int)Math.Ceiling((textureRect.Width + padding * 2) / settings.Scale), 1);
                int height = Math.Max((int)Math.Ceiling((textureRect.Height + padding * 2) / settings.Scale), 1);

                Rectangle sourceRect = new(x, y, width, height);
                Rectangle clipped = Rectangle.Intersect(sourceRect, textureRect);
                return clipped.Width > 0 && clipped.Height > 0 ? clipped : textureRect;
            }

            private IEnumerable<QuickSlotLayout> BuildSlotLayouts(QuickGeometry geometry)
            {
                for (int i = 0; i < slots.Count; i++)
                {
                    GunsmithGuiSlot slot = slots[i];
                    if (slot.QuickMeta.SlotIndex < 0)
                    {
                        continue;
                    }

                    Vector2 anchor = slot.QuickMeta.AnchorValid
                        ? new Vector2(
                            geometry.Destination.X + (slot.QuickMeta.Anchor.X - geometry.SourceRect.X) * geometry.Scale,
                            geometry.Destination.Y + (slot.QuickMeta.Anchor.Y - geometry.SourceRect.Y) * geometry.Scale)
                        : FallbackAnchor(geometry.Destination, i, slots.Count);
                    Rectangle slotRect = SlotRectForSlot(slot, anchor, geometry);
                    yield return new QuickSlotLayout(slot, anchor, slotRect, slot.QuickMeta.AnchorValid);
                }
            }

            private static Vector2 FallbackAnchor(Rectangle destination, int index, int count)
            {
                float step = destination.Width / (float)Math.Max(count + 1, 2);
                return new Vector2(destination.X + step * (index + 1), destination.Y - 12);
            }

            private static Rectangle SlotRectForSlot(GunsmithGuiSlot slot, Vector2 anchor, QuickGeometry geometry)
            {
                Rectangle destination = geometry.Destination;
                Rectangle sourceRect = geometry.SourceRect;
                float scale = geometry.Scale;
                float sourceCenterX = sourceRect.X + sourceRect.Width * 0.5f;
                float sourceCenterY = sourceRect.Y + sourceRect.Height * 0.5f;
                float canvasX = sourceRect.X + (anchor.X - destination.X) / Math.Max(scale, 0.001f);
                float canvasY = sourceRect.Y + (anchor.Y - destination.Y) / Math.Max(scale, 0.001f);
                string path = slot.Path.ToLowerInvariant();

                int x;
                int y;
                if (path.Contains("lower_rail", StringComparison.Ordinal))
                {
                    x = (int)Math.Round(anchor.X - QuickSlotSize / 2.0f);
                    y = (int)Math.Round(anchor.Y + QuickSlotGap - QuickSlotSize / 2.0f);
                }
                else if (path.Contains("left_rail", StringComparison.Ordinal))
                {
                    x = (int)Math.Round(anchor.X - QuickSlotGap - QuickSlotSize / 2.0f);
                    y = (int)Math.Round(anchor.Y - QuickSlotSize / 2.0f);
                }
                else if (path.Contains("right_rail", StringComparison.Ordinal))
                {
                    x = (int)Math.Round(anchor.X + QuickSlotGap - QuickSlotSize / 2.0f);
                    y = (int)Math.Round(anchor.Y - QuickSlotSize / 2.0f);
                }
                else
                {
                    x = (int)Math.Round(anchor.X + (canvasX < sourceCenterX ? -QuickSlotGap : QuickSlotGap) - QuickSlotSize / 2.0f);
                    y = (int)Math.Round(anchor.Y + (canvasY < sourceCenterY ? -QuickSlotGap : QuickSlotGap) - QuickSlotSize / 2.0f);
                }

                Point offset = QuickSlotPositionOffsetForPath(path);
                if (offset != Point.Zero)
                {
                    x += offset.X;
                    y += offset.Y;
                }

                int minX = Math.Max(destination.X - 110, 8);
                int maxX = Math.Min(destination.Right + 110 - QuickSlotSize, GameMain.GraphicsWidth - QuickSlotSize - 8);
                int minY = Math.Max(destination.Y - 76, 58);
                int maxY = Math.Min(destination.Bottom + 76 - QuickSlotSize, GameMain.GraphicsHeight - QuickSlotSize - 8);
                return new Rectangle(Math.Clamp(x, minX, maxX), Math.Clamp(y, minY, maxY), QuickSlotSize, QuickSlotSize);
            }

            private static Point QuickSlotPositionOffsetForPath(string path)
            {
                if (path.Contains("optic_mount", StringComparison.Ordinal))
                {
                    return new Point(0, -150);
                }
                if (path.Contains("left_rail", StringComparison.Ordinal))
                {
                    return new Point(80, -100);
                }
                if (path.Contains("right_rail", StringComparison.Ordinal))
                {
                    return new Point(14, -100);
                }
                if (path.Contains("lower_rail", StringComparison.Ordinal))
                {
                    return new Point(-72, 12);
                }
                if (path.Contains("muzzle_mount", StringComparison.Ordinal) || path.Contains("muzzle", StringComparison.Ordinal))
                {
                    return new Point(0, 0);
                }
                return Point.Zero;
            }

            private void DrawQuickSlot(SpriteBatch spriteBatch, QuickSlotLayout layout)
            {
                VisualSlot visualSlot = new(layout.Rect);
                bool pendingDragFromThisSlot = pendingQuickDrag != null &&
                    ReferenceEquals(pendingQuickDrag.WeaponItem, item) &&
                    string.Equals(pendingQuickDrag.SlotPath, layout.Slot.Path, StringComparison.Ordinal);
                GunsmithGuiPart? installedPart = pendingDragFromThisSlot
                    ? null
                    : layout.Slot.Parts.FirstOrDefault(part => part.Id == layout.Slot.CurrentPartId);
                Inventory.DrawSlot(spriteBatch, null, visualSlot, null, -1, drawItem: false);

                bool mouseOn = layout.Rect.Contains(PlayerInput.MousePosition);
                Item? draggedItem = Inventory.DraggingItems.FirstOrDefault();
                bool canAccept = draggedItem != null && CanAcceptDraggedItemForDisplay(layout.Slot, draggedItem);
                bool failed = failedDropTimers.ContainsKey(layout.Slot.Path);
                Color outlineColor = failed
                    ? GUIStyle.Red
                    : mouseOn && draggedItem != null
                        ? canAccept ? GUIStyle.Green : GUIStyle.Red
                        : layout.AnchorValid ? Color.LightGreen : Color.Yellow;
                DrawSlotOutline(spriteBatch, GetLineTexture(), layout.Rect, outlineColor * 0.9f);

                if (mouseOn && draggedItem != null)
                {
                    GUIStyle.UIGlow.Draw(spriteBatch, layout.Rect, canAccept ? GUIStyle.Green : GUIStyle.Red);
                }

                if (installedPart != null)
                {
                    DrawPartIcon(spriteBatch, layout.Rect, installedPart, 0.82f);
                }
            }

            private static void DrawPartIcon(SpriteBatch spriteBatch, Rectangle rect, GunsmithGuiPart part, float fill)
            {
                if (TryGetPartSprite(part, out Sprite? sprite, out Color spriteColor) && sprite != null)
                {
                    float scale = Math.Min(rect.Width / sprite.size.X, rect.Height / sprite.size.Y) * fill;
                    sprite.Draw(spriteBatch, rect.Center.ToVector2(), spriteColor, scale: scale);
                    return;
                }

                if (!TryGetPartVisual(part, out Texture2D? texture, out Rectangle sourceRect) || texture == null)
                {
                    return;
                }

                float textureScale = Math.Min(rect.Width / (float)sourceRect.Width, rect.Height / (float)sourceRect.Height) * fill;
                int width = Math.Max((int)Math.Round(sourceRect.Width * textureScale), 1);
                int height = Math.Max((int)Math.Round(sourceRect.Height * textureScale), 1);
                Rectangle destination = new(rect.Center.X - width / 2, rect.Center.Y - height / 2, width, height);
                spriteBatch.Draw(texture, destination, sourceRect, Color.White);
            }

            private bool CanAcceptDraggedItemForDisplay(GunsmithGuiSlot slot, Item draggedItem)
            {
                if (item == null || item.OwnInventory == null)
                {
                    return false;
                }

                if (pendingQuickDrag != null &&
                    ReferenceEquals(pendingQuickDrag.WeaponItem, item) &&
                    ReferenceEquals(pendingQuickDrag.DraggedItem, draggedItem) &&
                    string.Equals(pendingQuickDrag.SlotPath, slot.Path, StringComparison.Ordinal))
                {
                    return true;
                }

                string identifier = draggedItem.Prefab?.Identifier.Value ?? string.Empty;
                if (string.IsNullOrWhiteSpace(identifier) || !slot.QuickMeta.AllowedItemIdentifiers.Contains(identifier))
                {
                    return false;
                }

                Item? existingItem = GetContainedQuickItem(slot);
                if (existingItem == null)
                {
                    return item.OwnInventory.CanBePutInSlot(draggedItem, slot.QuickMeta.SlotIndex);
                }

                return Character.Controlled?.Inventory != null;
            }

            private Item? GetContainedQuickItem(GunsmithGuiSlot slot)
            {
                int slotIndex = slot.QuickMeta.SlotIndex;
                if (item?.OwnInventory == null || slotIndex < 0 || slotIndex >= item.OwnInventory.slots.Length)
                {
                    return null;
                }

                foreach (Item contained in item.OwnInventory.slots[slotIndex].Items)
                {
                    if (contained != null && !contained.Removed)
                    {
                        return contained;
                    }
                }
                return null;
            }

            private void BeginDraggingQuickItem(GunsmithGuiSlot slot, Item containedItem)
            {
                if (item?.OwnInventory == null || containedItem.Removed)
                {
                    return;
                }

                GunsmithHiddenQuickSlotsPatch.BeginQuickSlotMutation(item);
                try
                {
                    item.OwnInventory.RemoveItem(containedItem);
                }
                finally
                {
                    GunsmithHiddenQuickSlotsPatch.EndQuickSlotMutation(item);
                }

                Inventory.DraggingItems.Clear();
                Inventory.DraggingItems.Add(containedItem);
                Inventory.DraggingSlot = null;
                suppressQuickUninstallRelease = true;
                pendingQuickDrag = new PendingQuickDrag(item, slot.Path, slot.QuickMeta.SlotIndex, containedItem, slot.CurrentPartId);
                SoundPlayer.PlayUISound(GUISoundType.PickItem);
            }

            private static bool TryPlaceQuickDraggedItem(Item weaponItem, GunsmithGuiSlot slot, Item draggedItem)
            {
                if (weaponItem.OwnInventory == null || slot.QuickMeta.SlotIndex < 0 || draggedItem.Removed)
                {
                    return false;
                }

                if (pendingQuickDrag != null &&
                    ReferenceEquals(pendingQuickDrag.WeaponItem, weaponItem) &&
                    ReferenceEquals(pendingQuickDrag.DraggedItem, draggedItem) &&
                    string.Equals(pendingQuickDrag.SlotPath, slot.Path, StringComparison.Ordinal))
                {
                    bool restored = PutItemInWeaponSlot(weaponItem, draggedItem, slot.QuickMeta.SlotIndex);
                    if (restored)
                    {
                        pendingQuickDrag = null;
                    }
                    return restored;
                }

                if (!IsDraggedItemAllowedByQuickSlot(slot, draggedItem))
                {
                    return false;
                }

                Item? existingItem = GetContainedQuickItem(weaponItem, slot.QuickMeta.SlotIndex);
                if (existingItem != null)
                {
                    if (ReferenceEquals(existingItem, draggedItem))
                    {
                        pendingQuickDrag = null;
                        GunsmithApi.CallLuaHook("DeepGunsmithSyncQuickContainer", weaponItem);
                        return true;
                    }

                    if (!ReturnItemToControlledInventory(existingItem))
                    {
                        return false;
                    }
                }

                if (!PutItemInWeaponSlot(weaponItem, draggedItem, slot.QuickMeta.SlotIndex))
                {
                    if (existingItem != null)
                    {
                        PutItemInWeaponSlot(weaponItem, existingItem, slot.QuickMeta.SlotIndex);
                    }
                    return false;
                }

                if (pendingQuickDrag != null && ReferenceEquals(pendingQuickDrag.DraggedItem, draggedItem))
                {
                    pendingQuickDrag = null;
                }
                GunsmithApi.CallLuaHook("DeepGunsmithSyncQuickContainer", weaponItem);
                return true;
            }

            private static bool IsDraggedItemAllowedByQuickSlot(GunsmithGuiSlot slot, Item draggedItem)
            {
                string identifier = draggedItem.Prefab?.Identifier.Value ?? string.Empty;
                return !string.IsNullOrWhiteSpace(identifier) &&
                    slot.QuickMeta.AllowedItemIdentifiers.Contains(identifier);
            }

            private static bool PutItemInWeaponSlot(Item weaponItem, Item itemToPut, int slotIndex)
            {
                if (weaponItem.OwnInventory == null || slotIndex < 0 || slotIndex >= weaponItem.OwnInventory.slots.Length)
                {
                    return false;
                }

                GunsmithHiddenQuickSlotsPatch.BeginQuickSlotMutation(weaponItem);
                try
                {
                    return weaponItem.OwnInventory.TryPutItem(itemToPut, slotIndex, allowSwapping: true, allowCombine: false, Character.Controlled, createNetworkEvent: false, ignoreCondition: false, triggerOnInsertedEffects: false);
                }
                finally
                {
                    GunsmithHiddenQuickSlotsPatch.EndQuickSlotMutation(weaponItem);
                }
            }

            private static bool ReturnItemToControlledInventory(Item itemToReturn)
            {
                if (itemToReturn.Removed || Character.Controlled?.Inventory == null)
                {
                    return false;
                }

                return Character.Controlled.Inventory.TryPutItem(itemToReturn, Character.Controlled, CharacterInventory.AnySlot, createNetworkEvent: false, ignoreCondition: true, triggerOnInsertedEffects: false);
            }

            private static Item? GetContainedQuickItem(Item weaponItem, int slotIndex)
            {
                if (weaponItem.OwnInventory == null || slotIndex < 0 || slotIndex >= weaponItem.OwnInventory.slots.Length)
                {
                    return null;
                }

                foreach (Item contained in weaponItem.OwnInventory.slots[slotIndex].Items)
                {
                    if (contained != null && !contained.Removed)
                    {
                        return contained;
                    }
                }
                return null;
            }

            private static void FlushPendingQuickDragClear(bool syncLua)
            {
                if (pendingQuickDrag == null)
                {
                    return;
                }

                Item weaponItem = pendingQuickDrag.WeaponItem;
                pendingQuickDrag = null;

                if (syncLua && !weaponItem.Removed)
                {
                    GunsmithApi.CallLuaHook("DeepGunsmithSyncQuickContainer", weaponItem);
                }
            }

            private static bool RestorePendingQuickDragToSource(bool syncLua)
            {
                if (pendingQuickDrag == null)
                {
                    return false;
                }

                PendingQuickDrag drag = pendingQuickDrag;
                bool restored = false;
                if (!drag.WeaponItem.Removed && !drag.DraggedItem.Removed)
                {
                    restored = PutItemInWeaponSlot(drag.WeaponItem, drag.DraggedItem, drag.SlotIndex);
                }

                pendingQuickDrag = null;

                if (syncLua && !drag.WeaponItem.Removed)
                {
                    GunsmithApi.CallLuaHook("DeepGunsmithSyncQuickContainer", drag.WeaponItem);
                }

                return restored;
            }

            private static void DrawSlotOutline(SpriteBatch spriteBatch, Texture2D texture, Rectangle rect, Color color)
            {
                spriteBatch.Draw(texture, new Rectangle(rect.X, rect.Y, rect.Width, 1), color);
                spriteBatch.Draw(texture, new Rectangle(rect.X, rect.Bottom - 1, rect.Width, 1), color);
                spriteBatch.Draw(texture, new Rectangle(rect.X, rect.Y, 1, rect.Height), color);
                spriteBatch.Draw(texture, new Rectangle(rect.Right - 1, rect.Y, 1, rect.Height), color);
            }

            private static void DrawLine(SpriteBatch spriteBatch, Texture2D texture, Vector2 from, Vector2 to, Color color, float thickness)
            {
                Vector2 edge = to - from;
                float length = edge.Length();
                if (length <= 0.1f) { return; }
                float angle = MathF.Atan2(edge.Y, edge.X);
                spriteBatch.Draw(texture, from, null, color, angle, Vector2.Zero, new Vector2(length, thickness), SpriteEffects.None, 0.0f);
            }

            private static void DrawSlotLabel(SpriteBatch spriteBatch, Rectangle slotRect, string label)
            {
                var font = GUIStyle.SmallFont ?? GUIStyle.Font;
                if (font == null || string.IsNullOrWhiteSpace(label)) { return; }
                Vector2 size = font.MeasureString(label);
                Vector2 position = new(slotRect.Center.X - size.X * 0.5f, slotRect.Y - size.Y - 3);
                GUI.DrawString(spriteBatch, position, label, Color.LightYellow, Color.Black * 0.65f, 0, font);
            }

            private static Texture2D GetLineTexture()
            {
                if (lineTexture != null && !lineTexture.IsDisposed)
                {
                    return lineTexture;
                }

                lineTexture = new Texture2D(GameMain.GraphicsDeviceManager.GraphicsDevice, 1, 1);
                lineTexture.SetData(new[] { Color.White });
                return lineTexture;
            }

            private readonly record struct QuickGeometry(Rectangle SourceRect, Rectangle Destination, float Scale);

            private readonly record struct QuickSlotLayout(GunsmithGuiSlot Slot, Vector2 Anchor, Rectangle Rect, bool AnchorValid);
        }
    }
}


