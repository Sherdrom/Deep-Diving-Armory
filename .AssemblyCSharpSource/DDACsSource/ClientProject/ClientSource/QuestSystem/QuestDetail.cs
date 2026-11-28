using static DeepDivingArmory.Quests.QuestStyle;

namespace DeepDivingArmory.Quests;

internal sealed partial class QuestPanel
{
    private void RefreshDetail()
    {
        header.ClearChildren();
        actions.ClearChildren();
        if (selected == null || !QuestRuntime.Rules.Quests.TryGetValue(selected, out var q))
        {
            body.Content.ClearChildren();
            Label(header, new(layout.Padding, 0, header.Rect.Width - 2 * layout.Padding, header.Rect.Height), Text.Ui("empty"), Sub);
            return;
        }
        var npc = QuestRuntime.Rules.Npcs[q.Npc];
        var status = Status(q);
        Sender(q, npc, status);
        FillScroll(body, () =>
        {
            Description(q, Faction(npc));
            Objectives(q);
            RewardsBlock(q);
        });
        BuildActions(q, status);
    }

    private void Sender(Quest q, Publisher npc, QuestStatus status)
    {
        int p = layout.Padding, w = header.Rect.Width, h = header.Rect.Height;
        // RefreshDetail also removes the decorative fill from the persistent header.
        Surface(header, new(0, 0, w, h), Tile, Edge);
        var (avatar, meta) = QuestLayout.Sender(w - 2 * p, h - 2 * p, p * 2);
        var icon = avatar with { X = p, Y = p };
        QuestStyle.Portrait(header, icon, npc);
        var accent = Faction(npc);
        int tick = Math.Max(2, GUI.IntScale(3));
        Surface(header, new(p, p, icon.Width / 4, tick), accent);
        Surface(header, new(p, p, tick, icon.Height / 4), accent);
        Surface(header, new(icon.Right - icon.Width / 4, icon.Bottom - tick, icon.Width / 4, tick), accent);
        Surface(header, new(icon.Right - tick, icon.Bottom - icon.Height / 4, tick, icon.Height / 4), accent);
        int left = meta.X + p, end = w - p, line = meta.Height / 3;
        string title = Text.Title(q.Id), category = Text.Ui(q.Category), state = StatusText(status);
        int badge = Math.Min(meta.Width / 4, Measure(state) + p * 3);
        int cat = Math.Min(meta.Width / 4, Measure(category) + 2 * p);
        int titleRoom = Math.Max(1, meta.Width - badge - cat - p * 3);
        int titleWidth = Math.Min(titleRoom, Measure(title, GUIStyle.SubHeadingFont) + p);
        Label(header, new(left, p, titleWidth, line), Fit(title, GUIStyle.SubHeadingFont, titleWidth), Ink, GUIStyle.SubHeadingFont);
        Chip(header, new(left + titleWidth + p, p, cat, line), category, accent);
        Chip(header, new(end - badge, p, badge, line), state, Tone(status));
        string name = Text.Npc(npc.Id, "name");
        int nameWidth = Math.Min(meta.Width * 2 / 3, Measure(name, GUIStyle.Font) + p);
        Label(header, new(left, p + line, nameWidth, line), name, Ink, GUIStyle.Font);
        Label(header, new(left + nameWidth, p + line, meta.Width - nameWidth, line), "· " + Text.Npc(npc.Id, "role"), Sub);
        string faction = Text.Npc(npc.Id, "faction"), location = Text.Field(q.Id, "location");
        if (location.Length == 0) { location = Text.Npc(npc.Id, "location"); }
        int y = p + 2 * line, tagH = meta.Height - 2 * line;
        int factionWidth = Math.Min(meta.Width / 2, Measure(faction) + p * 2);
        if (faction.Length > 0) { Chip(header, new(left, y, factionWidth, tagH), faction, accent); left += factionWidth + p; }
        if (location.Length > 0) { Chip(header, new(left, y, Math.Min(end - left, Measure(location) + 2 * p), tagH), location, Sub); }
    }

