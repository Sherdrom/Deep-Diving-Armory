using System.Xml.Linq;
using DeepDivingArmory.Quests;

static void Check(bool condition, string test)
{
    if (!condition) { throw new Exception(test); }
}
string root = AppContext.BaseDirectory;
var rules = QuestRules.Load(Path.Combine(root, "Quests"));
Check(rules.Quests.Count == 5 && rules.Npcs.Count == 2, "shipped quest rules");
var npcXml = XElement.Parse("<Npcs><Npc id='n' tags='chief' faction='coalition'/></Npcs>");
static XElement QuestFile(string id, string requirements = "", string rewards = "<Rewards/>") =>
    XElement.Parse($"<Quests><Quest id='{id}' npc='n' category='chain'>{requirements}<Objectives><Custom id='x' target='x'/></Objectives>{rewards}</Quest></Quests>");
static void Invalid(Action action, params string[] fragments)
{
    try { action(); }
    catch (FormatException e) when (fragments.All(f => e.Message.Contains(f, StringComparison.Ordinal))) { return; }
    throw new Exception("expected FormatException containing " + string.Join(", ", fragments));
}
var temp = Directory.CreateTempSubdirectory();
try
{
    string FileAt(string name) => Path.Combine(temp.FullName, name);
    npcXml.Save(FileAt("npcs.xml"));
    QuestFile("ignored").Save(FileAt("questsOther.xml"));
    Invalid(() => QuestRules.Load(temp.FullName), "quests.xml", "quests_*.xml");
    QuestFile("later", "<Prerequisites><RequireQuest id='middle'/></Prerequisites>").Save(FileAt("quests_Z.xml"));
    QuestFile("middle", rewards: "<Rewards unlock='later'/>").Save(FileAt("quests_a.xml"));
    Check(QuestRules.Load(temp.FullName).Quests.Keys.SequenceEqual(["middle", "later"]), "split-only forward and backward references");
    QuestFile("first").Save(FileAt("quests.xml"));
    Check(QuestRules.Load(temp.FullName).Quests.Keys.SequenceEqual(["first", "middle", "later"]), "deterministic filename order");
    QuestFile("middle").Save(FileAt("quests_Z.xml"));
    Invalid(() => QuestRules.Load(temp.FullName), "quests_a.xml", "quests_Z.xml", "middle");
    new XElement("Quest").Save(FileAt("quests_Z.xml"));
    Invalid(() => QuestRules.Load(temp.FullName), "quests_Z.xml", "<Quests>");
    QuestFile("other").Save(FileAt("quests_Z.xml"));
    Invalid(() => QuestRules.Load(temp.FullName), "quests_a.xml", "middle", "later");
}
finally { temp.Delete(true); }

IReadOnlyDictionary<string, int> Reputation(string rewards) => QuestRules.Parse(npcXml, QuestFile("rep", rewards: rewards)).Quests["rep"].Rewards.Reputation;
Check(Reputation("<Rewards reputation='-3'/>")["coalition"] == -3 && Reputation("<Rewards reputation='120'/>")["coalition"] == 120 &&
    Reputation("<Rewards reputation='0'/>").Count == 0, "legacy signed, unbounded positive and zero shorthand");
var mixed = Reputation("<Rewards reputation='3'><Reputation amount='-3'/><Reputation faction='husk' amount='100'/>" +
    "<Reputation faction='HUSK' amount='-2'/><Reputation faction='modded' amount='-100'/></Rewards>");
Check(mixed.Count == 2 && mixed["husk"] == 98 && mixed["modded"] == -100, "merge factions and drop net zero");
foreach (string amount in new[] { "0", "-101", "101", "1.5", "", "bad" })
{ Invalid(() => Reputation($"<Rewards><Reputation amount='{amount}'/></Rewards>"), "rep"); }
Invalid(() => Reputation("<Rewards><Reputation/></Rewards>"), "rep");
Invalid(() => Reputation("<Rewards reputation='2147483647'><Reputation amount='1'/></Rewards>"), "rep");
Check(rules.Quests["manifest"].Requires.Contains("bulkhead") && rules.Quests["bulkhead"].Rewards.Unlock.Contains("soundings") &&
    rules.Quests["manifest"].Rewards.Reputation["coalition"] == 3 && rules.Quests["manifest"].Rewards.Reputation["separatists"] == -2, "shipped faction contract");
Console.WriteLine("PASS split catalogs, cross-file references, diagnostics and signed faction merging");

