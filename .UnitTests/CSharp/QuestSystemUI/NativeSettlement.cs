extern alias server;
using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Xml.Linq;
using S = server::Barotrauma;

[assembly: IgnoresAccessChecksTo("DedicatedServer")]

internal static class NativeSettlement
{
    internal static void Verify(Assembly plugin)
    {
        const BindingFlags flags = BindingFlags.Static | BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        static T Fixture<T>() => (T)RuntimeHelpers.GetUninitializedObject(typeof(T));
        var campaign = Fixture<S.MultiPlayerCampaign>();
        var metadata = new S.CampaignMetadata();
        var coalition = Faction("coalition");
        var separatists = Faction("separatists");
        S.Faction Faction(string id) => new(metadata, new S.FactionPrefab(new S.ContentXElement(null,
            new XElement("Faction", new XAttribute("identifier", id))), null!));
        typeof(S.CampaignMode).GetField("factions", flags)!.SetValue(campaign,
            new Dictionary<Barotrauma.Identifier, S.Faction> { [coalition.Prefab.Identifier] = coalition, [separatists.Prefab.Identifier] = separatists });
        campaign.Map = Fixture<S.Map>();
        campaign.Map.CurrentLocation = Fixture<S.Location>();
        campaign.Map.CurrentLocation.Faction = coalition;
        var actor = Fixture<S.Character>();
        actor.Inventory = Fixture<S.CharacterInventory>();
        S.Entity.Spawner = Fixture<S.EntitySpawner>();
        var runtime = plugin.GetType("DeepDivingArmory.Quests.QuestRuntime", true)!;
        var parse = plugin.GetType("DeepDivingArmory.Quests.QuestRules", true)!.GetMethod("Parse", flags)!;
        runtime.GetField("campaign", flags)!.SetValue(null, campaign);
        bool Settle(string extra)
        {
            var quests = XElement.Parse($"<Quests><Quest id='q' npc='n' category='main'><Objectives><Custom id='x' target='x'/></Objectives>" +
                $"<Rewards reputation='-5'><Reputation faction='coalition' amount='8'/><Reputation faction='separatists' amount='-2'/>{extra}</Rewards></Quest></Quests>");
            var rules = parse.Invoke(null, [XElement.Parse("<Npcs><Npc id='n' tags='chief' faction='location'/></Npcs>"), new[] { quests }])!;
            var entries = (IDictionary)rules.GetType().GetField("Quests", flags)!.GetValue(rules)!;
            return (bool)runtime.GetMethod("Settle", flags)!.Invoke(null, [entries["q"], actor])!;
        }
        coalition.Reputation.SetReputation(-99);
        if (Settle("<Reputation faction='missing' amount='1'/>") || coalition.Reputation.Value != -99 || separatists.Reputation.Value != 0)
        { throw new Exception("Unregistered faction must reject the whole payout"); }
        if (!Settle("") || coalition.Reputation.Value != -96 || separatists.Reputation.Value != -2)
        { throw new Exception("Signed dedicated-server settlement and location alias at the native cap"); }
        var save = new XElement("campaign");
        metadata.Save(save);
        var restored = new S.CampaignMetadata();
        restored.Load(XElement.Parse(save.ToString()).Element("Metadata")!);
        if (new S.Faction(restored, coalition.Prefab).Reputation.Value != -96 || new S.Faction(restored, separatists.Prefab).Reputation.Value != -2)
        { throw new Exception("Dedicated-server faction save/load"); }
        runtime.GetField("campaign", flags)!.SetValue(null, null);
        S.Entity.Spawner = null;
        Console.WriteLine("PASS deployed server signed settlement, alias merge, all-or-nothing validation and native metadata reload");
    }
}