    private GUIFrame Section(string key, Color accent, out int y, string note = "")
    {
        int p = layout.Padding, w = body.Content.Rect.Width, line = layout.Row;
        var section = Surface(body.Content, new(0, 0, w, line), Panel, Edge, inner: true);
        section.UserData = key;
        int mark = Math.Max(2, GUI.IntScale(3));
        Surface(section, new(p, p, mark, line - p), accent);
        int noteWidth = note.Length == 0 ? 0 : Math.Min(w / 2, Measure(note) + p);
        Label(section, new(2 * p + mark, p / 2, w - 4 * p - noteWidth - mark, line), Text.Ui(key), Ink, GUIStyle.SubHeadingFont);
        if (noteWidth > 0) { Label(section, new(w - p - noteWidth, p / 2, noteWidth, line), note, accent, align: Alignment.CenterRight); }
        Surface(section, new(p, line + p, w - 2 * p, 1), Edge);
        y = line + 2 * p;
        return section;
    }

    private static void Finish(GUIFrame frame, int height) =>
        frame.RectTransform.Resize(new Point(frame.Rect.Width, height), resizeChildren: true);

    private int Paragraph(GUIComponent parent, int x, int y, int width, string value, Color color, GUIFont font)
    {
        var text = Label(parent, new(x, y, width, layout.Row), value, color, font, wrap: true);
        text.CalculateHeightFromText();
        return Math.Max(layout.Row * 2 / 3, text.Rect.Height);
    }

    private void Description(Quest q, Color accent)
    {
        var block = Section("description", accent, out int y);
        int p = layout.Padding, width = block.Rect.Width - 2 * p;
        string desc = Text.Field(q.Id, "desc"), quote = Text.Field(q.Id, "quote");
        if (desc.Length > 0) { y += Paragraph(block, p, y, width, desc, Ink, GUIStyle.Font); }
        if (!string.IsNullOrWhiteSpace(quote))
        {
            y += p;
            var box = Surface(block, new(p, y, width, 1), Tile);
            box.UserData = "quote";
            int height = Paragraph(box, 2 * p, p, width - 3 * p, quote, Sub, GUIStyle.SmallFont) + 2 * p;
            Finish(box, height);
            Surface(box, new(0, 0, Math.Max(2, p / 2), height), accent);
            y += height;
        }
        Finish(block, y + p);
    }

    private static void DrawItemIcon(GUIComponent cell, ItemPrefab? prefab)
    {
        if ((prefab?.InventoryIcon ?? prefab?.Sprite) is { } icon)
        {
            new GUIImage(new RectTransform(new Vector2(.83f), cell.RectTransform, Anchor.Center), icon, scaleToFit: true)
                { CanBeFocused = false, Color = prefab!.InventoryIcon != null ? prefab.InventoryIconColor : prefab.SpriteColor };
        }
    }

