namespace GunSmith
{
    public static partial class GunsmithApi
    {
        private const string EmptyPartId = "__empty";

        private static GUIFrame? activeWindow;
        private static Item? activeItem;
        private static string? selectedSlot;
        private static GunsmithGuiContext activeContext = GunsmithGuiContext.Empty;
        private static List<GunsmithGuiSlot> activeSlots = new();
        private static GUIListBox? slotList;
        private static GUIFrame? previewPanel;
        private static GUIFrame? detailPanel;
        private static GUIListBox? partList;
        private static GUIFrame? partDetailPanel;
        private static GUITextBlock? partListTitle;
        private static readonly Dictionary<string, GUIButton> partButtons = new(StringComparer.Ordinal);
        private static GUITextBlock? partDetailStats;
        private static GUIButton? partDetailActionButton;
        private static string? partListSlotPath;
        private static string? partDetailSlotPath;
        private static string? selectedPartId;
        private static GunsmithPreviewSettings activePreviewSettings = GunsmithPreviewSettings.Default;
        private static bool activeQuickMode;

        public static void OpenFromLua(Item item, string title, string slotSpec)
            => OpenInternal(item, title, slotSpec, quickMode: false);

        public static void OpenQuickFromLua(Item item, string title, string slotSpec)
            => OpenInternal(item, title, slotSpec, quickMode: true);

        private static void OpenInternal(Item item, string title, string slotSpec, bool quickMode)
        {
            if (item == null || item.Removed) { return; }

            GunsmithGuiSpec spec = ParseSpec(slotSpec);
            if (spec.Slots.Count == 0) { return; }

            if (activeWindow != null && ReferenceEquals(activeItem, item))
            {
                activeQuickMode = quickMode;
                string previousPath = activeContext.CurrentPath;
                activeContext = spec.Context;
                activeSlots = spec.Slots;
                activePreviewSettings = spec.PreviewSettings;
                activeWeaponStats = spec.WeaponStats;
                SelectSlotAfterRefresh(previousPath, activeContext.CurrentPath);
                RebuildSlotList();
                RefreshSelectionPanels();
                return;
            }

            if (string.IsNullOrWhiteSpace(selectedSlot) || spec.Slots.All(slot => slot.Path != selectedSlot))
            {
                selectedSlot = spec.Slots[0].Path;
            }

            CloseWindow();

            activeItem = item;
            activeQuickMode = quickMode;
            activeContext = spec.Context;
            activeSlots = spec.Slots;
            activePreviewSettings = spec.PreviewSettings;
            activeWeaponStats = spec.WeaponStats;
            activeWindow = new GUIFrame(new RectTransform(new Vector2(0.74f, 0.62f), GUI.Canvas, Anchor.Center), color: Color.Black * 0.85f);
            BuildHeader(title);
            BuildBody();

            try
            {
                activeWindow.AddToGUIUpdateList();
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to add window to GUI update list: {ex.Message}");
            }
        }

        public static void RefreshPartsFromLua(Item item, string slotSpec)
            => RefreshInternal(item, slotSpec, quickMode: false);

        public static void RefreshQuickFromLua(Item item, string slotSpec)
            => RefreshInternal(item, slotSpec, quickMode: true);

        private static void RefreshInternal(Item item, string slotSpec, bool quickMode)
        {
            if (item == null || item.Removed || activeWindow == null || !ReferenceEquals(activeItem, item)) { return; }

            GunsmithGuiSpec spec = ParseSpec(slotSpec);
            if (spec.Slots.Count == 0) { return; }

            activeQuickMode = quickMode;
            string previousPath = activeContext.CurrentPath;
            activeContext = spec.Context;
            activeSlots = spec.Slots;
            activeWeaponStats = spec.WeaponStats;
            SelectSlotAfterRefresh(previousPath, activeContext.CurrentPath);

            GunsmithGuiSlot? slot = activeSlots.FirstOrDefault(slot => slot.Path == selectedSlot) ?? activeSlots.FirstOrDefault();
            if (slot == null) { return; }

            selectedSlot = slot.Path;
            SelectDefaultPart(slot);
            RefreshPartList(slot);
            RefreshPartDetailPanel(slot);
        }

