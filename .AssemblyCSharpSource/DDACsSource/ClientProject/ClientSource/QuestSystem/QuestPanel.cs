using static DeepDivingArmory.Quests.QuestStyle;

namespace DeepDivingArmory.Quests;

internal sealed partial class QuestPanel : GUIFrame
{
    internal static readonly QuestText Text = new(key => TextManager.Get(key).Fallback("").Value,
        id => ItemPrefab.FindByIdentifier(id.ToIdentifier())?.Name.Value ?? id);
    private readonly Publisher? publisher;
    private readonly ushort speaker;
    private readonly bool preview;
    private QuestLayout layout = null!;
    private GUIFrame header = null!, actions = null!, publisherRow = null!;
    private GUIListBox list = null!, body = null!;
    private GUITextBlock summary = null!, readySummary = null!;
    private GUIButton[] filters = [];
    private string? selected, npcFilter, lastRound, lastTracked;
    private int filter, publisherPage, cardWidth, sectionWidth, revision = -1;
    private bool listDirty = true, detailDirty = true, canAct;
    private Point size;
    private float scale;

    internal QuestPanel(GUIComponent parent, Publisher? publisher = null, ushort speaker = 0, bool preview = false)
        : base(new RectTransform(Vector2.One, parent.RectTransform), style: null)
    {
        selected = QuestRuntime.Tracked;
        this.publisher = publisher;
        this.speaker = speaker;
        this.preview = preview;
        Color = Deep;
        Refresh();
    }

    private static GUIListBox Scroll(GUIComponent parent, Box box)
    {
        var scroll = new GUIListBox(At(parent, box), style: null)
        {
            AutoHideScrollBar = true, KeepSpaceForScrollBar = false, ScrollBarVisible = false,
            Spacing = Math.Max(2, GUI.IntScale(6)), CurrentSelectMode = GUIListBox.SelectMode.None
        };
        scroll.ContentBackground.Color = Deep;
        scroll.Padding = Vector4.Zero;
        scroll.UpdateDimensions();
        return scroll;
    }

    private static void FillScroll(GUIListBox scroll, Action populate)
    {
        float position = scroll.BarScroll;
        // Measure at full width first: a wrapped paragraph can otherwise keep an unnecessary scrollbar visible.
        scroll.ScrollBarVisible = false;
        scroll.UpdateDimensions();
        scroll.Content.ClearChildren();
        populate();
        scroll.UpdateScrollBarSize();
        if (scroll.BarSize < 1)
        {
            scroll.ScrollBarVisible = true;
            scroll.UpdateDimensions();
            scroll.Content.ClearChildren();
            populate();
            scroll.UpdateScrollBarSize();
        }
        scroll.ScrollBar.Enabled = scroll.ScrollBarVisible;
        scroll.BarScroll = scroll.ScrollBarVisible ? position : 0;
    }

    public override void AddToGUIUpdateList(bool ignoreChildren = false, int order = 0)
    {
        Refresh();
        base.AddToGUIUpdateList(ignoreChildren, order);
    }