    private void Objectives(Quest q)
    {
        int[] current = q.Objectives.Select(o => QuestRuntime.State.Progress(q, o)).ToArray();
        int done = q.Objectives.Where((o, i) => current[i] >= o.Count).Count();
        string[] numbers = q.Objectives.Select((o, i) => current[i] + " / " + o.Count).ToArray();
        var block = Section("objectives", Cyan, out int y, Text.Ui("achieved") + "  " + done + " / " + current.Length);
        int p = layout.Padding, width = block.Rect.Width - 2 * p, check = Math.Max(8, GUI.IntScale(17));
        int slot = Math.Max(1, Math.Min(width / 3, GUI.IntScale(48)));
        int itemLine = Math.Max(12, layout.Row * 3 / 4);
        bool isActive = QuestRuntime.State.Active.ContainsKey(q.Id);
        var (_, count) = QuestLayout.Objective(width, layout.Row, numbers.Max(s => Measure(s)) + 2 * p, p);
        for (int i = 0; i < q.Objectives.Length; i++)
        {
            var o = q.Objectives[i];
            bool complete = current[i] >= o.Count;
            bool delivery = o.Type == ObjectiveType.DeliverItem;
            bool handIn = delivery && isActive;
            Color color = complete ? Green : Cyan;
            var row = Surface(block, new(p, y, width, 1), Tile, Edge);
            row.UserData = o.Id;
            int left = check + 3 * p;
            int nameW = Math.Max(1, count.X - left - p);
            int textH = Paragraph(row, left, p, nameW, Text.Objective(q, o), Ink, GUIStyle.Font);
            int topH = Math.Max(check, textH) + 2 * p + (!delivery && o.Count > 1 ? p : 0);
            int height = topH;
            if (delivery)
            {
                var prefab = ItemPrefab.FindByIdentifier(o.Target.ToIdentifier()) as ItemPrefab;
                string itemName = prefab?.Name.Value ?? o.Target, itemDesc = prefab?.Description.Value ?? "";
                int stock = QuestRuntime.State.Stock.GetValueOrDefault(o.Target);
                string caption = handIn ? Text.Ui(complete ? "handedin" : "handin") : "";
                string stockText = handIn && !complete ? Text.Ui("stock").Replace("[count]", stock.ToString()) : "";
                int buttonW = handIn ? Math.Min(width / 4, Math.Max(GUI.IntScale(88),
                    Math.Max(Measure(caption, GUIStyle.Font), Measure(stockText)) + 4 * p)) : 0;
                int itemY = topH;
                int infoX = p + slot + p, infoW = Math.Max(1, width - infoX - p - (handIn ? buttonW + p : 0));
                var info = Surface(row, new(infoX, itemY, infoW, slot), Panel, Edge);
                info.UserData = "iteminfo";
                int textPad = Math.Max(2, p / 2);
                Label(info, new(p, textPad, Math.Max(1, infoW - 2 * p), itemLine), itemName + " ×" + o.Count, Ink, GUIStyle.Font);
                int descY = textPad + itemLine, descH = 0;
                GUITextBlock? descText = null;
                if (itemDesc.Length > 0)
                {
                    descText = Label(info, new(p, descY, Math.Max(1, infoW - 2 * p), Math.Max(1, slot - descY)), itemDesc, Sub, wrap: true);
                    descText.CalculateHeightFromText();
                    descH = descText.Rect.Height;
                }
                int barH = Math.Max(3, p / 2);
                int contentBottom = descY + descH + (o.Count > 1 ? p + barH + p : p);
                int itemH = Math.Max(slot, contentBottom);
                Finish(info, itemH);
                descText?.RectTransform.Resize(new Point(Math.Max(1, infoW - 2 * p), Math.Max(1, descH)));
                if (o.Count > 1)
                {
                    Meter(info, new(p, itemH - p - barH, Math.Max(1, infoW - 2 * p), barH), (float)current[i] / o.Count, color);
                }
                var itemSlot = Surface(row, new(p, itemY + (itemH - slot) / 2, slot, slot), Deep, Color.Lerp(Edge, color, .55f));
                itemSlot.UserData = "itemslot";
                itemSlot.CanBeFocused = true;
                itemSlot.ToolTip = itemDesc.Length > 0 ? itemName + "\n" + itemDesc : itemName;
                DrawItemIcon(itemSlot, prefab);
                if (handIn)
                {
                    var button = Button(row, new(width - p - buttonW, itemY, buttonW, itemH), caption,
                        () => QuestRuntime.Request(QuestAction.Deliver, q.Id, speaker, preview, o.Id));
                    bool inPlace = q.Remote || publisher?.Id == q.Npc;
                    button.Enabled = !complete && inPlace && stock > 0 && canAct;
                    Paint(button, false, button.Enabled ? Green : Dim, button.Enabled);
                    if (!complete)
                    {
                        button.TextBlock.RectTransform.Pivot = Pivot.TopCenter;
                        button.TextBlock.RectTransform.Anchor = Anchor.TopCenter;
                        button.TextBlock.RectTransform.RelativeSize = new Vector2(1f, .54f);
                        button.TextBlock.RectTransform.AbsoluteOffset = new Point(0, Math.Max(1, p / 2));
                        Label(button, new(p / 2, itemH / 2, Math.Max(1, buttonW - p), Math.Max(1, itemH - itemH / 2 - p / 2)),
                            stockText, button.Enabled ? Color.Lerp(Green, Ink, .45f) : Dim, align: Alignment.Center);
                    }
                    button.ToolTip = complete ? caption : !inPlace ? Visit(q) : preview && GameMain.IsMultiplayer ? Text.Ui("preview") :
                        stock == 0 ? Text.Ui("nostock") : Text.Ui("handinstock").Replace("[count]", stock.ToString());
                }
                height = itemY + itemH + p;
            }
            Finish(row, height);
            var square = Surface(row, new(p, (topH - check) / 2, check, check), complete ? Tint(Green) : Deep, color);
            if (complete) { Label(square, new(0, 0, check, check), "✓", Green, align: Alignment.Center); }
            if (!delivery && o.Count > 1) { Meter(row, new(left, topH - p, nameW, Math.Max(2, p / 2)), (float)current[i] / o.Count, color); }
            Label(row, new(count.X, 0, Math.Max(1, count.Width - p), topH), numbers[i], color, align: Alignment.CenterRight).UserData = "count";
            y += height + p;
        }
        var state = QuestRuntime.State;
        var tags = new List<(string, Color)>();
        void Gate(string value, bool met) => tags.Add(((met ? "✓ " : "✕ ") + value, met ? Green : Red));
        foreach (string id in q.Requires) { Gate(Text.Ui("requires") + " · " + Text.Title(id), state.Completed.Contains(id)); }
        foreach (var t in q.Trust) { Gate(Text.Npc(t.Npc, "name") + " · " + Text.Ui("trust") + " ≥ " + t.Count, state.Trust.GetValueOrDefault(t.Npc) >= t.Count); }
        if (q.Repeatable) { tags.Add(("✓ " + Text.Ui("canrepeat"), Cyan)); }
        tags.Add((q.Remote ? "✓ " + Text.Ui("remote") : "! " + Text.Ui("inperson"), q.Remote ? Green : Amber));
        Finish(block, Chips(block, y, tags) + p);
    }