        private static void BuildHeader(string title)
        {
            if (activeWindow == null) { return; }

            GUIFrame header = new(new RectTransform(new Vector2(0.96f, 0.12f), activeWindow.RectTransform, Anchor.TopCenter), color: Color.Black * 0.35f);
            _ = new GUITextBlock(new RectTransform(new Vector2(0.76f, 0.78f), header.RectTransform, Anchor.CenterLeft), FormatL(title, LocalizedItemName(activeItem)), textAlignment: Alignment.CenterLeft);

            GUIButton closeButton = new(new RectTransform(new Vector2(0.16f, 0.72f), header.RectTransform, Anchor.CenterRight), L("deep.gunsmith.ui.close"), Alignment.Center);
            closeButton.OnClicked = (_, _) =>
            {
                CloseWindow();
                return true;
            };
        }

        private static void BuildBody()
        {
            if (activeWindow == null) { return; }

            GUIFrame body = new(new RectTransform(new Vector2(0.96f, 0.82f), activeWindow.RectTransform, Anchor.BottomCenter), color: Color.Transparent);
            BuildSlotPanel(body);

            GUIFrame middle = new(new RectTransform(new Vector2(0.36f, 0.96f), body.RectTransform, Anchor.Center), color: Color.Transparent);
            previewPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.66f), middle.RectTransform, Anchor.TopCenter), color: Color.Black * 0.25f);
            detailPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.30f), middle.RectTransform, Anchor.BottomCenter), color: Color.Black * 0.25f);
            GUIFrame rightPanel = new(new RectTransform(new Vector2(0.28f, 0.96f), body.RectTransform, Anchor.CenterRight), color: Color.Transparent);
            partList = new GUIListBox(new RectTransform(new Vector2(1.0f, 0.62f), rightPanel.RectTransform, Anchor.TopCenter));
            partDetailPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.34f), rightPanel.RectTransform, Anchor.BottomCenter), color: Color.Black * 0.25f);

            RefreshSelectionPanels();
        }

        private static void BuildSlotPanel(GUIFrame body)
        {
            slotList = new GUIListBox(new RectTransform(new Vector2(0.28f, 0.96f), body.RectTransform, Anchor.CenterLeft));
            RebuildSlotList();
        }

        private static void RebuildSlotList()
        {
            if (slotList == null) { return; }
            slotList.Content.ClearChildren();

            _ = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.12f), slotList.Content.RectTransform), L("deep.gunsmith.ui.current_slots"), textAlignment: Alignment.Center);

            if (!string.IsNullOrWhiteSpace(activeContext.CurrentPath))
            {
                GUIButton backButton = new(new RectTransform(new Vector2(1.0f, 0.13f), slotList.Content.RectTransform), L("deep.gunsmith.ui.back"), Alignment.Center);
                backButton.OnClicked = (_, _) =>
                {
                    if (activeItem != null && !activeItem.Removed)
                    {
                        CallLuaHook("DeepGunsmithEnterPath", activeItem, activeContext.ParentPath);
                    }
                    return true;
                };
            }

            foreach (GunsmithGuiSlot slot in activeSlots)
            {
                string label = LocalizeKey(slot.NameKey);
                if (slot.Path == selectedSlot) { label = FormatLValue("deep.gunsmith.ui.selected_prefix", label); }
                GUIButton selectButton = new(new RectTransform(new Vector2(1.0f, 0.13f), slotList.Content.RectTransform), (LocalizedString)label, Alignment.Center);
                selectButton.OnClicked = (_, _) =>
                {
                    selectedSlot = slot.Path;
                    RebuildSlotList();
                    RefreshSelectionPanels();
                    return true;
                };
            }
        }

        private static void RefreshSelectionPanels()
        {
            GunsmithGuiSlot? slot = activeSlots.FirstOrDefault(slot => slot.Path == selectedSlot) ?? activeSlots.FirstOrDefault();
            if (slot == null) { return; }
            selectedSlot = slot.Path;
            SelectDefaultPart(slot);

            RebuildPreviewPanel(slot);
            RebuildPartList(slot);
            RebuildPartDetailPanel(slot);
        }

        private static void SelectSlotAfterRefresh(string previousPath, string currentPath)
        {
            if (!string.IsNullOrWhiteSpace(previousPath) &&
                !string.Equals(previousPath, currentPath, StringComparison.Ordinal) &&
                (string.Equals(ParentPath(previousPath), currentPath ?? string.Empty, StringComparison.Ordinal) ||
                    string.IsNullOrWhiteSpace(currentPath)) &&
                activeSlots.Any(slot => slot.Path == previousPath))
            {
                selectedSlot = previousPath;
                return;
            }

            if (string.IsNullOrWhiteSpace(selectedSlot) || activeSlots.All(slot => slot.Path != selectedSlot))
            {
                selectedSlot = activeSlots.FirstOrDefault()?.Path;
                selectedPartId = null;
            }
        }

        private static string ParentPath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) { return string.Empty; }
            int slashIndex = path.LastIndexOf('/');
            return slashIndex > 0 ? path[..slashIndex] : string.Empty;
        }

        private static void RebuildPreviewPanel(GunsmithGuiSlot slot)
        {
            if (previewPanel == null) { return; }
            previewPanel.ClearChildren();
            detailPanel?.ClearChildren();

            if (activeItem != null && TryGetValidState(activeItem, out GunsmithSpriteState state))
            {
                _ = new GunsmithPreviewImage(
                    new RectTransform(new Vector2(0.92f, 0.86f), previewPanel.RectTransform, Anchor.Center),
                    activeItem,
                    activePreviewSettings);
            }
            else
            {
                _ = new GUITextBlock(new RectTransform(new Vector2(0.92f, 0.28f), previewPanel.RectTransform, Anchor.Center), L("deep.gunsmith.ui.preview_placeholder"), textAlignment: Alignment.Center);
            }

            if (detailPanel == null) { return; }
            _ = new GUITextBlock(new RectTransform(new Vector2(0.96f, 0.25f), detailPanel.RectTransform, Anchor.TopCenter), (LocalizedString)FormatStatsLine(activeWeaponStats), textAlignment: Alignment.Center);
            _ = new GUITextBlock(new RectTransform(new Vector2(0.92f, 0.28f), detailPanel.RectTransform, Anchor.Center), FormatL("deep.gunsmith.ui.path_line", LocalizePathLabel(activeContext.PathLabel)), textAlignment: Alignment.Center);

            if (!slot.CanEnter) { return; }
            GUIButton enterButton = new(new RectTransform(new Vector2(0.72f, 0.28f), detailPanel.RectTransform, Anchor.BottomCenter), L("deep.gunsmith.ui.enter_mounts"), Alignment.Center);
            enterButton.OnClicked = (_, _) =>
            {
                if (activeItem != null && !activeItem.Removed)
                {
                    CallLuaHook("DeepGunsmithEnterPath", activeItem, slot.Path);
                }
                return true;
            };
        }

        private static void RebuildPartList(GunsmithGuiSlot slot)
        {
            if (partList == null) { return; }
            partList.Content.ClearChildren();
            partButtons.Clear();
            partListSlotPath = slot.Path;

            partListTitle = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.12f), partList.Content.RectTransform), FormatL("deep.gunsmith.ui.part_list_title", LocalizeKey(slot.NameKey)), textAlignment: Alignment.Center);

            foreach (GunsmithGuiPart part in slot.Parts)
            {
                GUIButton button = new(new RectTransform(new Vector2(1.0f, 0.14f), partList.Content.RectTransform), (LocalizedString)PartButtonText(slot, part), Alignment.Center);
                partButtons[part.Id] = button;
                UpdatePartButton(slot, part, button);
            }
        }

        private static void RefreshPartList(GunsmithGuiSlot slot)
        {
            if (partList == null) { return; }
            if (!CanUpdatePartList(slot))
            {
                RebuildPartList(slot);
                return;
            }

            if (partListTitle != null)
            {
                partListTitle.Text = FormatL("deep.gunsmith.ui.part_list_title", LocalizeKey(slot.NameKey));
            }

            foreach (GunsmithGuiPart part in slot.Parts)
            {
                if (partButtons.TryGetValue(part.Id, out GUIButton? button))
                {
                    UpdatePartButton(slot, part, button);
                }
            }
        }

        private static bool CanUpdatePartList(GunsmithGuiSlot slot)
            => string.Equals(partListSlotPath, slot.Path, StringComparison.Ordinal) &&
               partListTitle != null &&
               partButtons.Count == slot.Parts.Count &&
               slot.Parts.All(part => partButtons.ContainsKey(part.Id));

        private static void UpdatePartButton(GunsmithGuiSlot slot, GunsmithGuiPart part, GUIButton button)
        {
            button.Text = (LocalizedString)PartButtonText(slot, part);
            button.OnClicked = (_, _) =>
            {
                selectedPartId = part.Id;
                RefreshPartList(slot);
                RefreshPartDetailPanel(slot);
                return true;
            };
        }

        private static string PartButtonText(GunsmithGuiSlot slot, GunsmithGuiPart part)
        {
            bool installed = part.Id == slot.CurrentPartId || (part.Id == EmptyPartId && string.IsNullOrWhiteSpace(slot.CurrentPartId));
            string label = PartLabel(part, installed);
            return part.Id == selectedPartId
                ? FormatLValue("deep.gunsmith.ui.selected_prefix", label)
                : label;
        }

        private static void RebuildPartDetailPanel(GunsmithGuiSlot slot)
        {
            if (partDetailPanel == null) { return; }
            partDetailPanel.ClearChildren();
            partDetailSlotPath = slot.Path;

            GunsmithGuiPart? part = slot.Parts.FirstOrDefault(part => part.Id == selectedPartId) ?? slot.Parts.FirstOrDefault();
            if (part == null) { return; }
            selectedPartId = part.Id;

            bool installed = part.Id == slot.CurrentPartId || (part.Id == EmptyPartId && string.IsNullOrWhiteSpace(slot.CurrentPartId));
            _ = new GUITextBlock(new RectTransform(new Vector2(0.96f, 0.18f), partDetailPanel.RectTransform, Anchor.TopCenter), L("deep.gunsmith.ui.part_detail_title"), textAlignment: Alignment.Center);
            partDetailStats = new GUITextBlock(new RectTransform(new Vector2(0.96f, 0.44f), partDetailPanel.RectTransform, Anchor.Center), (LocalizedString)FormatPartStats(part.Stats), textAlignment: Alignment.Center);

            string buttonText = InstallButtonText(part, installed);
            partDetailActionButton = new GUIButton(new RectTransform(new Vector2(0.72f, 0.22f), partDetailPanel.RectTransform, Anchor.BottomCenter), (LocalizedString)buttonText, Alignment.Center);
            UpdatePartDetailAction(slot, part, installed);
        }

        private static void RefreshPartDetailPanel(GunsmithGuiSlot slot)
        {
            if (partDetailPanel == null) { return; }
            if (!string.Equals(partDetailSlotPath, slot.Path, StringComparison.Ordinal) ||
                partDetailStats == null ||
                partDetailActionButton == null)
            {
                RebuildPartDetailPanel(slot);
                return;
            }

            GunsmithGuiPart? part = slot.Parts.FirstOrDefault(part => part.Id == selectedPartId) ?? slot.Parts.FirstOrDefault();
            if (part == null)
            {
                RebuildPartDetailPanel(slot);
                return;
            }

            selectedPartId = part.Id;
            bool installed = part.Id == slot.CurrentPartId || (part.Id == EmptyPartId && string.IsNullOrWhiteSpace(slot.CurrentPartId));
            partDetailStats.Text = (LocalizedString)FormatPartStats(part.Stats);
            UpdatePartDetailAction(slot, part, installed);
        }

        private static void UpdatePartDetailAction(GunsmithGuiSlot slot, GunsmithGuiPart part, bool installed)
        {
            if (partDetailActionButton == null) { return; }
            partDetailActionButton.Text = (LocalizedString)InstallButtonText(part, installed);
            partDetailActionButton.Enabled = !installed && part.IsActionable;
            partDetailActionButton.OnClicked = (_, _) =>
            {
                if (!installed && part.IsActionable && activeItem != null && !activeItem.Removed)
                {
                    CallLuaHook(activeQuickMode ? "DeepGunsmithSetQuickPart" : "DeepGunsmithSetPart", activeItem, slot.Path, part.Id);
                }
                return true;
            };
        }

        private static void SelectDefaultPart(GunsmithGuiSlot slot)
        {
            if (slot.Parts.Any(part => part.Id == selectedPartId)) { return; }
            selectedPartId = slot.Parts.FirstOrDefault(part => part.Id == slot.CurrentPartId)?.Id;
            if (string.IsNullOrWhiteSpace(selectedPartId) && string.IsNullOrWhiteSpace(slot.CurrentPartId))
            {
                selectedPartId = slot.Parts.FirstOrDefault(part => part.Id == EmptyPartId)?.Id;
            }
            selectedPartId ??= slot.Parts.FirstOrDefault()?.Id;
        }

        private static LocalizedString L(string key)
            => TextManager.Get(key).Fallback(key);

        private static string LocalizeKey(string key)
            => L(key).Value;

        private static LocalizedString FormatL(string key, params object?[] args)
            => (LocalizedString)FormatLValue(key, args);

        private static string FormatLValue(string key, params object?[] args)
        {
            string value = LocalizeKey(key);
            for (int i = 0; i < args.Length; i++)
            {
                value = value.Replace("{" + i + "}", args[i]?.ToString() ?? string.Empty, StringComparison.Ordinal);
            }
            return value;
        }

        private static string LocalizePathLabel(string pathLabel)
        {
            if (string.IsNullOrWhiteSpace(pathLabel)) { return LocalizeKey("deep.gunsmith.ui.weapon_root"); }
            return string.Join(" > ",
                pathLabel
                    .Split('>', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Select(LocalizeKey));
        }

        private static string LocalizedItemName(Item? item)
        {
            string identifier = item?.Prefab?.Identifier.Value ?? string.Empty;
            return string.IsNullOrWhiteSpace(identifier)
                ? string.Empty
                : TextManager.Get("entityname." + identifier).Fallback(identifier).Value;
        }

        private static string PartLabel(GunsmithGuiPart part, bool installed)
            => FormatLValue("deep.gunsmith.status." + (installed ? "installed" : part.Status), LocalizeKey(part.NameKey));

        private static string InstallButtonText(GunsmithGuiPart part, bool installed)
        {
            if (installed || part.Status == "installed") { return LocalizeKey("deep.gunsmith.action.installed"); }
            return part.Status switch
            {
                "missing" => LocalizeKey("deep.gunsmith.action.missing"),
                "incompatible" => LocalizeKey("deep.gunsmith.action.incompatible"),
                "disabled" => LocalizeKey("deep.gunsmith.action.disabled"),
                _ => LocalizeKey(part.Id == EmptyPartId ? "deep.gunsmith.action.remove" : "deep.gunsmith.action.install")
            };
        }

        private static string FormatStatsLine(GunsmithStats stats)
            => $"{LocalizeKey("deep.gunsmith.stat.weight")} {stats.Weight:0.##} | {LocalizeKey("deep.gunsmith.stat.ergonomics")} {stats.Ergonomics:+0.##;-0.##;0} | {LocalizeKey("deep.gunsmith.stat.recoil_control")} {stats.RecoilControl * 100:+0.#;-0.#;0}% | {LocalizeKey("deep.gunsmith.stat.spread_reduction")} {stats.SpreadReduction * 100:+0.#;-0.#;0}% | {LocalizeKey("deep.gunsmith.stat.fire_rate")} {stats.FireRateMultiplier * 100:+0.#;-0.#;0}% | {LocalizeKey("deep.gunsmith.stat.damage")} {stats.DamageMultiplier * 100:+0.#;-0.#;0}%";

        private static string FormatPartStats(GunsmithStats stats)
            => $"{LocalizeKey("deep.gunsmith.stat.weight")}: {stats.Weight:+0.##;-0.##;0}\n{LocalizeKey("deep.gunsmith.stat.ergonomics")}: {stats.Ergonomics:+0.##;-0.##;0}\n{LocalizeKey("deep.gunsmith.stat.recoil_control")}: {stats.RecoilControl * 100:+0.#;-0.#;0}%\n{LocalizeKey("deep.gunsmith.stat.spread_reduction")}: {stats.SpreadReduction * 100:+0.#;-0.#;0}%\n{LocalizeKey("deep.gunsmith.stat.fire_rate")}: {stats.FireRateMultiplier * 100:+0.#;-0.#;0}%\n{LocalizeKey("deep.gunsmith.stat.damage")}: {stats.DamageMultiplier * 100:+0.#;-0.#;0}%";

        private static Rectangle CreatePreviewSourceRect(GunsmithSpriteState state, GunsmithPreviewSettings settings)
        {
            Rectangle bounds = state.ContentBounds;
            int padding = (int)Math.Round(settings.Padding);
            int x = bounds.X - padding + (int)Math.Round(settings.Offset.X);
            int y = bounds.Y - padding + (int)Math.Round(settings.Offset.Y);
            int width = Math.Max((int)Math.Ceiling((bounds.Width + padding * 2) / settings.Scale), 1);
            int height = Math.Max((int)Math.Ceiling((bounds.Height + padding * 2) / settings.Scale), 1);

            Rectangle sourceRect = new(x, y, width, height);
            Rectangle textureRect = new(0, 0, state.Texture.Width, state.Texture.Height);
            Rectangle clipped = Rectangle.Intersect(sourceRect, textureRect);
            return clipped.Width > 0 && clipped.Height > 0 ? clipped : textureRect;
        }

        private static void CloseWindow()
        {
            if (activeWindow == null) { return; }
            activeWindow.RectTransform.Parent = null;
            activeWindow = null;
            activeItem = null;
            slotList = null;
            previewPanel = null;
            detailPanel = null;
            partList = null;
            partDetailPanel = null;
            partListTitle = null;
            partButtons.Clear();
            partDetailStats = null;
            partDetailActionButton = null;
            partListSlotPath = null;
            partDetailSlotPath = null;
            selectedPartId = null;
            activePreviewSettings = GunsmithPreviewSettings.Default;
            activeWeaponStats = GunsmithStats.Empty;
            activeQuickMode = false;
        }

        internal static void RefreshWindow()
        {
            if (activeWindow == null) { return; }
            activeWindow.AddToGUIUpdateList();
        }

        private static GunsmithGuiSpec ParseSpec(string slotSpec)
        {
            string[] sections = slotSpec.Split(new[] { "::" }, 2, StringSplitOptions.None);
            GunsmithGuiContext context = ParseContext(sections[0]);
            GunsmithPreviewSettings previewSettings = GunsmithPreviewSettings.Default;
            GunsmithStats weaponStats = GunsmithStats.Empty;
            string slotsText = string.Empty;
            if (sections.Length > 1)
            {
                string[] remaining = sections[1].Split(new[] { "::" }, StringSplitOptions.None);
                if (remaining.Length >= 3)
                {
                    previewSettings = ParsePreviewSettings(remaining[0]);
                    weaponStats = ParseStats(remaining[1]);
                    slotsText = remaining[2];
                }
                else if (remaining.Length == 2)
                {
                    weaponStats = ParseStats(remaining[0]);
                    slotsText = remaining[1];
                }
                else
                {
                    slotsText = sections[1];
                }
            }
            return new GunsmithGuiSpec(context, previewSettings, weaponStats, ParseSlots(slotsText).ToList());
        }

        private static GunsmithGuiContext ParseContext(string contextSpec)
        {
            string[] parts = contextSpec.Split('|', 3, StringSplitOptions.TrimEntries);
            return new GunsmithGuiContext(
                parts.Length > 0 ? parts[0] : string.Empty,
                parts.Length > 1 && !string.IsNullOrWhiteSpace(parts[1]) ? parts[1] : "deep.gunsmith.ui.weapon_root",
                parts.Length > 2 ? parts[2] : string.Empty);
        }

        private static IEnumerable<GunsmithGuiSlot> ParseSlots(string slotsText)
        {
            foreach (string entry in slotsText.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('|', 5, StringSplitOptions.TrimEntries);
                if (parts.Length != 5 || string.IsNullOrWhiteSpace(parts[0])) { continue; }

                yield return new GunsmithGuiSlot(
                    parts[0],
                    string.IsNullOrWhiteSpace(parts[1]) ? parts[0] : parts[1],
                    parts[2],
                    parts[3] == "1",
                    ParseParts(parts[4]).ToList());
            }
        }

        private static IEnumerable<GunsmithGuiPart> ParseParts(string partSpec)
        {
            foreach (string entry in partSpec.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split(':', 4, StringSplitOptions.TrimEntries);
                if (parts.Length < 2 || string.IsNullOrWhiteSpace(parts[0])) { continue; }
                yield return new GunsmithGuiPart(
                    parts[0],
                    string.IsNullOrWhiteSpace(parts[1]) ? parts[0] : parts[1],
                    parts.Length > 2 && !string.IsNullOrWhiteSpace(parts[2]) ? parts[2] : "available",
                    parts.Length > 3 ? ParseStats(parts[3]) : GunsmithStats.Empty);
            }
        }

        private static GunsmithStats ParseStats(string statSpec)
        {
            GunsmithStats stats = GunsmithStats.Empty;
            foreach (string entry in statSpec.Split(new[] { ',', '~' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('=', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2 || !float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float value)) { continue; }
                stats = parts[0] switch
                {
                    "weight" => stats with { Weight = value },
                    "ergonomics" => stats with { Ergonomics = value },
                    "recoilControl" => stats with { RecoilControl = value },
                    "spreadReduction" => stats with { SpreadReduction = value },
                    "fireRateMultiplier" => stats with { FireRateMultiplier = value },
                    "damageMultiplier" => stats with { DamageMultiplier = value },
                    _ => stats
                };
            }
            return stats;
        }

        private static GunsmithPreviewSettings ParsePreviewSettings(string previewSpec)
        {
            GunsmithPreviewSettings settings = GunsmithPreviewSettings.Default;
            foreach (string entry in previewSpec.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('=', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2 || !float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float value)) { continue; }
                settings = parts[0] switch
                {
                    "padding" when value >= 0 => settings with { Padding = value },
                    "scale" when value > 0 => settings with { Scale = value },
                    "offsetX" => settings with { Offset = new Vector2(value, settings.Offset.Y) },
                    "offsetY" => settings with { Offset = new Vector2(settings.Offset.X, value) },
                    _ => settings
                };
            }
            return settings;
        }

        private static GunsmithStats activeWeaponStats = GunsmithStats.Empty;

        private sealed record GunsmithGuiSpec(GunsmithGuiContext Context, GunsmithPreviewSettings PreviewSettings, GunsmithStats WeaponStats, List<GunsmithGuiSlot> Slots);

        private sealed record GunsmithGuiContext(string CurrentPath, string PathLabel, string ParentPath)
        {
            public static GunsmithGuiContext Empty { get; } = new(string.Empty, "deep.gunsmith.ui.weapon_root", string.Empty);
        }

        private sealed record GunsmithGuiSlot(string Path, string NameKey, string CurrentPartId, bool CanEnter, List<GunsmithGuiPart> Parts);

        private sealed record GunsmithGuiPart(string Id, string NameKey, string Status, GunsmithStats Stats)
        {
            public bool IsActionable => Status != "missing" && Status != "disabled" && Status != "incompatible";
        }

        private sealed record GunsmithStats(float Weight, float Ergonomics, float RecoilControl, float SpreadReduction, float FireRateMultiplier, float DamageMultiplier)
        {
            public static GunsmithStats Empty { get; } = new(0, 0, 0, 0, 0, 0);
        }

        private sealed record GunsmithPreviewSettings(float Padding, float Scale, Vector2 Offset)
        {
            public static GunsmithPreviewSettings Default { get; } = new(12.0f, 1.0f, Vector2.Zero);
        }

        private sealed class GunsmithPreviewImage : GUIFrame
        {
            private readonly Item item;
            private readonly GunsmithPreviewSettings settings;

            public GunsmithPreviewImage(RectTransform rectT, Item item, GunsmithPreviewSettings settings)
                : base(rectT, "GUIFrame", Color.Transparent)
            {
                this.item = item;
                this.settings = settings;
            }

            public override void Draw(SpriteBatch spriteBatch)
            {
                if (!Visible || item.Removed || !TryGetValidState(item, out GunsmithSpriteState state))
                {
                    return;
                }

                base.Draw(spriteBatch);
                Texture2D texture = state.Texture;
                Rectangle sourceRect = CreatePreviewSourceRect(state, settings);
                if (sourceRect.Width <= 0 || sourceRect.Height <= 0 || Rect.Width <= 0 || Rect.Height <= 0)
                {
                    return;
                }

                float scale = Math.Min(Rect.Width / (float)sourceRect.Width, Rect.Height / (float)sourceRect.Height);
                int width = Math.Max((int)Math.Round(sourceRect.Width * scale), 1);
                int height = Math.Max((int)Math.Round(sourceRect.Height * scale), 1);
                Rectangle destination = new(
                    Rect.Center.X - width / 2,
                    Rect.Center.Y - height / 2,
                    width,
                    height);

                spriteBatch.Draw(texture, destination, sourceRect, Color.White);
            }
        }
    }
}
