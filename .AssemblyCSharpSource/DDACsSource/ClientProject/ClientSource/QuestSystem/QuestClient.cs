using System.Xml.Linq;
using Microsoft.Xna.Framework.Input;

namespace DeepDivingArmory.Quests;

public static partial class QuestRuntime
{
    private const TabMenu.InfoFrameTab QuestTab = (TabMenu.InfoFrameTab)0x4441;
    internal static string? Tracked;
    private static readonly Dictionary<string, Sprite?> portraits = [];
    private static QuestPanel? tabPanel, dialoguePanel;
    private static GUIMessageBox? dialog;
    private static GUIButton? tabButton, conversationButton, campaignButton;
    private static TabMenu? menu;
    private static GUILayoutGroup? sidebar;
    private static Point originalSidebarMax;
    private static GUIFrame? readyBadge;
    private static GUITextBlock? readyNumber;
    private static UISprite? tabIcon;
    private static int badgeRevision = -1;
    private static string? badgeRound;
    private static ushort dialogueSpeaker;
    private static IDebugConsole? console;

    static partial void RegisterSide(ISimpleHookService hooks)
    {
        Plugin.Network.RegisterHandler<NetworkHeader, QuestSnapshot>(NetworkHeader.QuestState, Receive);
        console = PluginServiceProvider.GetService<IDebugConsole>();
        console.RegisterCommand("dda_quest_ui", "dda_quest_ui", CommandFlags.DoNotRelayToServer, _ => OpenGlobal());
        console.RegisterCommand("dda_quest_npc", "dda_quest_npc <npcId>", CommandFlags.DoNotRelayToServer, args =>
        {
            if (args.Length == 1 && Rules.Npcs.TryGetValue(args[0], out var npc))
            { OpenDialogue(npc, 0, true); }
            else { console.NewMessage("dda_quest_npc <" + string.Join(" | ", Rules.Npcs.Keys) + ">"); }
        }, () => [Rules.Npcs.Keys.ToArray()]);
    }

    internal static Sprite? Portrait(Publisher npc)
    {
        if (portraits.TryGetValue(npc.Id, out var sprite)) { return sprite; }
        string path = ContentPath.FromRaw(Plugin.Package, npc.Texture).Value;
        if (npc.Texture.Length > 0 && File.Exists(path))
        { sprite = new Sprite(path, npc.SourceRect.Length > 0 ? XMLExtensions.ParseRect(npc.SourceRect, true) : (Rectangle?)null); }
        portraits[npc.Id] = sprite;
        return sprite;
    }

    private static void Receive(QuestSnapshot snapshot)
    {
        if (GameMain.GameSession?.Campaign == null || string.IsNullOrEmpty(snapshot.Round) ||
            (Round == snapshot.Round && snapshot.Revision < Revision)) { return; }
        if (snapshot.Declined) { Declined(); }
        State = QuestState.Read(snapshot.State);
        Round = snapshot.Round;
        Revision = snapshot.Revision;
        if (Tracked != null && !State.Active.ContainsKey(Tracked)) { Tracked = null; }
    }

    internal static void Request(QuestAction action, string quest, ushort speaker, bool preview, string objectiveId = "")
    {
        var req = new QuestRequest((byte)action, quest, speaker, Round, Revision, objectiveId);
        if (GameMain.IsSingleplayer)
        {
            if (!Handle(req, Character.Controlled, preview)) { Declined(); }
        }
        else if (GameMain.Client != null) { Plugin.Network.Send(NetworkHeader.QuestRequest, req); }
    }

    private static void Declined() => GUI.AddMessage(QuestPanel.Text.Ui("denied"), GUIStyle.Orange);

    static partial void StartSide()
    {
        if (GameMain.IsMultiplayer) { Request(QuestAction.Sync, "", 0, false); }
    }

    static partial void Publish()
    {
        if (Tracked != null && !State.Active.ContainsKey(Tracked)) { Tracked = null; }
    }

