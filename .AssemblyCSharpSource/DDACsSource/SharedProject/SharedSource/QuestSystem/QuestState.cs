using System.Xml.Linq;

namespace DeepDivingArmory.Quests;

internal sealed class QuestState
{
    internal int LastPort = -1;
    internal readonly Dictionary<string, Dictionary<string, int>> Active = new();
    internal readonly HashSet<string> Completed = [];
    internal readonly HashSet<string> Unlocked = [];
    internal readonly Dictionary<string, int> Trust = new();
    internal readonly Dictionary<string, int> Stock = new(StringComparer.OrdinalIgnoreCase);

    internal QuestStatus Status(QuestRules rules, Quest q)
    {
        if (Active.ContainsKey(q.Id))
        { return q.Objectives.All(o => Progress(q, o) >= o.Count) ? QuestStatus.Ready : QuestStatus.Active; }
        if (Completed.Contains(q.Id) && !q.Repeatable) { return QuestStatus.Completed; }
        bool gated = rules.Quests.Values.Any(p => p.Rewards.Unlock.Contains(q.Id));
        bool available = (!gated || Unlocked.Contains(q.Id)) && q.Requires.All(Completed.Contains) &&
            q.Trust.All(t => Trust.GetValueOrDefault(t.Npc) >= t.Count);
        return available ? QuestStatus.Available : QuestStatus.Locked;
    }

    internal int Progress(Quest q, Objective o)
    {
        if (!Active.TryGetValue(q.Id, out var counts)) { return Completed.Contains(q.Id) && !q.Repeatable ? o.Count : 0; }
        return Math.Min(o.Count, counts.GetValueOrDefault(o.Id));
    }

    internal bool Deliver(Quest q, string objectiveId, bool atPublisher, Func<string, int, int> take)
    {
        if ((!atPublisher && !q.Remote) || !Active.TryGetValue(q.Id, out var counts)) { return false; }
        var o = q.Objectives.FirstOrDefault(o => o.Id == objectiveId && o.Type == ObjectiveType.DeliverItem);
        if (o == null) { return false; }
        int delivered = counts.GetValueOrDefault(o.Id);
        if (delivered >= o.Count) { return false; }
        int taken = take(o.Target, o.Count - delivered);
        if (taken == 0) { return false; }
        counts[o.Id] = delivered + taken;
        return true;
    }

    internal bool Apply(QuestRules rules, Quest q, QuestAction action, bool atPublisher, Func<Quest, bool> settle)
    {
        switch (action)
        {
            case QuestAction.Accept when atPublisher && Status(rules, q) == QuestStatus.Available:
                Active.Add(q.Id, new());
                return true;
            case QuestAction.Abandon:
                return Active.Remove(q.Id);
            case QuestAction.Submit when (atPublisher || q.Remote) && Status(rules, q) == QuestStatus.Ready:
                if (!settle(q)) { return false; }
                Active.Remove(q.Id);
                Completed.Add(q.Id);
                Unlocked.UnionWith(q.Rewards.Unlock);
                Trust[q.Npc] = (int)Math.Min(int.MaxValue, (long)Trust.GetValueOrDefault(q.Npc) + q.Rewards.Trust);
                return true;
            default:
                return false;
        }
    }

    internal bool Advance(QuestRules rules, ObjectiveType type, Func<string, bool> matches, int amount = 1)
    {
        if (type == ObjectiveType.DeliverItem || amount <= 0) { return false; }
        bool changed = false;
        foreach (var (id, counts) in Active)
        {
            if (!rules.Quests.TryGetValue(id, out var q)) { continue; }
            foreach (var o in q.Objectives.Where(o => o.Type == type && matches(o.Target)))
            {
                int previous = counts.GetValueOrDefault(o.Id);
                if (previous >= o.Count) { continue; }
                counts[o.Id] = (int)Math.Min(o.Count, (long)previous + amount);
                changed = true;
            }
        }
        return changed;
    }

    internal string Write(bool snapshot = false)
    {
        static XElement Counts(string name, Dictionary<string, int> counts) =>
            new(name, counts.Select(p => new XElement("n", new XAttribute("id", p.Key), new XAttribute("v", p.Value))));
        static XElement Ids(string name, HashSet<string> ids) => new(name, ids.Select(id => new XElement("q", new XAttribute("id", id))));
        var root = new XElement("crew", new XAttribute("version", 1), new XAttribute("port", LastPort), Ids("done", Completed), Ids("unlock", Unlocked), Counts("trust", Trust),
            Active.Select(p => new XElement("quest", new XAttribute("id", p.Key), Counts("progress", p.Value))));
        if (snapshot) { root.Add(Counts("stock", Stock)); }
        return root.ToString(SaveOptions.DisableFormatting);
    }

    internal static QuestState Read(string xml)
    {
        var state = new QuestState();
        if (xml.Length == 0) { return state; }
        var root = XElement.Parse(xml);
        if (root.Name != "crew" || (int?)root.Attribute("version") != 1) { throw new FormatException("Unsupported quest state"); }
        static string Id(XElement e) => (string?)e.Attribute("id") ?? throw new FormatException("Missing state id");
        static void Counts(XElement? parent, Dictionary<string, int> target)
        {
            foreach (var e in parent?.Elements("n") ?? []) { target.Add(Id(e), Math.Max(0, (int)e.Attribute("v")!)); }
        }
        state.LastPort = (int?)root.Attribute("port") ?? -1;
        state.Completed.UnionWith(root.Element("done")?.Elements("q").Select(Id) ?? []);
        state.Unlocked.UnionWith(root.Element("unlock")?.Elements("q").Select(Id) ?? []);
        Counts(root.Element("trust"), state.Trust);
        Counts(root.Element("stock"), state.Stock);
        foreach (var e in root.Elements("quest"))
        {
            var counts = new Dictionary<string, int>();
            Counts(e.Element("progress"), counts);
            state.Active.Add(Id(e), counts);
        }
        return state;
    }
}