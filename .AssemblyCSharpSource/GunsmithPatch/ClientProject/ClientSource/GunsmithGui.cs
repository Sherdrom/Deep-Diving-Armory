namespace GunsmithPatch
{
    public static partial class GunsmithApi
    {
        private static GUIFrame? activeWindow;

        public static void OpenFromLua(Item item, string title, string slotSpec)
        {
            if (item == null || item.Removed) { return; }

            CloseWindow();

            activeWindow = new GUIFrame(new RectTransform(new Vector2(0.42f, 0.52f), GUI.Canvas, Anchor.Center), color: Color.Black * 0.85f);
            GUIListBox list = new(new RectTransform(new Vector2(0.94f, 0.88f), activeWindow.RectTransform, Anchor.Center));
            _ = new GUITextBlock(new RectTransform(new Vector2(1.0f, 0.12f), list.Content.RectTransform), title, textAlignment: Alignment.Center);

            foreach ((string slot, string label) in ParseSlotSpec(slotSpec))
            {
                GUIButton button = new(new RectTransform(new Vector2(1.0f, 0.13f), list.Content.RectTransform), (LocalizedString)label, Alignment.Center);
                button.OnClicked = (_, _) =>
                {
                    CallLuaHook("DeepGunsmithCycle", item, slot);
                    return true;
                };
            }

            GUIButton closeButton = new(new RectTransform(new Vector2(1.0f, 0.13f), list.Content.RectTransform), (LocalizedString)"Close", Alignment.Center);
            closeButton.OnClicked = (_, _) =>
            {
                CloseWindow();
                return true;
            };

            try
            {
                activeWindow.AddToGUIUpdateList();
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to add window to GUI update list: {ex.Message}");
            }
        }

        private static void CloseWindow()
        {
            if (activeWindow == null) { return; }
            activeWindow.RectTransform.Parent = null;
            activeWindow = null;
        }

        internal static void RefreshWindow()
        {
            if (activeWindow == null) { return; }
            activeWindow.AddToGUIUpdateList();
        }

        private static IEnumerable<(string Slot, string Label)> ParseSlotSpec(string slotSpec)
        {
            foreach (string entry in slotSpec.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = entry.Split('|', 2, StringSplitOptions.TrimEntries);
                if (parts.Length != 2 || string.IsNullOrWhiteSpace(parts[0])) { continue; }
                yield return (parts[0], parts[1]);
            }
        }
    }
}
