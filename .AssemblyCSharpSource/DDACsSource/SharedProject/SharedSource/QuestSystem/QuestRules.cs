using System.Globalization;
using System.Xml.Linq;

namespace DeepDivingArmory.Quests;

internal enum ObjectiveType { DeliverItem, KillTag, ReachLocation, Custom }
internal enum QuestStatus { Locked, Available, Active, Ready, Completed }
internal enum QuestAction : byte { Sync, Accept, Abandon, Submit, Deliver }
internal sealed record Publisher(string Id, string Identifier, string[] Tags, string Texture, string SourceRect, string Color, string Faction);
internal sealed record Objective(string Id, ObjectiveType Type, string Target, int Count);
internal sealed record TrustRequirement(string Npc, int Count);
internal sealed record ItemAmount(string Id, int Count);
internal sealed record Rewards(int Marks, int Trust, IReadOnlyDictionary<string, int> Reputation, ItemAmount[] Items, string[] Unlock);
internal sealed record Quest(string Id, string Npc, string Category, bool Repeatable, bool Remote,
    string[] Requires, TrustRequirement[] Trust, Objective[] Objectives, Rewards Rewards);

internal sealed class QuestRules
{
    internal readonly Dictionary<string, Publisher> Npcs = new();
    internal readonly Dictionary<string, Quest> Quests = new();

