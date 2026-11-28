using System.Reflection;
using System.Runtime.CompilerServices;
using Barotrauma;
using Microsoft.Xna.Framework;

internal static class NativeHudChecks
{
    internal static void Verify(Type runtime, string cleanup)
    {
        const BindingFlags flags = BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
        static T Fixture<T>() => (T)RuntimeHelpers.GetUninitializedObject(typeof(T));
        static void Check(bool value, string name) { if (!value) { throw new Exception("HUD " + name); } }
        void Call(string method) => runtime.GetMethod(method, flags)!.Invoke(null, null);
        var tracked = runtime.GetField("Tracked", flags)!;
        var hud = runtime.GetField("trackedHud", flags)!;
        GUIButton? Collect()
        {
            Call("CollectTrackedHud");
            return (GUIButton?)hud.GetValue(null);
        }
        void State(string quest, string goal, int count)
        {
            var state = new DeepDivingArmory.Quests.QuestState();
            state.Active[quest] = new() { [goal] = count };
            var property = runtime.GetProperty("State", flags)!;
            property.SetValue(null, property.PropertyType.GetMethod("Read", flags)!.Invoke(null, [state.Write()]));
            tracked.SetValue(null, quest);
            var revision = runtime.GetProperty("Revision", flags)!;
            revision.SetValue(null, (int)revision.GetValue(null)! + 1);
        }
        bool Says(GUIButton b, string text) => b.GetAllChildren<GUITextBlock>().Any(label => label.Text.SanitizedString.Value == text);
        var session = GameMain.GameSession = Fixture<GameSession>();
        session.IsRunning = true;
        Screen.Selected = GameMain.GameScreen = Fixture<GameScreen>();
        var cfg = GameSettings.CurrentConfig;
        State("co_pirate_patrol", "pirates", 2);
        foreach (var (w, h, scale) in new[] { (1280, 720, 1f), (1280, 720, 1.5f), (1920, 1080, 1f), (3440, 1440, 1.25f) })
        {
            GameMain.GraphicsWidth = w;
            GameMain.GraphicsHeight = h;
            cfg.Graphics.HUDScale = scale;
            typeof(GameSettings).GetField("currentConfig", flags)!.SetValue(null, cfg);
            GUICanvas.RecalculateSize();
            HUDLayoutSettings.InventoryTopY = h - h / 6;
            HUDLayoutSettings.CreateAreas();
            var b = Collect()!;
            Check(b.Visible && ReferenceEquals(b, Collect()) && Says(b, "★ 寒冰洋治安巡逻") && Says(b, "2 / 5") && Says(b, "击败海盗武装人员"), "active, cached rows and title");
            Check(HUDLayoutSettings.TutorialObjectiveListArea.Contains(b.Rect) && !new[] { HUDLayoutSettings.CrewArea,
                HUDLayoutSettings.ButtonAreaTop, HUDLayoutSettings.MessageAreaTop, HUDLayoutSettings.HealthBarAfflictionArea,
                HUDLayoutSettings.BottomRightInfoArea, HUDLayoutSettings.InventoryAreaLower }.Any(r => b.Rect.Intersects(r)), $"safe bounds at {w}x{h} / {scale}: {b.Rect}");
        }
        var collect = runtime.GetMethod("CollectTrackedHud", flags)!.CreateDelegate<Action>();
        void CheckAllocations()
        {
            for (int i = 0; i < 100; i++) { GUI.additions.Clear(); collect(); }
            long before = GC.GetAllocatedBytesForCurrentThread();
            for (int i = 0; i < 100; i++) { GUI.additions.Clear(); collect(); }
            long allocated = GC.GetAllocatedBytesForCurrentThread() - before;
            Check(allocated == 0, $"steady HUD {tracked.GetValue(null)} allocated {allocated} bytes over 100 frames");
        }
        CheckAllocations();
        State("dda_tide_gauge", "mine", 0);
        var longHud = Collect()!;
        var bar = longHud.GetChild<GUIScrollBar>();
        var rows = longHud.Children.Single(c => c.CountChildren == 25);
        Check(longHud.Rect.Contains(bar.Rect) && HUDLayoutSettings.TutorialObjectiveListArea.Contains(longHud.Rect) &&
            bar.BarSize < 1 && rows.Children.First().Visible && !rows.Children.Last().Visible, "long checklist fits");
        bar.BarScroll = 1;
        bar.OnMoved(bar, bar.BarScroll);
        Check(!rows.Children.First().Visible && rows.Children.Last().Visible && rows.Children.Where(c => c.Visible).All(c => rows.Rect.Contains(c.Rect)),
            "last objectives reachable and visible rows stay in the card");
        CheckAllocations();
        State("co_pirate_patrol", "pirates", 2);
        var previousRound = Collect()!;
        runtime.GetProperty("Round", flags)!.SetValue(null, "next-round");
        var active = Collect()!;
        Check(!ReferenceEquals(active, previousRound) && previousRound.RectTransform.Parent == null, "new round with identical revision");
        State("co_pirate_patrol", "pirates", 5);
        var ready = Collect()!;
        Check(!ReferenceEquals(ready, active) && active.RectTransform.Parent == null && Says(ready, "✓") && Says(ready, "5 / 5") &&
            Says(ready, "打开委托面板提交"), "live progress, ready guidance and stale tree release");
        GUI.DisableHUD = true;
        Check(!Collect()!.Visible, "disable");
        GUI.DisableHUD = false;
        GUI.PauseMenuOpen = true;
        Check(!Collect()!.Visible, "pause");
        GUI.PauseMenuOpen = false;
        session.tabMenu = Fixture<TabMenu>();
        Check(!Collect()!.Visible, "tab");
        session.tabMenu = null;
        var dialog = runtime.GetField("dialog", flags)!;
        dialog.SetValue(null, Fixture<GUIMessageBox>());
        Check(!Collect()!.Visible, "NPC dialog");
        dialog.SetValue(null, null);
        session.IsRunning = false;
        Check(!Collect()!.Visible, "stopped session");
        session.IsRunning = true;
        Screen.Selected = null;
        Check(!Collect()!.Visible, "different screen");
        Screen.Selected = GameMain.GameScreen;
        Check(ReferenceEquals(Collect(), ready) && ready.Visible, "restore same tree");
        if (cleanup == "ClearRound")
        {
            // A native conversation keeps TAB closed; the HUD opens the global contracts dialog instead.
            var conversation = new GUIFrame(new RectTransform(new Point(8, 8)), style: null) { UserData = "ConversationAction" };
            GUIMessageBox.MessageBoxes.Add(conversation);
            var portraits = (System.Collections.IDictionary)runtime.GetField("portraits", flags)!.GetValue(null)!;
            foreach (string id in new[] { "peachhat", "benzene", "sterling", "natalia", "harland", "liaison" }) { portraits[id] = null; }
            Check(ready.OnClicked(ready, null), "click accepted");
            var panel = runtime.GetField("dialoguePanel", flags)!.GetValue(null)!;
            Check(Equals(panel.GetType().GetField("selected", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(panel), "co_pirate_patrol") &&
                !Collect()!.Visible, "click opens contracts at tracked quest");
            Call("CloseDialogue");
            GUIMessageBox.MessageBoxes.Remove(conversation);
        }
        GUI.ForceMouseOn(ready);
        tracked.SetValue(null, null);
        Check(Collect() == null && ready.OnClicked == null && ready.CountChildren == 0 && GUI.MouseOn == null && ready.RectTransform.Parent == null, "untrack releases hit target");
        State("co_pirate_bounty", "pirates", 1);
        var abandoned = Collect()!;
        var stateProperty = runtime.GetProperty("State", flags)!;
        stateProperty.SetValue(null, stateProperty.PropertyType.GetMethod("Read", flags)!.Invoke(null, [""]));
        Call("Publish");
        Check(tracked.GetValue(null) == null && Collect() == null && abandoned.RectTransform.Parent == null, "abandoned quest disappears");
        State("gunsmith_plastic_test", "plastic", 4);
        var both = new DeepDivingArmory.Quests.QuestState();
        both.Active["gunsmith_plastic_test"] = new() { ["plastic"] = 4, ["relay"] = 1 };
        stateProperty.SetValue(null, stateProperty.PropertyType.GetMethod("Read", flags)!.Invoke(null, [both.Write()]));
        var last = Collect()!;
        Check(Says(last, "✓") && last.GetAllChildren<GUITextBlock>().Any(t => t.Text.SanitizedString.Value.Contains("氧化苯")) &&
            last.OnClicked != null, "in-person guidance and click target");
        Call(cleanup);
        Check(hud.GetValue(null) == null && last.OnClicked == null && last.RectTransform.Parent == null && tracked.GetValue(null) == null, cleanup);
        GameMain.GameSession = null;
        Screen.Selected = GameMain.GameScreen = null;
        Console.WriteLine("PASS native HUD progress, safe areas, visibility, cache, tracking and " + cleanup);
    }
}