    static partial void UpdateSide()
    {
        if (dialog != null && (dialog.Closed || !GUIMessageBox.MessageBoxes.Contains(dialog) ||
            (dialogueSpeaker != 0 && (Entity.FindEntityByID(dialogueSpeaker) is not Character npc ||
                npc.IsDead || !InReach(Character.Controlled, npc))))) { CloseDialogue(); }
        if (conversationButton != null && !ConversationAction.IsDialogOpen) { Detach(ref conversationButton); }
        if (campaignButton != null && GameMain.GameSession?.Campaign?.ShowCampaignUI != true) { Detach(ref campaignButton); }
        if (Screen.Selected == GameMain.GameScreen && GameMain.GameSession != null && !DebugConsole.IsOpen &&
            GUI.KeyboardDispatcher?.Subscriber is not GUITextBox && !GUI.PauseMenuOpen &&
            PluginSettings.GetKey("QuestMenu", Keys.J).IsHit())
        {
            if (dialog != null) { CloseDialogue(); }
            else if (GameSession.IsTabMenuOpen && TabMenu.SelectedTab == QuestTab) { GameMain.GameSession.ToggleTabMenu(); }
            else if (!GUI.InputBlockingMenuOpen || GameSession.IsTabMenuOpen) { OpenGlobal(); }
        }
    }

    private static void OpenGlobal()
    {
        if (GameMain.GameSession is not { } session) { return; }
        CloseDialogue();
        if (!GameSession.IsTabMenuOpen) { session.ToggleTabMenu(); }
        if (GameSession.TabMenuInstance is { } tabs) { tabs.SelectInfoFrameTab(QuestTab); }
        else { OpenDialogue(null, 0, false); }
    }

    private static void OpenDialogue(Publisher? npc, ushort entity, bool preview)
    {
        CloseDialogue();
        var windowSize = new Vector2(.84f, .80f);
        dialog = new GUIMessageBox("", "", Array.Empty<LocalizedString>(), relativeSize: windowSize) { DrawOnTop = true };
        dialog.InnerFrame.ClearChildren();
        dialog.InnerFrame.RectTransform.Resize(windowSize);
        var area = new GUIFrame(new RectTransform(new Vector2(1f, .915f), dialog.InnerFrame.RectTransform, Anchor.BottomCenter), style: null);
        new QuestDialogueHeader(new RectTransform(new Vector2(1f, .085f), dialog.InnerFrame.RectTransform), npc, CloseDialogue);
        dialogueSpeaker = entity;
        dialoguePanel = new QuestPanel(area, npc, entity, preview);
        if (GameMain.IsMultiplayer) { Request(QuestAction.Sync, "", 0, false); }
    }

    private static void CloseDialogue()
    {
        dialoguePanel?.Close();
        dialoguePanel = null;
        if (dialog != null)
        {
            dialog.InnerFrame.ClearChildren();
            dialog.Close();
            dialog.RectTransform.Parent = null;
            dialog = null;
        }
        dialogueSpeaker = 0;
    }

    internal static void AddTab(TabMenu tabs, TabMenu.InfoFrameTab selected)
    {
        ReleaseTab();
        menu = tabs;
        if (selected == QuestTab)
        {
            tabs.contentFrame.RectTransform.Resize(new Vector2(.85f, .79f));
            if (tabs.infoFrameHolder.Parent is GUILayoutGroup inner)
            {
                foreach (var sibling in inner.Children.Where(c => c != tabs.infoFrameHolder))
                {
                    sibling.Visible = false;
                    sibling.IgnoreLayoutGroups = true;
                }
                tabs.infoFrameHolder.RectTransform.Resize(inner.Rect.Size);
                inner.Recalculate();
            }
            else
            {
                tabs.infoFrameHolder.RectTransform.Resize(new Point(tabs.infoFrameHolder.Parent.Rect.Width, tabs.infoFrameHolder.Rect.Height));
            }
        }
        if (tabs.tabButtons.FirstOrDefault()?.Parent is not GUILayoutGroup bar) { return; }
        tabIcon ??= new UISprite(new ContentXElement(Plugin.Package, new XElement("Sprite",
            new XAttribute("texture", "%ModDir%/Quests/quest-tab.png"),
            new XAttribute("sourcerect", "0,0,65,65"), new XAttribute("maintainaspectratio", true), new XAttribute("tile", false))));
        AttachSidebar(bar, selected == QuestTab, () => tabs.SelectInfoFrameTab(QuestTab), tabIcon);
        tabs.tabButtons.Add(tabButton!);
    }