    internal static QuestRules Load(string directory)
    {
        var files = Directory.EnumerateFiles(directory, "quests*.xml", new EnumerationOptions
            { MatchCasing = MatchCasing.CaseInsensitive, AttributesToSkip = 0, IgnoreInaccessible = false })
            .Where(path => Path.GetFileName(path).Equals("quests.xml", StringComparison.OrdinalIgnoreCase) ||
                Path.GetFileName(path).StartsWith("quests_", StringComparison.OrdinalIgnoreCase))
            .OrderBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase).ThenBy(Path.GetFileName, StringComparer.Ordinal).ToArray();
        if (files.Length == 0) { throw new FormatException($"{directory}: no quests.xml or quests_*.xml"); }
        return Parse(XElement.Load(Path.Combine(directory, "npcs.xml")), files.Select(path =>
        {
            try { return XElement.Load(path, LoadOptions.SetBaseUri); }
            catch (System.Xml.XmlException ex) { throw new FormatException($"{Path.GetFileName(path)}: {ex.Message}", ex); }
        }).ToArray());
    }

    internal static QuestRules Parse(XElement npcs, params XElement[] questFiles)
    {
        var rules = new QuestRules();
        static string Attr(XElement e, string key) => ((string?)e.Attribute(key) ?? "").Trim();
        static string Required(XElement e, string key) => Attr(e, key) is { Length: > 0 } value ? value :
            throw new FormatException($"Missing {key} on {e.Name}");
        static string[] Split(string value) => value.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        static int Number(XElement e, string name, int fallback = 0, int min = 0, int max = int.MaxValue)
        {
            int value = (int?)e.Attribute(name) ?? fallback;
            return value >= min && value <= max ? value : throw new FormatException($"Invalid {name} on {e}");
        }
        if (npcs.Name != "Npcs") { throw new FormatException("npcs.xml: expected <Npcs>"); }
        if (questFiles.Length == 0) { throw new FormatException("Expected quests.xml or quests_*.xml"); }
        foreach (var n in npcs.Elements("Npc"))
        {
            var npc = new Publisher(Required(n, "id"), Attr(n, "npcIdentifier"), Split(Attr(n, "tags")),
                Attr(n, "texture"), Attr(n, "sourcerect"), Attr(n, "color"), Required(n, "faction"));
            if (npc.Identifier == "" && npc.Tags.Length == 0) { throw new FormatException($"No NPC match on {npc.Id}"); }
            rules.Npcs.Add(npc.Id, npc);
        }
        var sources = new Dictionary<string, string>();
        IEnumerable<XElement> QuestElements()
        {
            for (int i = 0; i < questFiles.Length; i++)
            {
                var file = questFiles[i];
                string name = file.BaseUri.Length > 0 ? Path.GetFileName(new Uri(file.BaseUri).LocalPath) : $"questFiles[{i}]";
                if (file.Name != "Quests") { throw new FormatException($"{name}: expected <Quests>, found <{file.Name}>"); }
                foreach (var q in file.Elements("Quest"))
                {
                    string id = Required(q, "id");
                    if (!sources.TryAdd(id, name)) { throw new FormatException($"{name}: duplicate quest '{id}' (also in {sources[id]})"); }
                    yield return q;
                }
            }
        }

        foreach (var q in QuestElements())
        {
            string id = Required(q, "id"), npc = Required(q, "npc"), category = Required(q, "category");
            var pre = q.Element("Prerequisites");
            var rewards = q.Element("Rewards") ?? new XElement("Rewards");
            var objectives = q.Element("Objectives")?.Elements().Select(o =>
            {
                string kind = (string?)o.Attribute("type") ?? o.Name.LocalName;
                if (!Enum.TryParse<ObjectiveType>(kind, true, out var type) || !Enum.IsDefined(type)) { throw new FormatException($"Unknown objective {kind}"); }
                return new Objective(Required(o, "id"), type, Required(o, "target"), Number(o, "count", 1, 1, 65535));
            }).ToArray() ?? [];
            if (!rules.Npcs.ContainsKey(npc) || category is not ("chain" or "main" or "repeat" or "bounty") ||
                objectives.Length == 0 || objectives.Select(o => o.Id).Distinct().Count() != objectives.Length)
            { throw new FormatException($"Invalid publisher, category or objectives on {id}"); }
            rules.Quests.Add(id, new Quest(id, npc, category, (bool?)q.Attribute("repeatable") ?? false,
                (bool?)q.Attribute("allowRemoteTurnIn") ?? false,
                pre?.Elements("RequireQuest").Select(e => Required(e, "id")).ToArray() ?? [],
                pre?.Elements("RequireTrust").Select(e => new TrustRequirement((string?)e.Attribute("npc") ?? npc, Number(e, "count", 0, 1))).ToArray() ?? [],
                objectives, new Rewards(Number(rewards, "marks"), Number(rewards, "trust"), ReputationChanges(rewards, rules.Npcs[npc].Faction, id),
                    rewards.Elements("Item").Select(e => new ItemAmount(Required(e, "id"), Number(e, "count", 1, 1, 255))).ToArray(),
                    Split(Attr(rewards, "unlock")))));
        }
        foreach (var q in rules.Quests.Values)
        {
            foreach (var id in q.Requires.Concat(q.Rewards.Unlock))
            {
                if (!rules.Quests.ContainsKey(id)) { throw new FormatException($"{sources[q.Id]}: unknown quest '{id}' referenced by '{q.Id}'"); }
            }
            if (q.Trust.Any(t => !rules.Npcs.ContainsKey(t.Npc))) { throw new FormatException($"Unknown trust prerequisite on {q.Id}"); }
        }
        return rules;
    }

    private static Dictionary<string, int> ReputationChanges(XElement rewards, string publisherFaction, string quest)
    {
        var totals = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        if (rewards.Attribute("reputation") is { } legacy)
        {
            if (!int.TryParse(legacy.Value, CultureInfo.InvariantCulture, out int amount)) { throw new FormatException($"Invalid reputation '{legacy.Value}' on {quest}"); }
            totals[publisherFaction] = amount;
        }
        foreach (var entry in rewards.Elements("Reputation"))
        {
            string faction = ((string?)entry.Attribute("faction") ?? publisherFaction).Trim();
            if (faction.Length == 0 || !int.TryParse((string?)entry.Attribute("amount"), CultureInfo.InvariantCulture, out int amount) || amount is 0 or < -100 or > 100)
            { throw new FormatException($"Invalid reputation on {quest}: {entry} (expected a faction and a nonzero amount from -100 to 100)"); }
            totals[faction] = totals.GetValueOrDefault(faction) + amount;
        }
        if (totals.Values.Any(v => v is < int.MinValue or > int.MaxValue)) { throw new FormatException($"Reputation sum out of range on {quest}"); }
        return totals.Where(p => p.Value != 0).ToDictionary(p => p.Key.ToLowerInvariant(), p => (int)p.Value, StringComparer.OrdinalIgnoreCase);
    }
}

internal sealed class QuestText(Func<string, string> lookup, Func<string, string> itemName)
{
    private string Get(string key, string fallback = "") =>
        lookup("dda.quest." + key) is { Length: > 0 } value ? value : fallback;
    internal string Ui(string key) => Get("ui." + key, key);
    internal string Title(string id) => Get(id + ".title", id);
    internal string Field(string id, string field) => Get(id + "." + field);
    internal string Npc(string id, string field) => Get("npc." + id + "." + field, field == "name" ? id : "");
    internal string Objective(Quest q, Objective o)
    {
        string value = Get(q.Id + ".obj." + o.Id);
        if (value.Length > 0) { return value; }
        string target = o.Type == ObjectiveType.DeliverItem ? itemName(o.Target) : o.Target;
        return Ui("obj." + o.Type.ToString().ToLowerInvariant()).Replace("[target]", target);
    }
}