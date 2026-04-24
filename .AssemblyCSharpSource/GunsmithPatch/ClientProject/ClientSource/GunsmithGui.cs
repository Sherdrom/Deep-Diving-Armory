namespace GunsmithPatch
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

        public static void OpenFromLua(Item item, string title, string slotSpec)
        {
            if (item == null || item.Removed) { return; }

            GunsmithGuiSpec spec = ParseSpec(slotSpec);
            if (spec.Slots.Count == 0) { return; }

            if (string.IsNullOrWhiteSpace(selectedSlot) || spec.Slots.All(slot => slot.Path != selectedSlot))
            {
                selectedSlot = spec.Slots[0].Path;
            }

            CloseWindow();

            activeItem = item;
            activeContext = spec.Context;
            activeSlots = spec.Slots;
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

        private static void BuildHeader(string title)
        {
            if (activeWindow == null) { return; }

            GUIFrame header = new(new RectTransform(new Vector2(0.96f, 0.12f), activeWindow.RectTransform, Anchor.TopCenter), color: Color.Black * 0.35f);
            _ = new GUITextBlock(new RectTransform(new Vector2(0.76f, 0.78f), header.RectTransform, Anchor.CenterLeft), title, textAlignment: Alignment.CenterLeft);

            GUIButton closeButton = new(new RectTransform(new Vector2(0.16f, 0.72f), header.RectTransform, Anchor.CenterRight), (LocalizedString)"关闭", Alignment.Center);
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

            GUIFrame middle = new(new RectTransform(new Vector2(0.38f, 0.96f), body.RectTransform, Anchor.Center), color: Color.Transparent);
            previewPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.66f), middle.RectTransform, Anchor.TopCenter), color: Color.Black * 0.25f);
            detailPanel = new GUIFrame(new RectTransform(new Vector2(1.0f, 0.30f), middle.RectTransform, Anchor.BottomCenter), color: Color.Black * 0.25f);
            partList = new GUIListBox(new RectTransform(new Vector2(0.30f, 0.96f), body.RectTransform, Anchor.CenterRight));

            RefreshSelectionPanels();
        }

        private static void BuildSlotPanel(GUIFrame body)
        {
            slotList = new GUIListBox(new RectTransform(new Vector2(0.26f, 0.96f), body.RectTransform, Anchor.CenterLeft));
            RebuildSlotList();
        }

        private static void RebuildSlotList()
        {
            if (slotList == null) { return; }
            slotList.Content.ClearChildren();

            _ = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.12f), slotList.Content.RectTransform), (LocalizedString)"当前层级槽位", textAlignment: Alignment.Center);

            if (!string.IsNullOrWhiteSpace(activeContext.CurrentPath))
            {
                GUIButton backButton = new(new RectTransform(new Vector2(1.0f, 0.13f), slotList.Content.RectTransform), (LocalizedString)"[返回上级]", Alignment.Center);
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
                string prefix = slot.Path == selectedSlot ? "[选中] " : "";
                GUIButton selectButton = new(new RectTransform(new Vector2(1.0f, 0.13f), slotList.Content.RectTransform), (LocalizedString)(prefix + slot.Name), Alignment.Center);
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

            RebuildPreviewPanel(slot);
            RebuildPartList(slot);
        }

        private static void RebuildPreviewPanel(GunsmithGuiSlot slot)
        {
            if (previewPanel == null) { return; }
            previewPanel.ClearChildren();
            detailPanel?.ClearChildren();

            _ = new GUITextBlock(new RectTransform(new Vector2(0.92f, 0.28f), previewPanel.RectTransform, Anchor.Center), (LocalizedString)"枪械预览区域", textAlignment: Alignment.Center);

            if (detailPanel == null) { return; }
            _ = new GUITextBlock(new RectTransform(new Vector2(0.92f, 0.36f), detailPanel.RectTransform, Anchor.TopCenter), (LocalizedString)$"路径: {activeContext.PathLabel}", textAlignment: Alignment.Center);

            if (!slot.CanEnter) { return; }
            GUIButton enterButton = new(new RectTransform(new Vector2(0.72f, 0.36f), detailPanel.RectTransform, Anchor.BottomCenter), (LocalizedString)"进入该配件挂点", Alignment.Center);
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

            _ = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.12f), partList.Content.RectTransform), (LocalizedString)$"{slot.Name}配件", textAlignment: Alignment.Center);

            foreach (GunsmithGuiPart part in slot.Parts)
            {
                bool installed = part.Id == slot.CurrentPartId || (part.Id == EmptyPartId && string.IsNullOrWhiteSpace(slot.CurrentPartId));
                string label = installed ? "[已安装] " + part.Name : part.Name;
                GUIButton button = new(new RectTransform(new Vector2(1.0f, 0.14f), partList.Content.RectTransform), (LocalizedString)label, Alignment.Center);
                button.OnClicked = (_, _) =>
                {
                    if (!installed && activeItem != null && !activeItem.Removed)
                    {
                        CallLuaHook("DeepGunsmithSetPart", activeItem, slot.Path, part.Id);
                    }
                    return true;
                };
            }
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
            string slotsText = sections.Length > 1 ? sections[1] : string.Empty;
            return new GunsmithGuiSpec(context, ParseSlots(slotsText).ToList());
        }

        private static GunsmithGuiContext ParseContext(string contextSpec)
        {
            string[] parts = contextSpec.Split('|', 3, StringSplitOptions.TrimEntries);
            return new GunsmithGuiContext(
                parts.Length > 0 ? parts[0] : string.Empty,
                parts.Length > 1 && !string.IsNullOrWhiteSpace(parts[1]) ? parts[1] : "枪械",
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
                string[] parts = entry.Split(':', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2 || string.IsNullOrWhiteSpace(parts[0])) { continue; }
                yield return new GunsmithGuiPart(parts[0], string.IsNullOrWhiteSpace(parts[1]) ? parts[0] : parts[1]);
            }
        }

        private sealed record GunsmithGuiSpec(GunsmithGuiContext Context, List<GunsmithGuiSlot> Slots);

        private sealed record GunsmithGuiContext(string CurrentPath, string PathLabel, string ParentPath)
        {
            public static GunsmithGuiContext Empty { get; } = new(string.Empty, "枪械", string.Empty);
        }

        private sealed record GunsmithGuiSlot(string Path, string Name, string CurrentPartId, bool CanEnter, List<GunsmithGuiPart> Parts);

        private sealed record GunsmithGuiPart(string Id, string Name);
    }
}