    internal void Refresh()
    {
        if (size != Rect.Size || scale != GUI.Scale)
        {
            size = Rect.Size;
            scale = GUI.Scale;
            layout = new QuestLayout(size.X, size.Y, scale);
            ClearChildren();
            Surface(this, layout.Left, Panel, Edge, inner: true);
            Surface(this, layout.Right, Panel, Edge, inner: true);
            publisherRow = Surface(this, layout.Publisher, Panel);
            filters = Enumerable.Range(0, 4).Select(i => Button(this, layout.Filters.Cell(i, 4, layout.Padding), "",
                () => { filter = i; listDirty = true; })).ToArray();
            list = Scroll(this, layout.List);
            var foot = Surface(this, layout.Summary, Tile, Edge);
            int p = layout.Padding, half = foot.Rect.Width / 2;
            summary = Label(foot, new(p, 0, half - p, foot.Rect.Height), "", Sub);
            readySummary = Label(foot, new(half, 0, foot.Rect.Width - half - p, foot.Rect.Height), "", Dim, align: Alignment.CenterRight);
            header = Surface(this, layout.Header, Tile, Edge, inner: true);
            body = Scroll(this, layout.Body);
            actions = Surface(this, layout.Actions, Panel);
            listDirty = true;
        }
        if (revision != QuestRuntime.Revision || lastRound != QuestRuntime.Round || lastTracked != QuestRuntime.Tracked)
        {
            revision = QuestRuntime.Revision;
            lastRound = QuestRuntime.Round;
            lastTracked = QuestRuntime.Tracked;
            listDirty = true;
        }
        if (listDirty || cardWidth != list.Content.Rect.Width)
        {
            detailDirty |= listDirty;
            RefreshList();
            cardWidth = list.Content.Rect.Width;
            listDirty = false;
        }
        bool allowed = QuestRuntime.Round.Length > 0 && Character.Controlled is { IsDead: false, IsIncapacitated: false } &&
            (!preview || GameMain.IsSingleplayer);
        if (canAct != allowed) { canAct = allowed; detailDirty = true; }
        if (detailDirty || sectionWidth != body.Content.Rect.Width)
        {
            RefreshDetail();
            sectionWidth = body.Content.Rect.Width;
            detailDirty = false;
        }
    }

    private static QuestStatus Status(Quest q) => QuestRuntime.State.Status(QuestRuntime.Rules, q);
    private static string StatusText(QuestStatus s) => Text.Ui(s.ToString().ToLowerInvariant());
    private static string Title(string id) => (QuestRuntime.Tracked == id ? "★ " : "") + Text.Title(id);
    private static string Fit(string value, GUIFont font, int width) =>
        Measure(value, font) <= width ? value : ToolBox.LimitString(value, font, width).Value;

    private void RefreshList()
    {
        var rules = QuestRuntime.Rules;
        var entries = rules.Quests.Values.Select(q => (Quest: q, Status: Status(q))).ToArray();
        Publishers(entries.Where(e => e.Status == QuestStatus.Ready).Select(e => e.Quest.Npc).ToHashSet());
        string? owner = publisher?.Id ?? npcFilter;
        var scoped = entries.Where(e => owner == null || e.Quest.Npc == owner).ToArray();
        QuestStatus[] byFilter = [QuestStatus.Ready, QuestStatus.Active, QuestStatus.Available];
        int[] counts = [scoped.Length, .. byFilter.Select(s => scoped.Count(e => e.Status == s))];
        string[] keys = ["all", "ready", "active", "available"];
        for (int i = 0; i < filters.Length; i++)
        {
            var b = filters[i];
            b.Text = Text.Ui(keys[i]) + " " + counts[i];
            Paint(b, filter == i, i == 0 ? Focus : Tone(byFilter[i - 1]));
        }
        var visible = scoped.Where(e => filter == 0 || e.Status == byFilter[filter - 1]).ToArray();
        if (!visible.Any(e => e.Quest.Id == selected)) { selected = visible.FirstOrDefault().Quest?.Id; body.BarScroll = 0; }
        FillScroll(list, () =>
        {
            foreach (var (quest, status) in visible) { AddCard(quest, status); }
        });
        summary.Text = Text.Ui("accepted") + "  " + (counts[1] + counts[2]);
        readySummary.Text = Text.Ui("ready") + "  " + counts[1];
        readySummary.TextColor = counts[1] > 0 ? Green : Dim;
    }