    private static void AttachSidebar(GUILayoutGroup bar, bool selected, Action click, UISprite? icon)
    {
        sidebar = bar;
        originalSidebarMax = bar.RectTransform.MaxSize;
        tabButton = new GUIButton(new RectTransform(Vector2.One, bar.RectTransform, scaleBasis: ScaleBasis.BothWidth),
            style: "InfoFrameTabButton.Mission")
        {
            UserData = QuestTab, ToolTip = QuestPanel.Text.Ui("tab"), Selected = selected,
            OnClicked = (_, _) => { click(); return true; }
        };
        if (icon != null) { tabButton.Frame.sprites = new() { [GUIComponent.ComponentState.None] = [icon] }; }
        readyBadge = new GUIFrame(new RectTransform(new Vector2(.39f, .33f), tabButton.RectTransform, Anchor.TopRight), style: null)
            { Color = QuestStyle.Green, HoverColor = QuestStyle.Green, SelectedColor = QuestStyle.Green,
              PressedColor = QuestStyle.Green, OutlineColor = QuestStyle.Deep, OutlineThickness = 1, CanBeFocused = false };
        readyNumber = new GUITextBlock(new RectTransform(Vector2.One, readyBadge.RectTransform), "",
            textColor: QuestStyle.Deep, font: GUIStyle.SmallFont, textAlignment: Alignment.Center)
            { Padding = Vector4.Zero, AutoScaleHorizontal = true, AutoScaleVertical = true, CanBeFocused = false };
        tabButton.OnAddedToGUIUpdateList += RefreshSidebar;
        RefreshSidebar(tabButton);
    }

    private static void RefreshSidebar(GUIComponent button)
    {
        if (sidebar == null) { return; }
        int limit = QuestLayout.SidebarLimit(sidebar.Rect.Height, sidebar.CountChildren, sidebar.AbsoluteSpacing);
        var max = new Point(Math.Min(originalSidebarMax.X, limit), originalSidebarMax.Y);
        if (sidebar.RectTransform.MaxSize != max)
        {
            sidebar.RectTransform.MaxSize = max;
            sidebar.Recalculate();
        }
        if (badgeRevision == Revision && badgeRound == Round) { return; }
        badgeRevision = Revision;
        badgeRound = Round;
        int ready = Rules.Quests.Values.Count(q => State.Status(Rules, q) == QuestStatus.Ready);
        readyNumber!.Text = ready.ToString();
        readyBadge!.Visible = ready > 0;
    }

    internal static void ShowTab(TabMenu tabs, TabMenu.InfoFrameTab selected)
    {
        if (selected != QuestTab) { return; }
        tabPanel = new QuestPanel(tabs.infoFrameHolder);
        if (GameMain.IsMultiplayer) { Request(QuestAction.Sync, "", 0, false); }
    }

    internal static void ReleaseTab()
    {
        tabPanel?.Close();
        tabPanel = null;
        if (tabButton != null) { menu?.tabButtons.Remove(tabButton); }
        if (tabButton != null)
        {
            tabButton.OnAddedToGUIUpdateList -= RefreshSidebar;
            tabButton.Frame.sprites = null;
        }
        Detach(ref tabButton);
        if (sidebar != null)
        {
            sidebar.RectTransform.MaxSize = originalSidebarMax;
            sidebar.Recalculate();
        }
        sidebar = null;
        readyBadge = null;
        readyNumber = null;
        badgeRevision = -1;
        badgeRound = null;
        menu = null;
    }

    private static void Detach(ref GUIButton? button)
    {
        if (button == null) { return; }
        button.OnClicked = null;
        button.RemoveFromGUIUpdateList();
        button.RectTransform.Parent = null;
        button = null;
    }

