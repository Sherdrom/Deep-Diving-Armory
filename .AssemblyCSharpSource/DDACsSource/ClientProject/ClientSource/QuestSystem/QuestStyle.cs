namespace DeepDivingArmory.Quests;

internal static class QuestStyle
{
    internal static readonly Color Deep = new(10, 15, 13), Panel = new(17, 24, 21), Tile = new(23, 33, 28),
        Hover = new(32, 46, 39), Selected = new(30, 48, 40), Edge = new(48, 66, 57), Focus = new(94, 142, 121),
        Ink = new(218, 229, 222), Sub = new(148, 168, 157), Dim = new(108, 127, 117),
        Amber = new(217, 169, 92), Cyan = new(114, 184, 170), Green = new(120, 194, 138),
        Red = new(201, 111, 103), Copper = new(207, 134, 97);

    internal static Color Tint(Color color) => Color.Lerp(Tile, color, .18f);
    internal static Color Tone(QuestStatus state) => state switch
    {
        QuestStatus.Ready => Green, QuestStatus.Active => Cyan, QuestStatus.Available => Amber, _ => Dim
    };
    internal static Color Faction(Publisher npc) => npc.Color.Length > 0 ? XMLExtensions.ParseColor(npc.Color) : Cyan;
    internal static int Measure(string text, GUIFont? font = null) => (int)Math.Ceiling((font ?? GUIStyle.SmallFont).MeasureString(text).X);
    internal static RectTransform At(GUIComponent parent, Box b) => new(new Point(Math.Max(1, b.Width), Math.Max(1, b.Height)),
        parent.RectTransform, isFixedSize: true) { AbsoluteOffset = new Point(b.X, b.Y) };
    internal static GUIFrame Surface(GUIComponent parent, Box box, Color fill, Color edge = default, bool inner = false)
    {
        var frame = new GUIFrame(At(parent, box), style: inner ? "InnerFrame" : null)
            { Color = fill, HoverColor = fill, SelectedColor = fill, PressedColor = fill, OutlineColor = edge, OutlineThickness = 1, CanBeFocused = false };
        if (inner)
        {
            new GUIFrame(new RectTransform(Vector2.One, frame.RectTransform), style: null)
                { Color = fill, HoverColor = fill, SelectedColor = fill, PressedColor = fill, OutlineColor = edge, OutlineThickness = 1, CanBeFocused = false };
        }
        return frame;
    }
    internal static GUITextBlock Label(GUIComponent parent, Box box, string value, Color color, GUIFont? font = null,
        Alignment align = Alignment.CenterLeft, bool wrap = false) =>
        new(At(parent, box), value, textColor: color, font: font ?? GUIStyle.SmallFont, textAlignment: align, wrap: wrap, style: null)
        { CanBeFocused = false, Padding = Vector4.Zero, AutoScaleHorizontal = !wrap,
            Color = Color.Transparent, SelectedColor = Color.Transparent, HoverColor = Color.Transparent, PressedColor = Color.Transparent };

    internal static GUIButton Button(GUIComponent parent, Box box, string value, Action click)
    {
        var b = new GUIButton(At(parent, box), value, style: null)
        {
            TextColor = Ink, HoverTextColor = Ink, SelectedTextColor = Ink,
            TextBlock = { AutoScaleHorizontal = true, Padding = Vector4.Zero, CanBeFocused = false },
            OnClicked = (_, _) => { click(); return true; }
        };
        b.Frame.DisabledColor = Tile;
        b.TextBlock.DisabledTextColor = Dim;
        Paint(b, false, Focus);
        return b;
    }
    internal static void Paint(GUIButton b, bool selected, Color accent, bool emphasize = false)
    {
        b.Selected = selected;
        b.Color = emphasize ? Tint(accent) : Tile;
        b.HoverColor = Color.Lerp(Hover, accent, .24f);
        b.SelectedColor = Color.Lerp(Selected, accent, .18f);
        b.PressedColor = b.SelectedColor;
        b.OutlineThickness = 1;
        b.Frame.OutlineThickness = 1;
        b.OutlineColor = selected || emphasize ? accent : Edge;
    }
    internal static GUITextBlock Chip(GUIComponent parent, Box box, string value, Color accent)
    {
        var bg = Surface(parent, box, Tint(accent), Color.Lerp(Edge, accent, .55f));
        return Label(bg, new(1, 0, box.Width - 2, box.Height), value, accent, align: Alignment.Center);
    }
    internal static void Portrait(GUIComponent parent, Box box, Publisher npc)
    {
        var frame = Surface(parent, box, Deep, Edge);
        if (QuestRuntime.Portrait(npc) is { } sprite)
        {
            new GUIImage(new RectTransform(new Vector2(.92f), frame.RectTransform, Anchor.Center), sprite, scaleToFit: true)
                { CanBeFocused = false };
        }
    }
    internal static void Meter(GUIComponent parent, Box box, float fraction, Color color)
    {
        Surface(parent, box, Edge);
        int width = (int)Math.Round(box.Width * Math.Clamp(fraction, 0, 1));
        if (width > 0) { Surface(parent, box with { Width = width }, color); }
    }
}

internal sealed class QuestDialogueHeader : GUIFrame
{
    private readonly Publisher? npc;
    private readonly Action close;
    private Point size;
    private int trust = -1;
    internal QuestDialogueHeader(RectTransform rect, Publisher? npc, Action close) : base(rect, style: null)
    {
        this.npc = npc;
        this.close = close;
        Color = QuestStyle.Panel;
        Refresh();
    }
    public override void AddToGUIUpdateList(bool ignoreChildren = false, int order = 0)
    {
        Refresh();
        base.AddToGUIUpdateList(ignoreChildren, order);
    }
    private void Refresh()
    {
        int value = npc == null ? 0 : QuestRuntime.State.Trust.GetValueOrDefault(npc.Id);
        if (size == Rect.Size && trust == value) { return; }
        size = Rect.Size;
        trust = value;
        ClearChildren();
        var t = QuestPanel.Text;
        int p = Math.Max(2, GUI.IntScale(9)), h = size.Y - 2 * p, width = size.X - p * 2;
        int closeWidth = Math.Min(width / 5, GUI.IntScale(82));
        QuestStyle.Button(this, new(size.X - p - closeWidth, p, closeWidth, h), t.Ui("close"), close);
        int end = size.X - closeWidth - 2 * p;
        if (npc != null)
        {
            int infoWidth = Math.Min(end / 2, GUI.IntScale(380)), left = end - infoWidth;
            int half = infoWidth / 2;
            QuestStyle.Label(this, new(left, p, half - p, h), t.Npc(npc.Id, "location"), QuestStyle.Sub, align: Alignment.CenterRight);
            QuestStyle.Label(this, new(left + half, p, half, h - p), t.Ui("trust") + "  " + trust, QuestStyle.Cyan);
            int threshold = QuestRuntime.Rules.Quests.Values.SelectMany(q => q.Trust)
                .Where(r => r.Npc == npc.Id && r.Count > trust).Select(r => r.Count).DefaultIfEmpty(Math.Max(1, trust)).Min();
            QuestStyle.Meter(this, new(left + half, p + h - Math.Max(2, p / 2), half, Math.Max(2, p / 2)), (float)trust / threshold, QuestStyle.Cyan);
            end = left - p;
        }
        QuestStyle.Label(this, new(p, p, end - p, h), npc == null ? t.Ui("tab") : t.Npc(npc.Id, "name"), QuestStyle.Ink, GUIStyle.SubHeadingFont);
        QuestStyle.Surface(this, new(0, size.Y - 1, size.X, 1), QuestStyle.Focus);
    }
}