    private void Publishers(HashSet<string> ready)
    {
        publisherRow.ClearChildren();
        int width = publisherRow.Rect.Width, h = publisherRow.Rect.Height, p = layout.Padding;
        if (publisher != null)
        {
            QuestStyle.Portrait(publisherRow, new(1, 1, h - 2, h - 2), publisher);
            Label(publisherRow, new(h + p, 0, width - h - p, h), Text.Npc(publisher.Id, "name") + " · " + Text.Ui("tab"), Sub);
            return;
        }
        var npcs = QuestRuntime.Rules.Npcs.Values.ToArray();
        int allWidth = Math.Min(width / 3, Math.Max(h, Measure(Text.Ui("all")) + p * 4));
        var all = Button(publisherRow, new(0, 0, allWidth, h), Text.Ui("all"), () => { npcFilter = null; listDirty = true; });
        Paint(all, npcFilter == null, Cyan);
        int available = Math.Max(1, width - allWidth - p);
        bool paged = npcs.Length * (h + p) - p > available;
        int thumb = paged ? Math.Min(h, Math.Max(1, (available - p) / 2)) : h;
        int step = thumb + p, top = (h - thumb) / 2;
        int capacity = Math.Max(1, (available + p - (paged ? step : 0)) / step);
        int pages = Math.Max(1, (npcs.Length + capacity - 1) / capacity);
        publisherPage %= pages;
        int x = allWidth + p;
        foreach (var npc in npcs.Skip(publisherPage * capacity).Take(capacity))
        {
            var b = Button(publisherRow, new(x, top, thumb, thumb), "", () => { npcFilter = npc.Id; listDirty = true; });
            b.ToolTip = Text.Npc(npc.Id, "name");
            Paint(b, npcFilter == npc.Id, Amber);
            int inset = Math.Max(2, p / 2);
            QuestStyle.Portrait(b, new(inset, inset, thumb - inset * 2, thumb - inset * 2), npc);
            if (ready.Contains(npc.Id)) { Label(b, new(thumb / 2, 0, thumb / 2, thumb / 2), "●", Green, align: Alignment.TopRight); }
            x += step;
        }
        if (paged)
        {
            var next = Button(publisherRow, new(width - thumb, top, thumb, thumb), "›", () => { publisherPage = (publisherPage + 1) % pages; listDirty = true; });
            next.ToolTip = Text.Ui("morepublishers");
        }
    }

    private void AddCard(Quest q, QuestStatus status)
    {
        int w = list.Content.Rect.Width, h = 2 * layout.Row, p = layout.Padding;
        var npc = QuestRuntime.Rules.Npcs[q.Npc];
        Color tone = Tone(status);
        var card = Button(list.Content, new(0, 0, w, h), "", () =>
        {
            selected = q.Id;
            foreach (var b in list.Content.Children.OfType<GUIButton>()) { Paint(b, Equals(b.UserData, selected), Focus); }
            body.BarScroll = 0;
            detailDirty = true;
        });
        card.UserData = q.Id;
        card.ToolTip = Text.Title(q.Id);
        Paint(card, q.Id == selected, Focus);
        int stripe = Math.Max(2, GUI.IntScale(4)), side = Math.Min(h - 2 * p, GUI.IntScale(30));
        Surface(card, new(1, 1, stripe, h - 2), tone);
        QuestStyle.Portrait(card, new(stripe + p, (h - side) / 2, side, side), npc);
        int x = stripe + side + 2 * p, end = w - p, line = (h - 2 * p) / 2;
        string category = Text.Ui(q.Category);
        int badgeW = Math.Min((end - x) / 3, Measure(category) + 2 * p);
        string title = Title(q.Id);
        Label(card, new(x, p, end - x - badgeW - p, line), Fit(title, GUIStyle.Font, end - x - badgeW - p), Ink, GUIStyle.Font);
        Chip(card, new(end - badgeW, p, badgeW, line), category, Sub);
        string stateText = status == QuestStatus.Active
            ? StatusText(status) + " " + q.Objectives.Sum(o => (long)QuestRuntime.State.Progress(q, o)) + "/" + q.Objectives.Sum(o => (long)o.Count)
            : StatusText(status);
        int stateW = Math.Min((end - x) / 2, Measure(stateText) + p);
        Label(card, new(x, p + line, end - x - stateW - p, line), Text.Npc(npc.Id, "name") + " · " + Text.Npc(npc.Id, "faction"), Sub);
        Label(card, new(end - stateW, p + line, stateW, line), stateText, tone, align: Alignment.CenterRight);
    }

    internal void Close()
    {
        RemoveFromGUIUpdateList();
        ClearChildren();
        RectTransform.Parent = null;
    }
}