    private int Chips(GUIComponent parent, int y, List<(string Value, Color Accent)> tags)
    {
        int p = layout.Padding, x = p, end = parent.Rect.Width - p, height = Math.Max(12, layout.Row * 3 / 4);
        foreach (var (value, color) in tags)
        {
            int width = Math.Min(end - p, Measure(value) + 3 * p);
            if (x != p && x + width > end) { x = p; y += height + p; }
            Chip(parent, new(x, y, width, height), value, color);
            x += width + p;
        }
        return tags.Count == 0 ? y : y + height;
    }

    private static void DrawFlag(GUIComponent box, int size, Color color)
    {
        int poleW = Math.Max(2, size / 13), poleH = Math.Max(8, size * 56 / 100);
        int x = size * 28 / 100, y = (size - poleH) / 2;
        int clothH = Math.Max(4, poleH * 52 / 100), drop = Math.Max(1, clothH / 4);
        int leftW = Math.Max(3, size * 24 / 100), rightW = Math.Max(3, size * 22 / 100);
        Surface(box, new(x, y, poleW, poleH), color);
        Surface(box, new(x + poleW, y, leftW, clothH), color);
        Surface(box, new(x + poleW + leftW - 1, y + drop, rightW, clothH), color);
    }

    private static string FactionName(string id, Publisher npc)
    {
        var custom = TextManager.Get("dda.quest.faction." + id);
        if (custom.Loaded) { return custom.Value; }
        if (FactionPrefab.Prefabs.TryGet(id, out var prefab) && prefab != null) { return prefab.Name.Value; }
        string fallback = id.Equals(npc.Faction, StringComparison.OrdinalIgnoreCase) ? Text.Npc(npc.Id, "faction") : "";
        return TextManager.Get("faction." + id).Fallback(fallback.Length > 0 ? fallback : id).Value;
    }