HashSet<string>? english = null;
foreach (string language in new[] { "English", "Chinese" })
{
    var pack = XElement.Load(Path.Combine(root, "text", language + "Quests.xml")).Elements().ToDictionary(e => e.Name.LocalName, e => e.Value);
    var keys = pack.Keys.ToHashSet();
    if (english != null) { Check(keys.SetEquals(english), "bilingual key parity"); }
    english = keys;
    var text = new QuestText(k => pack.GetValueOrDefault(k, ""), id => "ITEM/" + id);
    foreach (var q in rules.Quests.Values)
    {
        Check(text.Title(q.Id) != q.Id && text.Field(q.Id, "desc") != "" && text.Npc(q.Npc, "role") != "", "text contract " + q.Id);
    }
    var first = rules.Quests["bulkhead"];
    pack.Remove("dda.quest.bulkhead.obj.plates");
    Check(text.Title("missing") == "missing" && text.Field("missing", "desc") == "" && text.Field("watch", "location") == "", "optional fields");
    Check(text.Field("samples", "quote") == "" && text.Field("watch", "quote") != "", "optional quote");
    Check(text.Objective(first, first.Objectives[0]).Contains("ITEM/steel"), "localized delivery fallback");
}
Console.WriteLine("PASS bilingual rules, title/description/objective fallbacks and optional quote");

var state = new QuestState();
Quest start = rules.Quests["bulkhead"], next = rules.Quests["soundings"], watch = rules.Quests["watch"];
bool Apply(Quest q, QuestAction action, bool npc = true) => state.Apply(rules, q, action, npc, _ => true);
Check(!Apply(next, QuestAction.Accept) && !Apply(start, QuestAction.Accept, false), "accept gates");
Check(Apply(start, QuestAction.Accept) && !Apply(start, QuestAction.Accept), "single acceptance");
int takeCalls = 0;
int Take(string target, int remaining)
{
    takeCalls++;
    int taken = Math.Min(remaining, state.Stock.GetValueOrDefault(target));
    state.Stock[target] = state.Stock.GetValueOrDefault(target) - taken;
    return taken;
}
var plates = start.Objectives.Single();
bool HandIn(Quest quest, string objective, bool atNpc = true) => state.Deliver(quest, objective, atNpc, Take);
state.Stock["steel"] = 3;
Check(!Apply(start, QuestAction.Submit) && state.Progress(start, plates) == 0, "stock alone cannot complete a legacy active objective");
Check(!HandIn(start, plates.Id, false) && !HandIn(start, "unknown") && takeCalls == 0, "validate location and objective before taking anything");
state.Stock["steel"] = 0;
Check(!HandIn(start, plates.Id) && state.Progress(start, plates) == 0, "zero stock rejected");
state.Stock["steel"] = 1;
Check(HandIn(start, plates.Id) && state.Stock["steel"] == 0 && state.Progress(start, plates) == 1 && !Apply(start, QuestAction.Submit), "partial delivery");
var partial = QuestState.Read(state.Write(true));
Check(partial.Active[start.Id][plates.Id] == 1 && partial.Stock["steel"] == 0, "partial snapshot");
state = QuestState.Read(state.Write());
Check(state.Progress(start, plates) == 1 && state.Stock.Count == 0, "reload keeps delivered count independently of stock");
state.Stock["steel"] = 5;
Check(HandIn(start, plates.Id) && state.Stock["steel"] == 3 && state.Status(rules, start) == QuestStatus.Ready, "take exactly the remaining two");
int callsAtReady = takeCalls;
Check(!HandIn(start, plates.Id) && takeCalls == callsAtReady && !Apply(start, QuestAction.Submit, false), "duplicate hand-in and remote settlement rejected");
Check(!state.Apply(rules, start, QuestAction.Submit, true, _ => false) && state.Progress(start, plates) == 3, "reward failure preserves delivery");
int marks = 0, reputation = 0, rewards = 0;
bool Settle(Quest q)
{
    marks += q.Rewards.Marks;
    reputation += q.Rewards.Reputation["location"];
    rewards += q.Rewards.Items.Single(i => i.Id == "saltpeter_powder").Count;
    return true;
}
Check(state.Apply(rules, start, QuestAction.Submit, true, Settle) && !state.Apply(rules, start, QuestAction.Submit, true, Settle), "settles once");
Check(state.Stock["steel"] == 3 && takeCalls == callsAtReady && !HandIn(start, plates.Id) && marks == 320 && reputation == 1 && rewards == 2 && state.Trust["dispatch"] == 5, "settlement totals");
Check(state.Unlocked.Contains(next.Id) && !Apply(start, QuestAction.Accept) && Apply(next, QuestAction.Accept), "chain unlock");
Check(Apply(watch, QuestAction.Accept) && state.Advance(rules, ObjectiveType.KillTag, x => x == "crawler", 2), "shared combat counter");
state.Stock["steel"] = 10;
state.LastPort = 3;
string save = state.Write();
Check(QuestState.Read(state.Write(true)).Stock["steel"] == 10, "snapshot includes visible cargo");
state = QuestState.Read(save);
Check(state.LastPort == 3 && state.Stock.Count == 0 && state.Write() == save && state.Progress(watch, watch.Objectives[0]) == 2, "persistent progress, transient stock");
Check(Apply(watch, QuestAction.Abandon) && Apply(watch, QuestAction.Accept) && state.Progress(watch, watch.Objectives[0]) == 0, "abandon resets counters");
Check(state.Advance(rules, ObjectiveType.KillTag, x => x == "crawler", 8) && !state.Advance(rules, ObjectiveType.KillTag, _ => true), "counter saturation");
Check(Apply(watch, QuestAction.Submit, false) && Apply(watch, QuestAction.Accept), "remote repeatable");
Check(state.Advance(rules, ObjectiveType.ReachLocation, x => x == "city") && Apply(next, QuestAction.Submit, false), "arrival and remote completion");
var extra = start with
{
    Id = "extra", Remote = true,
    Requires = [],
    Objectives = [
    new("a",ObjectiveType.DeliverItem,"steel",2),new("b",ObjectiveType.DeliverItem,"STEEL",3),new("c",ObjectiveType.Custom,"relay",1)]
};
rules.Quests.Add(extra.Id, extra);
Check(Apply(extra, QuestAction.Accept), "extra accepted");
state.Stock["steel"] = 4;
Check(!HandIn(extra, "c") && takeCalls == callsAtReady && !state.Advance(rules, ObjectiveType.DeliverItem, _ => true), "only delivery objectives can take items");
Check(HandIn(extra, "b", false) && state.Progress(extra, extra.Objectives[1]) == 3 && state.Stock["steel"] == 1, "single remote hand-in in full");
Check(state.Progress(extra, extra.Objectives[0]) == 0 && HandIn(extra, "a") && state.Progress(extra, extra.Objectives[0]) == 1 &&
    !HandIn(extra, "a") && !Apply(extra, QuestAction.Submit), "same-target objectives credit only the chosen row");
