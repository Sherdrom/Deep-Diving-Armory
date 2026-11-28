using static DeepDivingArmory.Quests.QuestStyle;

namespace DeepDivingArmory.Quests;

public static partial class QuestRuntime
{
    private static GUIButton? trackedHud;
    private static GUIScrollBar? hudScroll;
    private static (string Round, string Id, int Revision, Point Viewport, float Scale) hudVersion;

    internal static void CollectTrackedHud()
    {
        if (Tracked == null || !State.Active.ContainsKey(Tracked) || !Rules.Quests.TryGetValue(Tracked, out var quest))
        {
            if (trackedHud != null) { ReleaseTrackedHud(); }
            return;
        }
        if (Screen.Selected != GameMain.GameScreen || GameMain.GameSession?.IsRunning != true ||
            GUI.DisableHUD || GUI.PauseMenuOpen || GameSession.IsTabMenuOpen || dialog != null)
        {
            if (trackedHud != null) { trackedHud.Visible = false; }
            return;
        }
        var version = (Round, Tracked, Revision, new Point(GameMain.GraphicsWidth, GameMain.GraphicsHeight), GUI.Scale);
        if (trackedHud == null || hudVersion != version)
        {
            ReleaseTrackedHud();
            trackedHud = BuildTrackedHud(quest);
            hudVersion = version;
        }
        var safe = HUDLayoutSettings.TutorialObjectiveListArea;
        int padding = Math.Max(3, GUI.IntScale(9)), top = safe.Top + padding;
        if (GameMain.Client?.VotingInterface?.frame is { Visible: true } vote) { top = Math.Max(top, vote.Rect.Bottom + padding); }
        foreach (var objective in ObjectiveManager.activeObjectives)
        {
            if (objective.LinkedTextBlock is { Visible: true } label) { top = Math.Max(top, label.Rect.Bottom + padding); }
        }
        trackedHud.Visible = top + trackedHud.Rect.Height <= safe.Bottom;
        if (!trackedHud.Visible) { return; }
        var offset = new Point(GameMain.GraphicsWidth - safe.Right, top);
        if (trackedHud.RectTransform.AbsoluteOffset != offset) { trackedHud.RectTransform.AbsoluteOffset = offset; }
        if (hudScroll != null && PlayerInput.ScrollWheelSpeed != 0 && GUI.IsMouseOn(trackedHud))
        {
            hudScroll.BarScroll -= Math.Sign(PlayerInput.ScrollWheelSpeed) * hudScroll.Step;
            hudScroll.OnMoved(hudScroll, hudScroll.BarScroll);
        }
        trackedHud.AddToGUIUpdateList();
    }

    private static GUIButton BuildTrackedHud(Quest q)
    {
        var text = QuestPanel.Text;
        var status = State.Status(Rules, q);
        bool ready = status == QuestStatus.Ready;
        Color tone = Tone(status);
        var safe = HUDLayoutSettings.TutorialObjectiveListArea;
        int p = Math.Max(3, GUI.IntScale(9)), line = Math.Max(12, GUI.IntScale(25));
        int width = Math.Min(GUI.IntScale(365), safe.Width);
        int top = safe.Top + p, row = line + p, footer = ready ? line + p : 0;
        int available = Math.Min(GameMain.GraphicsHeight / 3, safe.Bottom - top) - 3 * p - line - footer;
        int visibleRows = Math.Clamp(available / row, 1, q.Objectives.Length);
        int rowsHeight = visibleRows * row;
        int height = 3 * p + line + rowsHeight + footer;
        var rect = new RectTransform(new Point(width, height), GUI.Canvas, Anchor.TopRight, isFixedSize: true);
        var button = new GUIButton(rect, "", style: null)
        {
            Color = Panel * .92f, HoverColor = Hover * .95f, PressedColor = Selected, OutlineColor = Edge,
            OnClicked = (_, _) =>
            {
                if (hudScroll != null && (GUI.IsMouseOn(hudScroll) || GUIScrollBar.DraggingBar == hudScroll)) { return false; }
                OpenGlobal();
                (tabPanel ?? dialoguePanel)?.RevealTracked();
                return true;
            }
        };
        button.Frame.OutlineThickness = 1;
        int stripe = Math.Max(3, GUI.IntScale(3)), left = stripe + p, inner = width - left - p;
        Surface(button, new(0, 0, stripe, height), tone);
        string state = text.Ui(ready ? "ready" : "active");
        int badge = Math.Min(inner / 3, Measure(state) + 2 * p);
        Label(button, new(left, p, inner - badge - p, line), "★ " + text.Title(q.Id), Ink, GUIStyle.Font);
        Chip(button, new(width - p - badge, p, badge, line), state, tone);

        int overflow = q.Objectives.Length - visibleRows, y = line + 2 * p;
        int barWidth = overflow > 0 ? Math.Max(8, GUI.IntScale(14)) : 0;
        if (overflow > 0) { inner -= barWidth + p; }
        var rows = Surface(button, new(left, y, inner, rowsHeight), Color.Transparent);
        for (int i = 0; i < q.Objectives.Length; i++)
        {
            var objective = q.Objectives[i];
            var item = Surface(rows, new(0, i < visibleRows ? i * row : 0, inner, row), Color.Transparent);
            item.Visible = i < visibleRows;
            int current = State.Progress(q, objective);
            bool done = current == objective.Count;
            string count = $"{current} / {objective.Count}";
            int countWidth = Math.Min(inner / 3, Measure(count) + p);
            Label(item, new(0, 0, line, line), done ? "✓" : "□", done ? Green : Dim);
            Label(item, new(line, 0, inner - line - countWidth - p, line), text.Objective(q, objective), Sub);
            Label(item, new(inner - countWidth, 0, countWidth, line), count, done ? Green : Ink, align: Alignment.CenterRight);
            Meter(item, new(line, line, inner - line, Math.Max(1, GUI.IntScale(2))), (float)current / objective.Count, done ? Green : Cyan);
        }
        if (overflow > 0)
        {
            // A native list box allocates enumerators on every HUD collection, even while idle.
            hudScroll = new GUIScrollBar(At(button, new(width - p - barWidth, y, barWidth, rowsHeight)),
                (float)visibleRows / q.Objectives.Length, isHorizontal: false) { Step = 1f / overflow };
            hudScroll.OnMoved = (_, value) =>
            {
                int first = (int)MathF.Round(value * overflow);
                for (int i = 0; i < rows.CountChildren; i++)
                {
                    var child = rows.RectTransform.GetChild(i);
                    child.GUIComponent.Visible = i >= first && i < first + visibleRows;
                    if (child.GUIComponent.Visible) { child.AbsoluteOffset = new Point(0, (i - first) * row); }
                }
                return true;
            };
        }
        if (ready)
        {
            string hint = q.Remote ? text.Ui("turninpanel") : text.Ui("visit").Replace("[npc]", text.Npc(q.Npc, "name"));
            Label(button, new(left, height - line - p, width - left - p, line), hint, Green);
        }
        return button;
    }

    private static void ReleaseTrackedHud()
    {
        if (hudScroll != null)
        {
            if (GUIScrollBar.DraggingBar == hudScroll) { GUIScrollBar.DraggingBar = null; }
            hudScroll.OnMoved = null;
            hudScroll = null;
        }
        if (trackedHud is { } old)
        {
            old.Visible = false;
            if (GUI.IsMouseOn(old)) { GUI.ForceMouseOn(null); }
            Detach(ref trackedHud);
            old.ClearChildren();
        }
        hudVersion = default;
    }
}