    internal static void AddConversation(GUIListBox parent, Character speaker)
    {
        Detach(ref conversationButton);
        if (Match(speaker) is not { } npc || parent.Content.Children.LastOrDefault() is not GUILayoutGroup message ||
            message.GetChild<GUILayoutGroup>() is not { } options) { return; }
        // Leave the native option array intact so its network response indices stay valid.
        conversationButton = Entry(new RectTransform(new Point(options.Rect.Width, GUI.IntScale(32)), options.RectTransform,
            isFixedSize: true), npc, speaker.ID);
        int height = options.Children.Sum(c => c.Rect.Height + options.AbsoluteSpacing) + GUI.IntScale(16);
        options.RectTransform.MinSize = new Point(0, height);
        message.RectTransform.MinSize = options.RectTransform.MinSize;
        options.Recalculate();
        message.Recalculate();
    }

    internal static void AddCampaign(CampaignUI ui, CampaignMode.InteractionType tab, Character? speaker)
    {
        Detach(ref campaignButton);
        if (Match(speaker) is not { } npc || ui.GetTabContainer(tab) is not { } parent) { return; }
        campaignButton = Entry(new RectTransform(new Point(GUI.IntScale(150), GUI.IntScale(34)), parent.RectTransform, Anchor.BottomCenter)
        { AbsoluteOffset = new Point(0, GUI.IntScale(6)) }, npc, speaker!.ID);
    }

    private static GUIButton Entry(RectTransform rect, Publisher npc, ushort entity) =>
        new(rect, QuestPanel.Text.Ui("tab"), style: "GUIButtonSmall")
        { OnClicked = (_, _) => { OpenDialogue(npc, entity, false); return true; } };

    static partial void ClearSide()
    {
        ReleaseTrackedHud();
        CloseDialogue();
        ReleaseTab();
        if (TabMenu.SelectedTab == QuestTab)
        {
            if (GameSession.IsTabMenuOpen && GameSession.TabMenuInstance is { } tabs)
            {
                tabs.SelectInfoFrameTab(TabMenu.InfoFrameTab.Crew);
                ReleaseTab();
            }
            else { TabMenu.SelectedTab = TabMenu.InfoFrameTab.Crew; }
        }
        Detach(ref conversationButton);
        Detach(ref campaignButton);
        foreach (var sprite in portraits.Values) { sprite?.Remove(); }
        portraits.Clear();
        tabIcon?.Sprite.Remove();
        tabIcon = null;
        Tracked = null;
    }

    static partial void DisposeSide()
    {
        ClearSide();
        console?.DeregisterCommand("dda_quest_ui");
        console?.DeregisterCommand("dda_quest_npc");
        console = null;
    }
}

[HarmonyPatch]
internal static class QuestEntrances
{
    [HarmonyPostfix, HarmonyPatch(typeof(GameScreen), nameof(GameScreen.AddToGUIUpdateList))]
    private static void Hud() => QuestRuntime.CollectTrackedHud();
    [HarmonyPostfix, HarmonyPatch(typeof(TabMenu), nameof(TabMenu.CreateInfoFrame))]
    private static void Added(TabMenu __instance, TabMenu.InfoFrameTab selectedTab) => QuestRuntime.AddTab(__instance, selectedTab);
    [HarmonyPostfix, HarmonyPatch(typeof(TabMenu), nameof(TabMenu.SelectInfoFrameTab))]
    private static void Selected(TabMenu __instance, TabMenu.InfoFrameTab selectedTab) => QuestRuntime.ShowTab(__instance, selectedTab);
    [HarmonyPrefix, HarmonyPatch(typeof(TabMenu), nameof(TabMenu.OnClose))]
    private static void Closed() => QuestRuntime.ReleaseTab();
    [HarmonyPostfix, HarmonyPatch(typeof(ConversationAction), nameof(ConversationAction.CreateConversation))]
    private static void Conversation(GUIListBox parentBox, Character speaker) => QuestRuntime.AddConversation(parentBox, speaker);
    [HarmonyPostfix, HarmonyPatch(typeof(CampaignUI), nameof(CampaignUI.SelectTab))]
    private static void Interaction(CampaignUI __instance, CampaignMode.InteractionType tab, Character npc) => QuestRuntime.AddCampaign(__instance, tab, npc);
}