    private readonly record struct RewardCard(string Kind, string Title, string Value, string Subtitle,
        string Badge, Color Accent, Color Fill, ItemPrefab? Prefab, string ToolTip);

    private void RewardsBlock(Quest q)
    {
        var block = Section("rewards", Amber, out int y);
        var npc = QuestRuntime.Rules.Npcs[q.Npc];
        int p = layout.Padding, width = block.Rect.Width - 2 * p;
        int mark = Math.Max(2, GUI.IntScale(3));
        var cards = new List<RewardCard>();
        if (q.Rewards.Marks > 0)
        {
            string title = Text.Ui("marks"), sub = Text.Ui("marksdesc");
            cards.Add(new("rewardstat", title, "+" + q.Rewards.Marks, sub, "mk", Amber, Tile, null, title + " +" + q.Rewards.Marks + "\n" + sub));
        }
        foreach (var item in q.Rewards.Items)
        {
            var prefab = ItemPrefab.FindByIdentifier(item.Id.ToIdentifier()) as ItemPrefab;
            string name = prefab?.Name.Value ?? item.Id, desc = prefab?.Description.Value ?? "";
            string title = name + " ×" + item.Count;
            cards.Add(new("rewarditem", title, "", desc, "", Amber, Tile, prefab, desc.Length > 0 ? title + "\n" + desc : title));
        }
        if (q.Rewards.Trust > 0)
        {
            string title = Text.Ui("trust");
            string npcName = Text.Npc(npc.Id, "name"), npcLoc = Text.Npc(npc.Id, "location");
            string sub = npcLoc.Length > 0 ? npcName + " · " + npcLoc : npcName;
            cards.Add(new("rewardstat", title, "+" + q.Rewards.Trust, sub, "★", Cyan, Tile, null, title + " +" + q.Rewards.Trust + "\n" + sub));
        }
        foreach (var (id, amount) in q.Rewards.Reputation)
        {
            string title = Text.Ui("reputation"), value = amount > 0 ? "+" + amount : amount.ToString();
            string sub = FactionName(id, npc);
            cards.Add(new("rewardstat", title, value, sub, "flag", amount > 0 ? Green : Red, Tile, null, title + " " + value + "\n" + sub));
        }
        foreach (string id in q.Rewards.Unlock)
        {
            string title = Text.Title(id), tag = Text.Ui("unlockchain"), sub = Text.Ui("unlockdesc");
            cards.Add(new("rewardunlock", title, tag, sub, "››", Copper, Color.Lerp(Tile, Copper, .06f), null, tag + " · " + title + "\n" + sub));
        }
        int iconBox = Math.Max(1, Math.Min(width / 8, GUI.IntScale(38)));
        int line = Math.Max(12, layout.Row * 2 / 3);
        int textPad = Math.Max(3, p / 2);
        int cardH = Math.Max(iconBox + 2 * p, textPad * 2 + line * 2);
        for (int i = 0; i < cards.Count;)
        {
            bool spanTwo = i + 1 == cards.Count;
            int rowCount = spanTwo ? 1 : 2;
            var rowBox = new Box(p, y, width, cardH);
            for (int col = 0; col < rowCount; col++)
            {
                var card = cards[i + col];
                var cell = rowBox.Cell(col, rowCount, p);
                var frame = Surface(block, cell, card.Fill, Edge);
                frame.UserData = card.Kind;
                frame.CanBeFocused = true;
                frame.ToolTip = card.ToolTip;
                Surface(frame, new(0, 0, mark, cardH), card.Accent);
                var box = Surface(frame, new(mark + p, (cardH - iconBox) / 2, iconBox, iconBox), Deep, Color.Lerp(Edge, card.Accent, .55f));
                box.UserData = "itemslot";
                if (card.Prefab != null) { DrawItemIcon(box, card.Prefab); }
                else if (card.Badge == "flag") { DrawFlag(box, iconBox, card.Accent); }
                else if (card.Badge.Length > 0) { Label(box, new(0, 0, iconBox, iconBox), card.Badge, card.Accent, GUIStyle.Font, Alignment.Center); }
                int metaX = mark + p + iconBox + p, metaW = Math.Max(1, cell.Width - metaX - p);
                bool unlock = card.Kind == "rewardunlock";
                Color titleColor = unlock ? Color.Lerp(Copper, Ink, .45f) : Ink;
                if (card.Value.Length > 0)
                {
                    var valFont = unlock ? GUIStyle.SmallFont : GUIStyle.Font;
                    int valW = Math.Min(metaW / 2, Measure(card.Value, valFont) + p);
                    int titleW = Math.Max(1, metaW - valW - p);
                    Label(frame, new(metaX, textPad, titleW, line), Fit(card.Title, GUIStyle.Font, titleW), titleColor, GUIStyle.Font);
                    Label(frame, new(metaX + metaW - valW, textPad, valW, line), card.Value, card.Accent, valFont, Alignment.CenterRight);
                }
                else
                {
                    Label(frame, new(metaX, textPad, metaW, line), Fit(card.Title, GUIStyle.Font, metaW), titleColor, GUIStyle.Font);
                }
                if (card.Subtitle.Length > 0)
                {
                    int subY = textPad + line;
                    Label(frame, new(metaX, subY, metaW, Math.Max(1, cardH - subY - textPad)), Fit(card.Subtitle, GUIStyle.SmallFont, metaW), Sub);
                }
            }
            i += rowCount;
            y += cardH + p;
        }
        Finish(block, y);
    }

