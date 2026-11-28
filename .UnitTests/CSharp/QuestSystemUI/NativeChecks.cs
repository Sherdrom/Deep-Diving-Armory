using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using System.Xml.Linq;
using Barotrauma;
using Microsoft.Xna.Framework;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

internal static class NativeChecks
{
    // --native <game directory> <mod directory>. Run with the game's architecture.
    internal static void Run(string[] args)
    {
        if (args.Length != 3 || args[0] != "--native") { throw new ArgumentException("--native <game directory> <mod directory>"); }
        string game = Path.GetFullPath(args[1]), mod = Path.GetFullPath(args[2]);
        string platform = OperatingSystem.IsMacOS() ? "Mac" : OperatingSystem.IsWindows() ? "Windows" : "Linux";
        AssemblyLoadContext.Default.Resolving += (ctx, name) =>
        {
            string path = Path.Combine(game, name.Name + ".dll");
            if (!File.Exists(path)) { path = Path.Combine(mod, ".Tools/Refs", name.Name + ".dll"); }
            if (name.Name == "VanillaComponentsExpandedClient")
            { path = Path.Combine(mod, "../Vanilla-Components-Expanded/bin", platform, "Client", name.Name + ".dll"); }
            return File.Exists(path) ? ctx.LoadFromAssemblyPath(Path.GetFullPath(path)) : null;
        };
        Verify(Assembly.LoadFrom(Path.Combine(mod, "bin", platform, "Client", "Deep-Diving-ArmoryClient.dll")),
            Assembly.LoadFrom(Path.Combine(mod, "bin", platform, "Server", "Deep-Diving-ArmoryServer.dll")), mod);
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static void Verify(Assembly plugin, Assembly server, string mod)
    {
        const BindingFlags flags = BindingFlags.Static | BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        Type Module(string name) => plugin.GetType("DeepDivingArmory.Quests." + name, true)!;
        var runtime = Module("QuestRuntime");
        void Call(string method, params object?[] values) => runtime.GetMethod(method, flags)!.Invoke(null, values);
        void Check(bool ok, string message) { if (!ok) { throw new Exception(message); } }
        object? Field(object target, string key) => target.GetType().GetField(key, flags)!.GetValue(target);

        var metadata = new CampaignMetadata();
        var key = "dda.quest.state".ToIdentifier();
        var state = new DeepDivingArmory.Quests.QuestState();
        state.Active["gunsmith_plastic_test"] = new() { ["plastic"] = 2 };
        state.Stock["engineeringplastic"] = 4;
        state.Active["co_pirate_bounty"] = new() { ["pirates"] = 2 };
        state.Trust["benzene"] = 5;
        metadata.SetValue(key, state.Write());
        var xml = new XElement("campaign");
        metadata.Save(xml);
        var reloaded = new CampaignMetadata();
        reloaded.Load(XElement.Parse(xml.ToString()).Element("Metadata")!);
        Check(DeepDivingArmory.Quests.QuestState.Read(reloaded.GetString(key)).Write() == state.Write(), "native CampaignMetadata Save/Load");

        static Type MessageType(Type contract) => contract.Assembly.GetType("Barotrauma.Networking.ReadWriteMessage", true)!;
        void Packet(Assembly sender, Assembly receiver, string name, params object[] fields)
        {
            var outgoing = sender.GetType("DeepDivingArmory.Quests." + name, true)!;
            var incoming = receiver.GetType(outgoing.FullName!, true)!;
            var writer = outgoing.GetInterfaces().Single(t => t.Name == nameof(INetSerializableStruct));
            var reader = incoming.GetInterfaces().Single(t => t.Name == nameof(INetSerializableStruct));
            object buffer = Activator.CreateInstance(MessageType(writer))!;
            writer.GetMethod("Write")!.Invoke(Activator.CreateInstance(outgoing, fields), [buffer]);
            var bytes = (byte[])buffer.GetType().GetProperty("Buffer")!.GetValue(buffer)!;
            var bits = (int)buffer.GetType().GetProperty("LengthBits")!.GetValue(buffer)!;
            object payload = Activator.CreateInstance(MessageType(reader), bytes, 0, bits, true)!;
            var decoded = reader.GetMethod("Read")!.MakeGenericMethod(incoming).Invoke(null, [payload]);
            Check(Equals(Activator.CreateInstance(incoming, fields), decoded), "cross-end packet " + name);
        }
        Packet(plugin, server, "QuestRequest", (byte)DeepDivingArmory.Quests.QuestAction.Deliver, "gunsmith_plastic_test", (ushort)42, "test-round", 18, "plastic");
        Packet(server, plugin, "QuestSnapshot", "test-round", 18, state.Write(true), true);
        Console.WriteLine("PASS deployed client-to-server request, server-to-client snapshot and CampaignMetadata persistence");

        NativeSettlement.Verify(server);

        var filelist = Path.Combine(mod, "filelist.xml");
        var manifest = XDocument.Load(filelist);
        manifest.Root!.Elements().Where(e => e.Name != "Text" || !((string)e.Attribute("file")!).EndsWith("Quests.xml")).Remove();
        var package = new RegularPackage(manifest, filelist);
        var files = package.Files.OfType<TextFile>().ToArray();
        Check(files.Length == 2, "registered text packs");
        var cfg = GameSettings.CurrentConfig;
        cfg.Language = TextManager.DefaultLanguage;
        cfg.Graphics.HUDScale = 1;
        typeof(GameSettings).GetField("currentConfig", flags)!.SetValue(null, cfg);
        foreach (var file in files) { file.LoadFile(); }
        Check(TextManager.Get("dda.quest.gunsmith_plastic_test.title").Value == "Watertight Polymer", "native TextManager English");
        cfg.Language = "Simplified Chinese".ToLanguageIdentifier();
        typeof(GameSettings).GetField("currentConfig", flags)!.SetValue(null, cfg);
        TextManager.IncrementLanguageVersion();
        Check(TextManager.Get("dda.quest.gunsmith_plastic_test.title").Value == "水密工程塑料", "native TextManager Chinese");
        Console.WriteLine("PASS both registered native TextManager packs");

        GameMain.GraphicsWidth = 1920;
        GameMain.GraphicsHeight = 1080;
        GUIStyle.ComponentStyles.Add(new GUIComponentStyle(new ContentXElement(null,
            XElement.Parse("<GUIScrollBar><GUIFrameVertical/><GUIButtonVertical/></GUIScrollBar>")), null), false);
        var config = Path.Combine(mod, "Quests");
        var questFiles = Directory.EnumerateFiles(config, "quests_*.xml")
            .OrderBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase)
            .Select(p => XElement.Load(p, LoadOptions.SetBaseUri)).ToArray();
        var gunsmith = questFiles.SelectMany(f => f.Elements("Quest")).First(e => (string?)e.Attribute("id") == "gunsmith_plastic_test");
        gunsmith.Element("Rewards")!.Add(
            new XElement("Reputation", new XAttribute("faction", "coalition"), new XAttribute("amount", 1)),
            new XElement("Item", new XAttribute("id", "steel"), new XAttribute("count", 7)));
        gunsmith.Element("Objectives")!.Add(new XElement("Custom", new XAttribute("id", "relay"), new XAttribute("target", "relay")));
        var tideGauge = questFiles.SelectMany(f => f.Elements("Quest")).First(q => (string?)q.Attribute("id") == "dda_tide_gauge");
        tideGauge.Element("Objectives")!.Add(
            Enumerable.Range(1, 23).Select(i => new XElement("ReachLocation", new XAttribute("id", "port" + i), new XAttribute("target", "city"))));
        object rules = Module("QuestRules").GetMethod("Parse", flags)!.Invoke(null, [XElement.Load(Path.Combine(config, "npcs.xml")), questFiles])!;
        runtime.GetProperty("Rules", flags)!.SetValue(null, rules);
        var portraits = (IDictionary)runtime.GetField("portraits", flags)!.GetValue(null)!;
        // This host exercises native geometry and hit targets without opening a graphics device.
        void StubPortraits()
        {
            foreach (string id in new[] { "peachhat", "benzene", "sterling", "natalia", "harland", "liaison" }) { portraits[id] = null; }
        }
        StubPortraits();
        var npcs = (IDictionary)Field(rules, "Npcs")!;
        foreach (var dims in new[] { new Point(72, 470), new Point(145, 395), new Point(100, 650) })
        {
            var parent = new GUIFrame(new RectTransform(dims), style: null);
            var bar = new GUILayoutGroup(new RectTransform(Vector2.One, parent.RectTransform)) { AbsoluteSpacing = 5 };
            var originals = Enumerable.Range(0, 5).Select(_ => new GUIButton(new RectTransform(Vector2.One, bar.RectTransform,
                scaleBasis: ScaleBasis.BothWidth), style: null)).ToArray();
            bar.Recalculate();
            var max = bar.RectTransform.MaxSize;
            int natural = originals[0].Rect.Width;
            bool clicked = false;
            Call("AttachSidebar", bar, true, (Action)(() => clicked = true), null);
            bar.Recalculate();
            var icons = bar.Children.OfType<GUIButton>().ToArray();
            Check(icons.Length == 6 && icons.All(b => b.Rect.Width == b.Rect.Height && b.Rect.Width == icons[0].Rect.Width && bar.Rect.Contains(b.Rect))
                && icons.Zip(icons.Skip(1)).All(pair => pair.First.Rect.Bottom <= pair.Second.Rect.Top), "six native sidebar buttons fit");
            var added = icons[^1];
            added.OnClicked(added, added.UserData);
            Check(clicked && added.Selected && added.ToolTip.SanitizedString.Value.Contains("NPC"), "native side tab activated");
            var badge = (GUIFrame)runtime.GetField("readyBadge", flags)!.GetValue(null)!;
            Check(!badge.Visible, "zero ready hides badge");
            var ready = new DeepDivingArmory.Quests.QuestState();
            ready.Active["gunsmith_plastic_test"] = new() { ["relay"] = 1, ["plastic"] = 4 };
            ready.Stock["engineeringplastic"] = 4;
            var snapshot = Module("QuestState").GetMethod("Read", flags)!.Invoke(null, [ready.Write(true)]);
            runtime.GetProperty("State", flags)!.SetValue(null, snapshot);
            runtime.GetProperty("Revision", flags)!.SetValue(null, 1);
            Call("RefreshSidebar", added);
            Check(badge.Visible && badge.GetChild<GUITextBlock>().Text.SanitizedString.Value == "1" &&
                added.Rect.Contains(badge.Rect) && badge.Rect.Right == added.Rect.Right, "ready count in button corner");
            var empty = Module("QuestState").GetMethod("Read", flags)!.Invoke(null, [""]);
            runtime.GetProperty("State", flags)!.SetValue(null, empty);
            runtime.GetProperty("Revision", flags)!.SetValue(null, 2);
            Call("RefreshSidebar", added);
            Check(!badge.Visible, "badge hides after turn-in");
            Call("ClearRound");
            bar.Recalculate();
            Check(bar.Children.SequenceEqual(originals) && originals[0].Rect.Width == natural && bar.RectTransform.MaxSize == max &&
                added.OnClicked == null && runtime.GetField("sidebar", flags)!.GetValue(null) == null, "release restores original five and sidebar bounds");
        }
        StubPortraits();
        foreach (var dimensions in new[] { new Point(680, 400), new Point(1152, 680), new Point(1680, 960) })
        {
            var host = new GUIFrame(new RectTransform(dimensions), style: null);
            foreach (string? npc in new string?[] { null, "benzene", "peachhat" })
            {
                var panelType = Module("QuestPanel");
                var panel = Activator.CreateInstance(panelType, flags, null, [host, npc == null ? null : npcs[npc], (ushort)0, true], null)!;
                var list = (GUIListBox)Field(panel, "list")!;
                var body = (GUIListBox)Field(panel, "body")!;
                var summary = (GUITextBlock)Field(panel, "summary")!;
                var actions = (GUIFrame)Field(panel, "actions")!;
                var filters = (GUIButton[])Field(panel, "filters")!;
                var header = (GUIFrame)Field(panel, "header")!;
                var sections = body.Content.Children.OfType<GUIFrame>().ToArray();
                Check(sections.Select(b => b.UserData).SequenceEqual(new[] { "description", "objectives", "rewards" }), "ordered native detail sections");

                body.RecalculateChildren();
                Check(sections.Zip(sections.Skip(1)).All(pair => pair.First.Rect.Bottom + body.Spacing <= pair.Second.Rect.Top), "separate scroll blocks");
                Check(sections.All(b => b.Rect.Width == body.Content.Rect.Width && b.Rect.Height > 0), "uniform detail edges");
                Check(sections[0].FindChild("quote", true) != null, "native quote block present on main quest");
                if (npc == "benzene")
                {
                    var cols = sections[1].GetAllChildren<GUITextBlock>().Where(t => Equals(t.UserData, "count")).ToArray();
                    Check(cols.Length == 2 && cols[0].Rect.Left == cols[1].Rect.Left, "shared objective count column");
                    var cards = sections[2].Children.OfType<GUIFrame>().Where(c => c.UserData is "rewardstat" or "rewarditem" or "rewardunlock").ToArray();
                    var items = cards.Where(c => Equals(c.UserData, "rewarditem")).ToArray();
                    Check(cards.Length == 6 && cards.All(c => c.Rect.Height == cards[0].Rect.Height), "uniform height across all reward cards");
                    Check(cards[0].Rect.Y == cards[1].Rect.Y && cards[0].Rect.Right < cards[1].Rect.Left &&
                        cards[0].Rect.Bottom < cards[2].Rect.Top && cards[2].Rect.Y == cards[3].Rect.Y &&
                        cards[0].Rect.Left == cards[2].Rect.Left && cards[1].Rect.Right == cards[3].Rect.Right, "balanced two-column reward card grid");
                    Check(items.Length == 2 &&
                        items.All(c => { var s = c.FindChild("itemslot", true); return s != null && s.Rect.Width == s.Rect.Height && !s.GetAllChildren<GUITextBlock>().Any(); }) &&
                        items[0].GetAllChildren<GUITextBlock>().Any(t => t.Text.SanitizedString.Value.Contains("×1")) &&
                        items[1].GetAllChildren<GUITextBlock>().Any(t => t.Text.SanitizedString.Value.Contains("×7")), "reward item cards keep ×count in text without icon badge");
                }
                if (npc == "peachhat")
                {
                    var repeatCard = list.Content.Children.OfType<GUIButton>().Single(b => Equals(b.UserData, "typhoon_powder_stock"));
                    repeatCard.OnClicked(repeatCard, repeatCard.UserData);
                    panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                    Check(body.Content.FindChild("description").FindChild("quote", true) == null, "optional native quote block omitted on repeat");
                    var mainCard = list.Content.Children.OfType<GUIButton>().First();
                    mainCard.OnClicked(mainCard, mainCard.UserData);
                    panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                }
                Check(filters[0].Rect.Left == list.Rect.Left && filters[^1].Rect.Right == list.Rect.Right, "native filter/list edges");
                Check(header.Rect.Left == actions.Rect.Left && summary.Rect.Bottom == actions.Rect.Bottom, "native content/footers");
                void CheckEdges(GUIListBox scroll, int right)
                {
                    scroll.RecalculateChildren();
                    int edge = scroll.ScrollBarVisible ? scroll.ScrollBar.Rect.Left : right;
                    Check(scroll.AutoHideScrollBar && !scroll.KeepSpaceForScrollBar && scroll.Content.Rect.Right == edge &&
                        scroll.Content.Children.All(c => c.Rect.Right == edge), "rows fill available width with or without scrollbar");
                    Check(scroll.Content.GetAllChildren<GUIButton>().All(b => b.Rect.Right <= edge) &&
                        scroll.Content.GetAllChildren<GUITextBlock>().All(t => t.Rect.Right <= edge), "scrollbar leaves captions and hit targets unobstructed");
                }
                CheckEdges(list, filters[^1].Rect.Right);
                CheckEdges(body, header.Rect.Right);
                Check(list.Rect.Right == summary.Parent.Rect.Right && body.Rect.Right == actions.Rect.Right, "footer edges");
                Check(!sections[1].GetAllChildren<GUIButton>().Any(), "unaccepted objectives have no hand-in buttons");
                if (npc == null)
                {
                    Check(actions.GetAllChildren<GUITextBlock>().Any(b => b.Text.SanitizedString.Value.Contains("等待战役数据")), "waiting for initial snapshot");
                    runtime.GetProperty("Round", flags)!.SetValue(null, "new-round");
                    panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                    Check(actions.GetAllChildren<GUITextBlock>().All(b => !b.Text.SanitizedString.Value.Contains("等待战役数据")), "revision zero snapshot activates the open panel");
                }
                if (npc == null)
                {
                    var publishers = (GUIFrame)Field(panel, "publisherRow")!;
                    var thumbs = publishers.Children.OfType<GUIButton>().ToArray();
                    Check(thumbs.Length >= 3 && thumbs[1].ToolTip.SanitizedString.Value.Contains("桃帽"), "all and named publishers");
                    thumbs[1].OnClicked(thumbs[1], null);
                    panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                    Check(list.Content.CountChildren == 8 && filters[0].Text.Value.Contains("8"), "publisher scopes cards and counters");
                    var all = publishers.Children.OfType<GUIButton>().First();
                    all.OnClicked(all, null);
                    panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                }
                var rows = list.Content.Children.OfType<GUIButton>().ToArray();
                Check(rows.All(row => row.Rect.Height >= filters[0].Rect.Height * 2), "two-line task rows");
                Check(rows.All(r => r.Text.Value == "" && !r.ToolTip.IsNullOrEmpty() &&
                    r.GetAllChildren<GUITextBlock>().Count(label => label.Text.SanitizedString.Value.Length > 0) >= 4), "structured task cards and tooltips");
                Check(rows.Count(r => r.Selected) == 1 && Equals(rows.Single(r => r.Selected).UserData, Field(panel, "selected")) &&
                    filters[0].Text.Value.Contains(rows.Length.ToString()), "filter count and selected card");
                Check(rows.Length == (npc == null ? 48 : npc == "benzene" ? 9 : 8), "mode-scoped list");
                rows[^1].OnClicked(rows[^1], rows[^1].UserData);
                panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                Check(ReferenceEquals(list, Field(panel, "list")) && Equals(Field(panel, "selected"), rows[^1].UserData), "selection keeps controls");
                host.RectTransform.Resize(new Point(dimensions.X + 32, dimensions.Y + 16));
                panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                Check(Equals(Field(panel, "selected"), rows[^1].UserData), "resize keeps task selection");
                if (npc == null && dimensions.X == 1152)
                {
                    void Refresh() => panelType.GetMethod("Refresh", flags)!.Invoke(panel, null);
                    var active = new DeepDivingArmory.Quests.QuestState();
                    foreach (string id in new[] { "gunsmith_plastic_test", "co_pirate_bounty", "dda_tide_gauge" }) { active.Active[id] = new(); }
                    void UpdateState(int revision)
                    {
                        var snapshot = Module("QuestState").GetMethod("Read", flags)!.Invoke(null, [active.Write(true)]);
                        runtime.GetProperty("State", flags)!.SetValue(null, snapshot);
                        runtime.GetProperty("Revision", flags)!.SetValue(null, revision);
                        Refresh();
                    }
                    UpdateState(10);
                    list = (GUIListBox)Field(panel, "list")!;
                    body = (GUIListBox)Field(panel, "body")!;
                    void Select(string id)
                    {
                        var card = list.Content.Children.OfType<GUIButton>().Single(b => Equals(b.UserData, id));
                        card.OnClicked(card, card.UserData);
                        Refresh();
                    }
                    foreach (string id in new[] { "co_pirate_bounty", "dda_tide_gauge" })
                    {
                        Select(id);
                        Check(!body.Content.FindChild("objectives").GetAllChildren<GUIButton>().Any(), "no material action on " + id);
                    }
                    Select("sp_break_embargo");
                    var reputationCards = body.Content.FindChild("rewards").Children.OfType<GUIFrame>()
                        .Where(c => Equals(c.UserData, "rewardstat")).ToArray();
                    Check(reputationCards.Length >= 4 && reputationCards[2].Rect.Height == reputationCards[3].Rect.Height &&
                        reputationCards[2].Rect.Top == reputationCards[3].Rect.Top, "two faction rewards share one row");
                    foreach (var (index, amount, faction, tone) in new[] { (2, "+4", "木星分离派", "Green"), (3, "-2", "木卫二联盟", "Red") })
                    {
                        var reward = reputationCards[index];
                        var accent = (Color)Module("QuestStyle").GetField(tone, flags)!.GetValue(null)!;
                        var labels = reward.GetAllChildren<GUITextBlock>().ToArray();
                        var flag = reward.FindChild("itemslot");
                        Check(reward.Children.First().Color == accent && flag.CountChildren == 3 && flag.Children.All(c => c.Color == accent) &&
                            labels.Any(t => t.Text.SanitizedString.Value == amount && t.TextColor == accent) && labels.Any(t => t.Text.SanitizedString.Value == faction), "flag, stripe, sign and faction " + tone);
                    }
                    Select("gunsmith_plastic_test");
                    var goals = body.Content.FindChild("objectives");
                    var hand = goals.GetAllChildren<GUIButton>().Single();
                    var materialRow = goals.FindChild("plastic");
                    var customRow = goals.FindChild("relay");
                    Check(hand.Parent == materialRow && !hand.Enabled && hand.ToolTip.SanitizedString.Value.Contains("氧化苯") &&
                        !customRow.GetAllChildren<GUIButton>().Any(), "global nonremote material button and custom row");
                    var numeric = materialRow.FindChild("count");
                    var objectiveName = materialRow.Children.OfType<GUITextBlock>().First();
                    var itemSlot = materialRow.FindChild("itemslot", true);
                    var itemInfo = materialRow.FindChild("iteminfo", true);
                    Check(itemSlot != null && itemInfo != null && itemSlot.Rect.Width == itemSlot.Rect.Height &&
                        !itemSlot.GetAllChildren<GUITextBlock>().Any() &&
                        itemInfo.GetAllChildren<GUITextBlock>().Any(t => t.Text.SanitizedString.Value.Contains("×4")) &&
                        itemSlot.Rect.Right < itemInfo.Rect.Left && itemInfo.Rect.Right < hand.Rect.Left &&
                        hand.Rect.Right <= materialRow.Rect.Right && itemSlot.Rect.Top >= numeric.Rect.Bottom &&
                        hand.Rect.Top >= numeric.Rect.Bottom && hand.Rect.Height == itemInfo.Rect.Height &&
                        hand.Rect.Contains(hand.TextBlock.Rect) &&
                        customRow.FindChild("itemslot", true) == null && customRow.FindChild("iteminfo", true) == null,
                        "Plan A material strip: icon (no badge) | info with ×count | hand-in button");
                    Check(objectiveName.Rect.Right < numeric.Rect.Left &&
                        numeric.Rect.Left == customRow.FindChild("count").Rect.Left &&
                        numeric.Rect.Right == customRow.FindChild("count").Rect.Right,
                        "objective progress column stays cleanly aligned across rows");
                    active.Active["gunsmith_plastic_test"]["plastic"] = 4;
                    UpdateState(11);
                    var complete = body.Content.FindChild("objectives").GetAllChildren<GUIButton>().Single();
                    Check(!complete.Enabled && complete.Text.Value == "已上交", "filled material disabled even with other goals outstanding");
                    // Verify debug bypass exposes Submit in TAB for in-person quests and promotes newly unlocked quests.
                    actions = (GUIFrame)Field(panel, "actions")!;
                    runtime.GetProperty("DebugBypass", flags)!.SetValue(null, true);
                    int readyCount = (int)runtime.GetMethod("ReadyAvailable", flags)!.Invoke(null, [false])!;
                    Check(readyCount >= 12, "debug mode readies all TL1 quests");
                    runtime.GetProperty("Revision", flags)!.SetValue(null, 12);
                    Refresh();
                    Select("gunsmith_plastic_test");
                    Check(actions.GetAllChildren<GUIButton>().Any(b => b.Text.Value == "提交"), "debug bypass shows Submit in TAB for in-person quest");
                    int allCount = (int)runtime.GetMethod("ReadyAvailable", flags)!.Invoke(null, [true])!;
                    Check(allCount == 48, "debug all readies all 48 quests");
                    runtime.GetProperty("DebugBypass", flags)!.SetValue(null, false);
                    UpdateState(13);
                    Check(actions.GetAllChildren<GUIButton>().All(b => b.Text.Value != "提交"), "normal mode hides Submit in TAB for in-person quest");
                    // Drive actual native scrollbars across overflow and back without changing the panel width.
                    foreach (int height in new[] { 6000, 90, 6000 })
                    {
                        foreach (var box in new[] { list, body })
                        {
                            box.RectTransform.Resize(new Point(box.Rect.Width, height));
                            box.UpdateDimensions();
                            box.ScrollBarVisible = box.BarSize < 1;
                            box.UpdateDimensions();
                        }
                        Refresh();
                        foreach (var box in new[] { list, body })
                        {
                            Check(box.ScrollBarVisible == (height == 90), "native scrollbar transitions");
                            CheckEdges(box, box.Rect.Right);
                        }
                    }
                }
                var field = runtime.GetField(npc == null ? "tabPanel" : "dialoguePanel", flags)!;
                field.SetValue(null, panel);
                Call("ClearRound");
                Check(!host.Children.Any() && field.GetValue(null) == null && portraits.Count == 0 && !(bool)runtime.GetProperty("DebugBypass", flags)!.GetValue(null)!, "ClearRound detaches panel and releases portraits");
                StubPortraits();
            }
        }
        Call("ClearRound");
        NativeHudChecks.Verify(runtime, "ClearRound");
        var finalHost = new GUIFrame(new RectTransform(new Point(86, 450)), style: null);
        var finalSidebar = new GUILayoutGroup(new RectTransform(Vector2.One, finalHost.RectTransform));
        Call("AttachSidebar", finalSidebar, false, (Action)(() => { }), null);
        NativeHudChecks.Verify(runtime, "Dispose");
        Check(finalSidebar.CountChildren == 0 && runtime.GetField("readyBadge", flags)!.GetValue(null) == null, "direct dispose releases sidebar and badge");
        var remainingRules = runtime.GetProperty("Rules", flags)!.GetValue(null)!;
        Check(((IDictionary)Field(remainingRules, "Quests")!).Count == 0 && runtime.GetField("Tracked", flags)!.GetValue(null) == null, "dispose rules and tracking");
        Console.WriteLine("PASS native sidebar, sections, cards, reward inspection, scrollbar show/hide/reflow, material-only controls, resize and cleanup");
    }
}
