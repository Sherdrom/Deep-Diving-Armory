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
        private static readonly Dictionary<string, GunsmithPartRow> partRows = new(StringComparer.Ordinal);
        private static GUIButton? partDetailActionButton;
        private static string? partListSlotPath;
        private static string? partDetailSlotPath;
        private static string? selectedPartId;
        private static GunsmithPreviewSettings activePreviewSettings = GunsmithPreviewSettings.Default;
        private static bool activeQuickMode;
        private static QuickOverlayFrame? quickOverlayFrame;
        private static bool suppressQuickUninstallRelease;
        private static readonly HashSet<string> warnedQuickAnchorPaths = new(StringComparer.Ordinal);
        private static readonly Dictionary<string, Rectangle> partIconSourceCache = new(StringComparer.Ordinal);

        public static void OpenFromLua(Item item, string title, string slotSpec)
            => OpenInternal(item, title, slotSpec, quickMode: false);

        public static void OpenQuickFromLua(Item item, string title, string slotSpec)
            => OpenInternal(item, title, slotSpec, quickMode: true);

        private static void OpenInternal(Item item, string title, string slotSpec, bool quickMode)
        {
            if (item == null || item.Removed) { return; }

            GunsmithGuiSpec spec = ParseSpec(slotSpec);
            if (spec.Slots.Count == 0) { return; }

            if (activeWindow != null && ReferenceEquals(activeItem, item) && activeQuickMode != quickMode)
            {
                CloseWindow();
            }

            if (activeWindow != null && ReferenceEquals(activeItem, item))
            {
                activeQuickMode = quickMode;
                string previousPath = activeContext.CurrentPath;
                activeContext = spec.Context;
                activeSlots = spec.Slots;
                activePreviewSettings = spec.PreviewSettings;
                activeWeaponStats = spec.WeaponStats;
                if (quickMode)
                {
                    RebuildQuickOverlay(title);
                }
                else
                {
                    SelectSlotAfterRefresh(previousPath, activeContext.CurrentPath);
                    RebuildSlotList();
                    RefreshSelectionPanels();
                }
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
            if (quickMode)
            {
                activeWindow = new GunsmithWindowFrame(new RectTransform(new Vector2(0.78f, 0.68f), GUI.Canvas, Anchor.Center), CloseWindow, Color.Black * 0.62f);
                BuildQuickOverlay(title);
            }
            else
            {
                activeWindow = new GunsmithWindowFrame(new RectTransform(new Vector2(0.74f, 0.62f), GUI.Canvas, Anchor.Center), CloseWindow, Color.Black * 0.85f);
                BuildHeader(title);
                BuildBody();
            }

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
            activePreviewSettings = spec.PreviewSettings;
            if (quickMode)
            {
                RebuildQuickOverlay("deep.gunsmith.ui.quick_title");
                return;
            }

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
            partList = new GUIListBox(new RectTransform(new Vector2(1.0f, 0.54f), rightPanel.RectTransform, Anchor.TopCenter), style: null)
            {
                PlaySoundOnSelect = true
            };
            partDetailPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.42f), rightPanel.RectTransform, Anchor.BottomCenter), color: Color.Black * 0.25f);

            RefreshSelectionPanels();
        }

        private static void BuildQuickOverlay(string title)
        {
            if (activeWindow == null) { return; }
            activeWindow.ClearChildren();

            GUIFrame header = new(new RectTransform(new Vector2(0.48f, 0.09f), activeWindow.RectTransform, Anchor.TopCenter), color: Color.Black * 0.35f);
            _ = new GUITextBlock(new RectTransform(new Vector2(0.72f, 0.72f), header.RectTransform, Anchor.CenterLeft), FormatL(title, LocalizedItemName(activeItem)), textAlignment: Alignment.CenterLeft);
            GUIButton closeButton = new(new RectTransform(new Vector2(0.20f, 0.72f), header.RectTransform, Anchor.CenterRight), L("deep.gunsmith.ui.close"), Alignment.Center);
            closeButton.OnClicked = (_, _) =>
            {
                CloseWindow();
                return true;
            };

            quickOverlayFrame = new QuickOverlayFrame(
                new RectTransform(new Vector2(0.92f, 0.78f), activeWindow.RectTransform, Anchor.Center),
                activeItem,
                activePreviewSettings,
                activeSlots);
        }

        private static void RebuildQuickOverlay(string title)
        {
            if (!activeQuickMode || activeWindow == null) { return; }
            BuildQuickOverlay(title);
            activeWindow.AddToGUIUpdateList();
        }

        private static void BuildSlotPanel(GUIFrame body)
        {
            slotList = new GUIListBox(new RectTransform(new Vector2(0.28f, 0.96f), body.RectTransform, Anchor.CenterLeft), style: null)
            {
                PlaySoundOnSelect = true
            };
            RebuildSlotList();
        }

        private static void RebuildSlotList()
        {
            if (slotList == null) { return; }
            slotList.Content.ClearChildren();

            _ = CreateListTitle(slotList, L("deep.gunsmith.ui.current_slots"));

            if (!string.IsNullOrWhiteSpace(activeContext.CurrentPath))
            {
                GUIFrame backRow = CreateListRow(slotList, L("deep.gunsmith.ui.back").Value, Color.Cyan, null);
                backRow.UserData = "__back";
            }

            slotList.OnSelected = (_, userData) =>
            {
                if (userData is string back && back == "__back")
                {
                    if (activeItem != null && !activeItem.Removed)
                    {
                        CallLuaHook("DeepGunsmithEnterPath", activeItem, activeContext.ParentPath);
                    }
                    return true;
                }

                if (userData is not GunsmithGuiSlot slot) { return false; }
                selectedSlot = slot.Path;
                RebuildSlotList();
                RefreshSelectionPanels();
                return true;
            };

            foreach (GunsmithGuiSlot slot in activeSlots)
            {
                string label = LocalizeKey(slot.NameKey);
                GUIFrame row = CreateListRow(slotList, label, slot.Path == selectedSlot ? Color.LightGreen : Color.Cyan, slot);
                row.Color = slot.Path == selectedSlot ? Color.DarkOliveGreen * 0.55f : Color.Transparent;
            }
        }

        private static GUITextBlock CreateListTitle(GUIListBox list, LocalizedString text)
            => new(new RectTransform(new Point(list.Content.Rect.Width, (int)(40 * GUI.yScale)), list.Content.RectTransform), text, textAlignment: Alignment.Center);

        private static GUIFrame CreateListRow(GUIListBox list, string labelText, Color indicatorColor, object? userData)
        {
            GUIFrame frame = new(new RectTransform(new Point(list.Content.Rect.Width, (int)(40 * GUI.yScale)), list.Content.RectTransform), style: null)
            {
                UserData = userData,
                HoverColor = Color.Gold * 0.2f,
                SelectedColor = Color.Gold * 0.5f
            };
            _ = new GUITextBlock(new RectTransform(new Vector2(0.92f, 1.0f), frame.RectTransform, Anchor.Center), (LocalizedString)labelText, font: GUIStyle.SmallFont, textAlignment: Alignment.CenterLeft)
            {
                Padding = Vector4.Zero,
                AutoScaleVertical = true,
                CanBeFocused = false
            };
            return frame;
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
            partRows.Clear();
            partListSlotPath = slot.Path;
            SetPartListSelectionHandler(slot.Path);

            partListTitle = CreateListTitle(partList, FormatL("deep.gunsmith.ui.part_list_title", LocalizeKey(slot.NameKey)));

            foreach (GunsmithGuiPart part in slot.Parts)
            {
                GunsmithPartRow row = CreatePartRow(slot, part);
                partRows[part.Id] = row;
                UpdatePartRow(slot, part, row);
            }
            GunsmithGuiPart? selectedPart = slot.Parts.FirstOrDefault(part => part.Id == selectedPartId);
            if (selectedPart != null)
            {
                partList.Select(selectedPart);
            }
        }

        private static GunsmithPartRow CreatePartRow(GunsmithGuiSlot slot, GunsmithGuiPart part)
        {
            GUIFrame frame = new(new RectTransform(new Point(partList!.Content.Rect.Width, (int)(40 * GUI.yScale)), partList.Content.RectTransform), style: null)
            {
                UserData = part,
                HoverColor = Color.Gold * 0.2f,
                SelectedColor = Color.Gold * 0.5f
            };
            AddPartPrefabImage(new RectTransform(new Point(frame.Rect.Height, frame.Rect.Height), frame.RectTransform, Anchor.CenterLeft), part, 0.82f);
            GUITextBlock label = new(new RectTransform(new Vector2(0.70f, 1.0f), frame.RectTransform, Anchor.CenterLeft), (LocalizedString)LocalizeKey(part.NameKey), font: GUIStyle.SmallFont, textAlignment: Alignment.CenterLeft)
            {
                Padding = new Vector4(frame.Rect.Height + (int)(6 * GUI.xScale), 0, 0, 0),
                AutoScaleVertical = true,
                CanBeFocused = false
            };
            GUITextBlock status = new(new RectTransform(new Vector2(0.26f, 1.0f), frame.RectTransform, Anchor.CenterRight), (LocalizedString)PartStatusText(slot, part), font: GUIStyle.SmallFont, textAlignment: Alignment.CenterRight)
            {
                Padding = Vector4.Zero,
                AutoScaleVertical = true,
                CanBeFocused = false
            };
            return new GunsmithPartRow(frame, label, status);
        }

        private static void RefreshPartList(GunsmithGuiSlot slot)
        {
            if (partList == null) { return; }
            if (!CanUpdatePartList(slot))
            {
                RebuildPartList(slot);
                return;
            }

            SetPartListSelectionHandler(slot.Path);
            if (partListTitle != null)
            {
                partListTitle.Text = FormatL("deep.gunsmith.ui.part_list_title", LocalizeKey(slot.NameKey));
            }

            foreach (GunsmithGuiPart part in slot.Parts)
            {
                if (partRows.TryGetValue(part.Id, out GunsmithPartRow? row))
                {
                    UpdatePartRow(slot, part, row);
                }
            }
        }

        private static bool CanUpdatePartList(GunsmithGuiSlot slot)
            => string.Equals(partListSlotPath, slot.Path, StringComparison.Ordinal) &&
               partListTitle != null &&
               partRows.Count == slot.Parts.Count &&
               slot.Parts.All(part => partRows.ContainsKey(part.Id));

        private static void UpdatePartRow(GunsmithGuiSlot slot, GunsmithGuiPart part, GunsmithPartRow row)
        {
            bool selected = part.Id == selectedPartId;
            row.Frame.UserData = part;
            row.Frame.Color = selected ? Color.DarkOliveGreen * 0.55f : Color.Transparent;
            row.Label.Text = (LocalizedString)LocalizeKey(part.NameKey);
            row.Status.Text = (LocalizedString)PartStatusText(slot, part);
            row.Status.TextColor = PartStatusColor(slot, part);
        }

        private static void SetPartListSelectionHandler(string slotPath)
        {
            if (partList == null) { return; }
            partList.OnSelected = (_, userData) =>
            {
                if (userData is not GunsmithGuiPart part) { return false; }
                GunsmithGuiSlot? latestSlot = activeSlots.FirstOrDefault(slot => slot.Path == slotPath);
                if (latestSlot == null) { return false; }

                selectedSlot = latestSlot.Path;
                selectedPartId = part.Id;
                RefreshPartList(latestSlot);
                RebuildPartDetailPanel(latestSlot);
                return true;
            };
        }

        private static bool IsPartInstalled(GunsmithGuiSlot slot, GunsmithGuiPart part)
            => part.Id == slot.CurrentPartId || (part.Id == EmptyPartId && string.IsNullOrWhiteSpace(slot.CurrentPartId));

        private static string PartStatusText(GunsmithGuiSlot slot, GunsmithGuiPart part)
        {
            string key = IsPartInstalled(slot, part)
                ? "deep.gunsmith.status.installed"
                : part.Status switch
                {
                    "missing" => "deep.gunsmith.status.missing",
                    "incompatible" => "deep.gunsmith.status.incompatible",
                    "disabled" => "deep.gunsmith.status.disabled",
                    _ => string.Empty
                };
            if (string.IsNullOrWhiteSpace(key)) { return string.Empty; }
            return FormatLValue(key, string.Empty).Trim();
        }

        private static Color PartStatusColor(GunsmithGuiSlot slot, GunsmithGuiPart part)
        {
            if (IsPartInstalled(slot, part)) { return Color.LightGreen; }
            return part.Status switch
            {
                "missing" => Color.DarkRed,
                "incompatible" => Color.OrangeRed,
                "disabled" => Color.Gray,
                _ => Color.Cyan
            };
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
            // 右下详情面板标题：“选中配件属性”。第一个 Vector2 控制标题占面板宽高，Anchor.TopCenter 固定在面板顶部居中。
            _ = new GUITextBlock(new RectTransform(new Vector2(0.96f, 0.12f), partDetailPanel.RectTransform, Anchor.TopCenter), L("deep.gunsmith.ui.part_detail_title"), textAlignment: Alignment.Center);

            // 右下详情面板中部内容容器：左侧预览图 + 右侧名称/属性。调这里可整体移动或缩放中部内容。
            // Vector2.X 控制宽度比例，Vector2.Y 控制高度比例；Anchor.Center 表示内容块以详情面板中心为基准。
            // RelativeOffset.Y 控制整个“预览图 + 属性文字”上下位置：负数往上，正数往下。
            GUIFrame content = new(new RectTransform(new Vector2(0.94f, 0.42f), partDetailPanel.RectTransform, Anchor.Center), style: null, color: Color.Transparent)
            {
                RectTransform = { RelativeOffset = new Vector2(0.0f, -0.14f) }
            };

            // 左侧预览图区域。Vector2.X 是左栏宽度比例；Anchor.CenterLeft 表示贴在 content 左侧并垂直居中。
            GUIFrame left = new(new RectTransform(new Vector2(0.34f, 1.0f), content.RectTransform, Anchor.CenterLeft), style: null, color: Color.Transparent);

            // 预览图正方形边长。0.78f 越大，预览框越大；48 是最小像素尺寸。
            int imageSize = Math.Max((int)Math.Round(Math.Min(left.Rect.Width, left.Rect.Height) * 0.78f), 48);

            // 配件预览框。Anchor.Center 表示预览框在左栏中居中；OutlineColor/OutlineThickness 控制边框颜色和粗细。
            GUIFrame imageFrame = new(new RectTransform(new Point(imageSize, imageSize), left.RectTransform, Anchor.Center), color: Color.Black * 0.35f)
            {
                OutlineColor = GUIStyle.Green * 0.85f,
                OutlineThickness = 2
            };
            // 预览框内部图片。Vector2 控制图片在边框内可用空间比例，fill 控制图片最终填充比例。
            AddPartPrefabImage(new RectTransform(new Vector2(0.88f, 0.88f), imageFrame.RectTransform, Anchor.Center), part, 0.92f);

            // 右侧文字区域：配件名称 + 属性。Vector2.X 是右栏宽度比例；Anchor.CenterRight 表示贴在 content 右侧。
            GUIFrame right = new(new RectTransform(new Vector2(0.62f, 1.0f), content.RectTransform, Anchor.CenterRight), style: null, color: Color.Transparent);

            // 配件名称文本。Vector2.Y 控制名称区域高度；Anchor.TopLeft 表示从右侧文字区域左上角开始。
            _ = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.22f), right.RectTransform, Anchor.TopLeft), (LocalizedString)LocalizeKey(part.NameKey), font: GUIStyle.SmallFont, textAlignment: Alignment.TopLeft)
            {
                TextColor = Color.Cyan,
                Padding = Vector4.Zero,
                Wrap = true
            };

            // 属性文本。Vector2.Y 控制属性区域高度；Anchor.BottomLeft 表示贴在右侧文字区域左下方。
            // 如果属性太靠下，可改 Anchor.CenterLeft 或增大/减小此处高度比例。
            GUITextBlock statsText = new(new RectTransform(new Vector2(1.0f, 0.76f), right.RectTransform, Anchor.BottomLeft), (LocalizedString)FormatPartStatsBlock(part.Stats), font: GUIStyle.SmallFont, textAlignment: Alignment.TopLeft)
            {
                Padding = Vector4.Zero,
                Wrap = true
            };
            string buttonText = InstallButtonText(part, installed);

            // 底部安装按钮。Vector2 控制按钮宽高比例；Anchor.BottomCenter 表示固定在详情面板底部居中。
            partDetailActionButton = new GUIButton(new RectTransform(new Vector2(0.72f, 0.18f), partDetailPanel.RectTransform, Anchor.BottomCenter), (LocalizedString)buttonText, Alignment.Center);
            UpdatePartDetailAction(slot, part, installed);
        }

        private static void RefreshPartDetailPanel(GunsmithGuiSlot slot)
        {
            if (partDetailPanel == null) { return; }
            if (!string.Equals(partDetailSlotPath, slot.Path, StringComparison.Ordinal) ||
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
            => $"{LocalizeKey("deep.gunsmith.stat.ergonomics")} {stats.Ergonomics:+0.##;-0.##;0} | {LocalizeStatType(StatTypes.RangedSpreadReduction)} {stats.Get(StatTypes.RangedSpreadReduction) * 100:+0.#;-0.#;0}% | {LocalizeStatType(StatTypes.RangedAttackSpeed)} {stats.Get(StatTypes.RangedAttackSpeed) * 100:+0.#;-0.#;0}% | {LocalizeStatType(StatTypes.RangedAttackMultiplier)} {stats.Get(StatTypes.RangedAttackMultiplier) * 100:+0.#;-0.#;0}%";

        private static List<string> FormatPartStats(GunsmithStats stats)
        {
            List<string> lines = new();

            AddNonZeroStatLine(lines, "deep.gunsmith.stat.ergonomics", stats.Ergonomics, "0.##");
            foreach (KeyValuePair<StatTypes, float> stat in stats.Values.OrderBy(stat => stat.Key))
            {
                AddNonZeroStatTypeLine(lines, stat.Key, stat.Value);
            }
            if (lines.Count == 0)
            {
                lines.Add(LocalizeKey("deep.gunsmith.stat.none"));
            }
            return lines;
        }

        private static void AddNonZeroPercentLine(List<string> lines, string key, float value)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            lines.Add($"{LocalizeKey(key)}: {value * 100:+0.#;-0.#;0}%");
        }

        private static void AddNonZeroStatTypeLine(List<string> lines, StatTypes statType, float value)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            if (IsFlatStat(statType))
            {
                lines.Add($"{LocalizeStatType(statType)}: {value:+0.#;-0.#;0}");
            }
            else
            {
                lines.Add($"{LocalizeStatType(statType)}: {value * 100:+0.#;-0.#;0}%");
            }
        }

        private static void AddNonZeroStatLine(List<string> lines, string key, float value, string format)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            lines.Add($"{LocalizeKey(key)}: {value.ToString("+" + format + ";-" + format + ";0", System.Globalization.CultureInfo.InvariantCulture)}");
        }

        private static string LocalizeStatType(StatTypes statType)
        {
            string key = $"deep.gunsmith.stattypes.{statType}";
            return TextManager.Get(key).Fallback(statType.ToString()).Value;
        }

        private static bool IsFlatStat(StatTypes statType)
            => statType.ToString().EndsWith("SkillBonus", StringComparison.Ordinal) ||
               statType.ToString().EndsWith("SkillOverride", StringComparison.Ordinal) ||
               statType is StatTypes.ExtraLevelGain or
                   StatTypes.ExtraMissionCount or
                   StatTypes.ExtraSpecialSalesCount or
                   StatTypes.MaxAttachableCount or
                   StatTypes.LockedTalents or
                   StatTypes.InventoryExtraStackSize;

        private static string FormatPartStatsBlock(GunsmithStats stats)
            => string.Join("\n", FormatPartStats(stats));

        private static void AddPartPrefabImage(RectTransform rectT, GunsmithGuiPart part, float fill)
        {
            if (TryGetPartSprite(part, out Sprite? sprite, out Color spriteColor))
            {
                _ = new GunsmithPartIcon(rectT, sprite!, spriteColor, fill);
                return;
            }

            if (TryGetPartVisual(part, out Texture2D? texture, out Rectangle sourceRect))
            {
                _ = new GunsmithPartIcon(rectT, texture!, sourceRect, Color.White, fill);
                return;
            }

            rectT.Parent = null;
        }

        private static bool TryGetPartVisual(GunsmithGuiPart part, out Texture2D? texture, out Rectangle sourceRect)
        {
            texture = null;
            sourceRect = Rectangle.Empty;
            if (string.IsNullOrWhiteSpace(part.VisualTexturePath) ||
                part.VisualSourceRect.Width <= 0 ||
                part.VisualSourceRect.Height <= 0)
            {
                return false;
            }

            try
            {
                string resolvedPath = ResolvePath(part.VisualTexturePath);
                texture = GetTexture(resolvedPath);
                sourceRect = Rectangle.Intersect(part.VisualSourceRect, new Rectangle(0, 0, texture.Width, texture.Height));
                if (sourceRect.Width <= 0 || sourceRect.Height <= 0)
                {
                    return false;
                }

                string cacheKey = $"{resolvedPath}|{sourceRect.X},{sourceRect.Y},{sourceRect.Width},{sourceRect.Height}";
                if (!partIconSourceCache.TryGetValue(cacheKey, out Rectangle trimmedRect))
                {
                    trimmedRect = TrimTransparentBounds(texture, sourceRect);
                    partIconSourceCache[cacheKey] = trimmedRect;
                }

                sourceRect = trimmedRect;
                return sourceRect.Width > 0 && sourceRect.Height > 0;
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to load part icon texture '{part.VisualTexturePath}': {ex.Message}");
                texture = null;
                sourceRect = Rectangle.Empty;
                return false;
            }
        }

        private static Rectangle TrimTransparentBounds(Texture2D texture, Rectangle rect)
        {
            Color[] pixels = new Color[rect.Width * rect.Height];
            texture.GetData(0, rect, pixels, 0, pixels.Length);

            int minX = rect.Width;
            int minY = rect.Height;
            int maxX = -1;
            int maxY = -1;
            for (int y = 0; y < rect.Height; y++)
            {
                int rowOffset = y * rect.Width;
                for (int x = 0; x < rect.Width; x++)
                {
                    if (pixels[rowOffset + x].A <= 8) { continue; }
                    minX = Math.Min(minX, x);
                    minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x);
                    maxY = Math.Max(maxY, y);
                }
            }

            if (maxX < minX || maxY < minY)
            {
                return rect;
            }

            return new Rectangle(
                rect.X + minX,
                rect.Y + minY,
                maxX - minX + 1,
                maxY - minY + 1);
        }

        private static bool TryGetPartSprite(GunsmithGuiPart part, out Sprite? sprite, out Color color)
        {
            sprite = null;
            color = Color.White;
            ItemPrefab? prefab = PartPrefab(part);
            if (prefab == null)
            {
                return false;
            }

            if (prefab.InventoryIcon != null)
            {
                color = prefab.InventoryIconColor;
                sprite = prefab.InventoryIcon;
            }
            else
            {
                color = prefab.SpriteColor;
                sprite = prefab.Sprite;
            }

            if (color.A == 0)
            {
                color = Color.White;
            }
            return sprite != null;
        }

        private static ItemPrefab? PartPrefab(GunsmithGuiPart part)
        {
            if (string.IsNullOrWhiteSpace(part.ItemIdentifier))
            {
                return null;
            }

            Identifier identifier = part.ItemIdentifier.ToIdentifier();
            if (ItemPrefab.Prefabs.TryGet(identifier, out ItemPrefab? prefab))
            {
                return prefab;
            }

            return (MapEntityPrefab.FindByIdentifier(identifier) ??
                    MapEntityPrefab.FindByName(part.ItemIdentifier)) as ItemPrefab;
        }

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

        private static bool TryCreatePreviewGeometry(Rectangle rect, GunsmithSpriteState state, GunsmithPreviewSettings settings, out Rectangle sourceRect, out Rectangle destination, out float scale)
        {
            sourceRect = CreatePreviewSourceRect(state, settings);
            destination = Rectangle.Empty;
            scale = 1.0f;
            if (sourceRect.Width <= 0 || sourceRect.Height <= 0 || rect.Width <= 0 || rect.Height <= 0)
            {
                return false;
            }

            scale = Math.Min(rect.Width / (float)sourceRect.Width, rect.Height / (float)sourceRect.Height);
            int width = Math.Max((int)Math.Round(sourceRect.Width * scale), 1);
            int height = Math.Max((int)Math.Round(sourceRect.Height * scale), 1);
            destination = new Rectangle(rect.Center.X - width / 2, rect.Center.Y - height / 2, width, height);
            return true;
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
            partRows.Clear();
            partDetailActionButton = null;
            partListSlotPath = null;
            partDetailSlotPath = null;
            selectedPartId = null;
            activePreviewSettings = GunsmithPreviewSettings.Default;
            activeWeaponStats = GunsmithStats.Empty;
            activeQuickMode = false;
            quickOverlayFrame = null;
            suppressQuickUninstallRelease = false;
            warnedQuickAnchorPaths.Clear();
        }

        internal static bool IsGunsmithWindowBlockingInput
            => activeWindow is { Visible: true };

        internal static GUIComponent? ActiveWindowForInputBlock => activeWindow;

        internal static bool TryHandleQuickOverlayDragging()
        {
            if (!activeQuickMode || quickOverlayFrame == null)
            {
                return false;
            }

            return quickOverlayFrame.TryHandleDraggingRelease();
        }

        internal static void RefreshWindow()
        {
            if (activeWindow == null) { return; }
            try
            {
                activeWindow.AddToGUIUpdateList();
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to refresh window: {ex.Message}");
                CloseWindow();
            }
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
                string[] parts = entry.Split('|', 6, StringSplitOptions.TrimEntries);
                if (parts.Length < 5 || string.IsNullOrWhiteSpace(parts[0])) { continue; }

                yield return new GunsmithGuiSlot(
                    parts[0],
                    string.IsNullOrWhiteSpace(parts[1]) ? parts[0] : parts[1],
                    parts[2],
                    parts[3] == "1",
                    ParseParts(parts[4]).ToList(),
                    parts.Length > 5 ? ParseQuickMeta(parts[5]) : GunsmithQuickSlotMeta.Empty);
            }
        }

        private static GunsmithQuickSlotMeta ParseQuickMeta(string metaSpec)
        {
            int slotIndex = -1;
            float anchorX = 0.0f;
            float anchorY = 0.0f;
            bool anchorValid = false;
            HashSet<string> allowedItems = new(StringComparer.OrdinalIgnoreCase);

            foreach (string entry in metaSpec.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('=', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2) { continue; }
                switch (parts[0])
                {
                    case "slot":
                        int.TryParse(parts[1], out slotIndex);
                        break;
                    case "anchorX":
                        float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out anchorX);
                        break;
                    case "anchorY":
                        float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out anchorY);
                        break;
                    case "anchorValid":
                        anchorValid = parts[1] == "1";
                        break;
                    case "items":
                        foreach (string identifier in parts[1].Split('~', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                        {
                            allowedItems.Add(identifier);
                        }
                        break;
                }
            }

            return new GunsmithQuickSlotMeta(slotIndex, new Vector2(anchorX, anchorY), anchorValid, allowedItems);
        }

        private static IEnumerable<GunsmithGuiPart> ParseParts(string partSpec)
        {
            foreach (string entry in partSpec.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split(':', 7, StringSplitOptions.TrimEntries);
                if (parts.Length < 2 || string.IsNullOrWhiteSpace(parts[0])) { continue; }
                yield return new GunsmithGuiPart(
                    parts[0],
                    string.IsNullOrWhiteSpace(parts[1]) ? parts[0] : parts[1],
                    parts.Length > 2 && !string.IsNullOrWhiteSpace(parts[2]) ? parts[2] : "available",
                    parts.Length > 3 ? ParseStats(parts[3]) : GunsmithStats.Empty,
                    parts.Length > 4 ? DecodeText(parts[4]) : string.Empty,
                    parts.Length > 5 ? DecodeText(parts[5]) : string.Empty,
                    parts.Length > 6 && TryParseRectangle(DecodeText(parts[6]), out Rectangle visualSourceRect) ? visualSourceRect : Rectangle.Empty);
            }
        }

        private static string DecodeText(string value)
        {
            return value
                .Replace("%3D", "=", StringComparison.OrdinalIgnoreCase)
                .Replace("%7E", "~", StringComparison.OrdinalIgnoreCase)
                .Replace("%3B", ";", StringComparison.OrdinalIgnoreCase)
                .Replace("%2C", ",", StringComparison.OrdinalIgnoreCase)
                .Replace("%7C", "|", StringComparison.OrdinalIgnoreCase)
                .Replace("%3A", ":", StringComparison.OrdinalIgnoreCase)
                .Replace("%25", "%", StringComparison.OrdinalIgnoreCase);
        }

        private static GunsmithStats ParseStats(string statSpec)
        {
            float ergonomics = 0.0f;
            Dictionary<StatTypes, float> values = new();
            foreach (string entry in statSpec.Split(new[] { ',', '~' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('=', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2 || !float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float value)) { continue; }
                if (string.Equals(parts[0], "Ergonomics", StringComparison.Ordinal))
                {
                    ergonomics = value;
                    continue;
                }

                if (Enum.TryParse(parts[0], ignoreCase: false, out StatTypes statType) && statType != StatTypes.None)
                {
                    values[statType] = value;
                }
            }
            return new GunsmithStats { Ergonomics = ergonomics, Values = values };
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

        private sealed record GunsmithGuiSlot(string Path, string NameKey, string CurrentPartId, bool CanEnter, List<GunsmithGuiPart> Parts, GunsmithQuickSlotMeta QuickMeta);

        private sealed record GunsmithQuickSlotMeta(int SlotIndex, Vector2 Anchor, bool AnchorValid, IReadOnlySet<string> AllowedItemIdentifiers)
        {
            public static GunsmithQuickSlotMeta Empty { get; } = new(-1, Vector2.Zero, false, new HashSet<string>(StringComparer.OrdinalIgnoreCase));
        }

        private sealed record GunsmithPartRow(GUIFrame Frame, GUITextBlock Label, GUITextBlock Status);

        private sealed record GunsmithGuiPart(string Id, string NameKey, string Status, GunsmithStats Stats, string ItemIdentifier, string VisualTexturePath, Rectangle VisualSourceRect)
        {
            public bool IsActionable => Status != "missing" && Status != "disabled" && Status != "incompatible";
        }

        private sealed class GunsmithStats
        {
            public float Ergonomics { get; init; }
            public IReadOnlyDictionary<StatTypes, float> Values { get; init; } = new Dictionary<StatTypes, float>();

            public float Get(StatTypes statType)
                => Values.TryGetValue(statType, out float value) ? value : 0.0f;

            public static GunsmithStats Empty { get; } = new();
        }

        private sealed record GunsmithPreviewSettings(float Padding, float Scale, Vector2 Offset)
        {
            public static GunsmithPreviewSettings Default { get; } = new(12.0f, 1.0f, Vector2.Zero);
        }

        private sealed class GunsmithWindowFrame : GUIFrame
        {
            private readonly Action close;
            private bool dragging;

            public GunsmithWindowFrame(RectTransform rectT, Action close, Color color)
                : base(rectT, style: null, color: color)
            {
                this.close = close;
                CanBeFocused = true;
            }

            public override void Update(float deltaTime)
            {
                base.Update(deltaTime);
                if (!Visible) { return; }

                bool mouseInsideWindow = Rect.Contains(PlayerInput.MousePosition);
                if (!mouseInsideWindow)
                {
                    GUI.ForceMouseOn(this);
                }

                if (PlayerInput.SecondaryMouseButtonClicked())
                {
                    close();
                    return;
                }

                Rectangle dragArea = new(Rect.X, Rect.Y, Rect.Width, Math.Max((int)(Rect.Height * 0.14f), 28));
                if (dragArea.Contains(PlayerInput.MousePosition) && PlayerInput.PrimaryMouseButtonDown())
                {
                    dragging = true;
                }

                if (!PlayerInput.PrimaryMouseButtonHeld())
                {
                    dragging = false;
                    return;
                }

                if (!dragging)
                {
                    return;
                }

                Vector2 speed = PlayerInput.MouseSpeed;
                if (speed == Vector2.Zero)
                {
                    return;
                }

                RectTransform.ScreenSpaceOffset += new Point((int)Math.Round(speed.X), (int)Math.Round(speed.Y));
                ClampToArea(new Rectangle(0, 0, GameMain.GraphicsWidth, GameMain.GraphicsHeight));
            }
        }

        private sealed class GunsmithPreviewImage : GUIFrame
        {
            private readonly Item item;
            private readonly GunsmithPreviewSettings settings;

            public GunsmithPreviewImage(RectTransform rectT, Item item, GunsmithPreviewSettings settings)
                : base(rectT, style: null, color: Color.Transparent)
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
                if (!TryCreatePreviewGeometry(Rect, state, settings, out Rectangle sourceRect, out Rectangle destination, out _))
                {
                    return;
                }

                spriteBatch.Draw(texture, destination, sourceRect, Color.White);
            }
        }

        private sealed class GunsmithPartIcon : GUIFrame
        {
            private readonly Sprite? sprite;
            private readonly Texture2D? texture;
            private readonly Rectangle sourceRect;
            private readonly Color iconColor;
            private readonly float fill;

            public GunsmithPartIcon(RectTransform rectT, Sprite sprite, Color color, float fill)
                : base(rectT, style: null, color: Color.Transparent)
            {
                this.sprite = sprite;
                texture = null;
                sourceRect = Rectangle.Empty;
                iconColor = color;
                this.fill = Math.Clamp(fill, 0.1f, 1.0f);
                CanBeFocused = false;
            }

            public GunsmithPartIcon(RectTransform rectT, Texture2D texture, Rectangle sourceRect, Color color, float fill)
                : base(rectT, style: null, color: Color.Transparent)
            {
                sprite = null;
                this.texture = texture;
                this.sourceRect = sourceRect;
                iconColor = color;
                this.fill = Math.Clamp(fill, 0.1f, 1.0f);
                CanBeFocused = false;
            }

            public override void Draw(SpriteBatch spriteBatch)
            {
                if (!Visible)
                {
                    return;
                }

                base.Draw(spriteBatch);
                if (Rect.Width <= 0 || Rect.Height <= 0)
                {
                    return;
                }

                if (sprite != null)
                {
                    if (sprite.size.X <= 0.0f || sprite.size.Y <= 0.0f)
                    {
                        return;
                    }

                    float scale = Math.Min(Rect.Width / sprite.size.X, Rect.Height / sprite.size.Y) * fill;
                    sprite.Draw(spriteBatch, Rect.Center.ToVector2(), iconColor, scale: scale);
                    return;
                }

                if (texture == null || sourceRect.Width <= 0 || sourceRect.Height <= 0)
                {
                    return;
                }

                float textureScale = Math.Min(Rect.Width / (float)sourceRect.Width, Rect.Height / (float)sourceRect.Height) * fill;
                int width = Math.Max((int)Math.Round(sourceRect.Width * textureScale), 1);
                int height = Math.Max((int)Math.Round(sourceRect.Height * textureScale), 1);
                Rectangle destination = new(Rect.Center.X - width / 2, Rect.Center.Y - height / 2, width, height);
                spriteBatch.Draw(texture, destination, sourceRect, iconColor);
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

            public bool TryHandleDraggingRelease()
            {
                if (!Visible || item == null || item.Removed || !Inventory.DraggingItems.Any() || !PlayerInput.PrimaryMouseButtonReleased() || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return false;
                }

                foreach (QuickSlotLayout layout in BuildSlotLayouts(geometry))
                {
                    if (!layout.Rect.Contains(PlayerInput.MousePosition))
                    {
                        continue;
                    }

                    Item? draggedItem = Inventory.DraggingItems.FirstOrDefault();
                    if (draggedItem != null)
                    {
                        if (CanAcceptDraggedItem(layout.Slot, draggedItem))
                        {
                            suppressQuickUninstallRelease = true;
                            CallLuaHook("DeepGunsmithInstallQuickItem", item, layout.Slot.Path, draggedItem);
                            Inventory.DraggingItems.Clear();
                            SoundPlayer.PlayUISound(GUISoundType.PickItem);
                        }
                        else
                        {
                            suppressQuickUninstallRelease = true;
                            failedDropTimers[layout.Slot.Path] = 0.45f;
                            Inventory.DraggingItems.Clear();
                            SoundPlayer.PlayUISound(GUISoundType.PickItemFail);
                        }
                        return true;
                    }
                }

                if (Rect.Contains(PlayerInput.MousePosition))
                {
                    suppressQuickUninstallRelease = true;
                    Inventory.DraggingItems.Clear();
                    return true;
                }

                return false;
            }

            public bool ContainsMouseOrSlot(Point mousePosition)
            {
                if (!Visible || item == null || item.Removed || !TryCreateQuickGeometry(out QuickGeometry geometry))
                {
                    return false;
                }

                return Rect.Contains(mousePosition) || BuildSlotLayouts(geometry).Any(layout => layout.Rect.Contains(mousePosition));
            }

            public override void Draw(SpriteBatch spriteBatch)
            {
                if (!Visible || item == null || item.Removed || !TryGetValidState(item, out GunsmithSpriteState state))
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
                return item != null && TryGetValidState(item, out GunsmithSpriteState state) && TryCreateQuickGeometry(state, out geometry);
            }

            private bool TryCreateQuickGeometry(GunsmithSpriteState state, out QuickGeometry geometry)
            {
                geometry = default;
                Rectangle previewRect = Rect;
                previewRect.Inflate(-(int)(48 * GUI.xScale), -(int)(28 * GUI.yScale));
                if (!TryCreatePreviewGeometry(previewRect, state, settings, out Rectangle sourceRect, out Rectangle destination, out float scale))
                {
                    return false;
                }

                geometry = new QuickGeometry(sourceRect, destination, scale);
                return true;
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

                int minX = Math.Max(destination.X - 110, 8);
                int maxX = Math.Min(destination.Right + 110 - QuickSlotSize, GameMain.GraphicsWidth - QuickSlotSize - 8);
                int minY = Math.Max(destination.Y - 76, 58);
                int maxY = Math.Min(destination.Bottom + 76 - QuickSlotSize, GameMain.GraphicsHeight - QuickSlotSize - 8);
                return new Rectangle(Math.Clamp(x, minX, maxX), Math.Clamp(y, minY, maxY), QuickSlotSize, QuickSlotSize);
            }

            private void DrawQuickSlot(SpriteBatch spriteBatch, QuickSlotLayout layout)
            {
                VisualSlot visualSlot = new(layout.Rect);
                GunsmithGuiPart? installedPart = layout.Slot.Parts.FirstOrDefault(part => part.Id == layout.Slot.CurrentPartId);
                Inventory.DrawSlot(spriteBatch, null, visualSlot, null, -1, drawItem: false);

                bool mouseOn = layout.Rect.Contains(PlayerInput.MousePosition);
                Item? draggedItem = Inventory.DraggingItems.FirstOrDefault();
                bool canAccept = draggedItem != null && CanAcceptDraggedItem(layout.Slot, draggedItem);
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

            private bool CanAcceptDraggedItem(GunsmithGuiSlot slot, Item draggedItem)
            {
                string identifier = draggedItem.Prefab?.Identifier.Value ?? string.Empty;
                return !string.IsNullOrWhiteSpace(identifier) &&
                    slot.QuickMeta.AllowedItemIdentifiers.Contains(identifier) &&
                    item?.OwnInventory?.CanBePutInSlot(draggedItem, slot.QuickMeta.SlotIndex) == true;
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
                CallLuaHook("DeepGunsmithSetQuickPart", item, slot.Path, EmptyPartId);
                SoundPlayer.PlayUISound(GUISoundType.PickItem);
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