state.Stock["steel"] = 2;
Check(HandIn(extra, "a") && state.Advance(rules, ObjectiveType.Custom, id => id == "relay") && Apply(extra, QuestAction.Submit, false) &&
    state.Stock["steel"] == 1, "mixed objective settlement leaves spare item untouched");
Console.WriteLine("PASS partial/full hand-in, duplicate and invalid requests, stock-independent save/snapshot, rewards, prerequisites, shared progress and repeat");

int layouts = 0;
foreach (var size in new[] { (960, 540), (1280, 720), (1920, 1080), (2560, 1440), (3440, 1440) })
    foreach (float scale in new[] { .75f, 1f, 1.5f, 2f })
        foreach (bool dialogue in new[] { false, true })
        {
            int width = (int)(size.Item1 * (dialogue ? .84f : .74f));
            int height = (int)(size.Item2 * (dialogue ? .732f : .70f));
            var l = new QuestLayout(width, height, scale);
            int gap = (int)Math.Round(5 * scale);
            int side = Math.Min(width / 12, QuestLayout.SidebarLimit(height, 6, gap));
            Check(side > 0 && 6 * side + 5 * gap <= height, "six square sidebar buttons fit");
            Check(l.Left.Y == l.Right.Y && l.Left.Bottom == l.Right.Bottom && l.Left.Right < l.Right.X, "panel bounds");
            Check(l.Summary.Bottom == l.Actions.Bottom && l.List.Bottom < l.Summary.Y && l.List.Height > 0, "footer alignment");
            var cells = Enumerable.Range(0, 4).Select(i => l.Filters.Cell(i, 4, l.Padding)).ToArray();
            Check(cells[0].X == l.List.X && cells[^1].Right == l.List.Right && cells.Max(c => c.Width) - cells.Min(c => c.Width) <= 1, "equal filters");
            Check(l.Header.X == l.Body.X && l.Header.Right == l.Actions.Right && l.Body.Height > 0, "detail edges");
            var (a, m) = QuestLayout.Sender(l.Header.Width, l.Header.Height, l.Gap);
            Check(a.Width == a.Height && a.Right < m.X && m.Right == l.Header.Width, "avatar separation");
            foreach (int measured in new[] { 32, 64, 160 })
            {
                var (label, column) = QuestLayout.Objective(l.Body.Width, l.Row, measured, l.Padding);
                Check(label.Right + l.Padding == column.X && column.Right == l.Body.Width, "shared check column");
            }
            layouts++;
        }
Console.WriteLine($"PASS {layouts} resolution/scale/mode layouts");
if (args.Length > 0) { NativeChecks.Run(args); }
