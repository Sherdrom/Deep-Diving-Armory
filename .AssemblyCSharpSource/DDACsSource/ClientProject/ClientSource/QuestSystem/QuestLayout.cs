namespace DeepDivingArmory.Quests;

internal readonly record struct Box(int X, int Y, int Width, int Height)
{
    internal int Right => X + Width;
    internal int Bottom => Y + Height;
    internal Box Inset(int n) => new(X + n, Y + n, Math.Max(1, Width - 2 * n), Math.Max(1, Height - 2 * n));
    internal Box Cell(int i, int count, int gap)
    {
        int width = Width - gap * (count - 1);
        int start = i * width / count;
        return new(X + start + i * gap, Y, (i + 1) * width / count - start, Height);
    }
}

internal sealed class QuestLayout
{
    internal readonly Box Left, Right, Publisher, Filters, List, Summary, Header, Body, Actions;
    internal readonly int Gap, Padding, Row;
    internal QuestLayout(int width, int height, float scale)
    {
        int Px(float n) => Math.Max(1, (int)MathF.Round(n * scale));
        Gap = Px(9);
        Padding = Px(7);
        Row = Math.Clamp(Px(33), 12, Math.Max(12, height / 10));
        var area = new Box(0, 0, width, height).Inset(Px(8));
        int left = (area.Width - Gap) / 3;
        Left = new(area.X, area.Y, left, area.Height);
        Right = new(Left.Right + Gap, area.Y, area.Width - left - Gap, area.Height);
        var l = Left.Inset(Padding);
        var r = Right.Inset(Padding);
        Publisher = new(l.X, l.Y, l.Width, Row + Padding);
        Filters = new(l.X, Publisher.Bottom + Padding, l.Width, Row);
        Summary = new(l.X, l.Bottom - Row, l.Width, Row);
        List = new(l.X, Filters.Bottom + Padding, l.Width, Summary.Y - Filters.Bottom - 2 * Padding);
        Actions = new(r.X, r.Bottom - Row, r.Width, Row);
        Header = new(r.X, r.Y, r.Width, Math.Min(Px(95), r.Height / 3));
        Body = new(r.X, Header.Bottom + Padding, r.Width, Actions.Y - Header.Bottom - 2 * Padding);
    }

    internal static int SidebarLimit(int height, int count, int spacing) =>
        Math.Max(1, (height - Math.Max(0, count - 1) * spacing) / Math.Max(1, count));

    internal static (Box Avatar, Box Meta) Sender(int width, int height, int gap)
    {
        int side = Math.Min(height, width / 4);
        return (new(0, 0, side, side), new(side + gap, 0, width - side - gap, height));
    }

    internal static (Box Label, Box Count) Objective(int width, int height, int measured, int gap)
    {
        int count = Math.Min(measured, width / 2);
        return (new(0, 0, width - count - gap, height), new(width - count, 0, count, height));
    }
}