    private static string Visit(Quest q) => Text.Ui("visit").Replace("[npc]", Text.Npc(q.Npc, "name"));

    private void BuildActions(Quest q, QuestStatus status)
    {
        bool active = status is QuestStatus.Active or QuestStatus.Ready;
        bool atNpc = publisher != null || (QuestRuntime.DebugBypass && GameMain.IsSingleplayer);
        var buttons = new List<(string Label, Action Run, Color Accent, bool Primary, bool Enabled)>();
        void Command(string key, QuestAction op, Color color, bool primary, bool enabled = true) =>
            buttons.Add((Text.Ui(key), () => QuestRuntime.Request(op, q.Id, speaker, preview), color, primary, enabled && canAct));
        if (atNpc && status == QuestStatus.Available) { Command("accept", QuestAction.Accept, Amber, true); }
        if (active)
        {
            if (atNpc || q.Remote) { Command("submit", QuestAction.Submit, Green, true, status == QuestStatus.Ready); }
            bool tracked = QuestRuntime.Tracked == q.Id;
            buttons.Add((Text.Ui(tracked ? "untrack" : "track"), () => { QuestRuntime.Tracked = tracked ? null : q.Id; listDirty = true; }, Cyan, tracked, true));
            Command("abandon", QuestAction.Abandon, Red, false);
        }
        string hint = !atNpc && (status == QuestStatus.Available || active && !q.Remote)
            ? Visit(q) : StatusText(status);
        if (atNpc && preview && GameMain.IsMultiplayer) { hint = Text.Ui("preview"); }
        if (QuestRuntime.Round.Length == 0) { hint = Text.Ui("campaign"); }
        int width = actions.Rect.Width, h = actions.Rect.Height, p = layout.Padding;
        int used = Math.Min(width * 2 / 3, (GUI.IntScale(86) + p) * buttons.Count);
        Label(actions, new(0, 0, Math.Max(1, width - used - p), h), hint, Tone(status));
        var area = new Box(width - used, 0, used, h);
        for (int i = 0; i < buttons.Count; i++)
        {
            var action = buttons[i];
            var b = Button(actions, area.Cell(i, buttons.Count, p), action.Label, action.Run);
            Paint(b, false, action.Accent, action.Primary);
            b.OutlineColor = !action.Enabled ? Edge : action.Primary ? action.Accent : Color.Lerp(Edge, action.Accent, .50f);
            b.TextColor = action.Primary ? action.Accent : Color.Lerp(Ink, action.Accent, .55f);
            b.Enabled = action.Enabled;
        }
    }
}
