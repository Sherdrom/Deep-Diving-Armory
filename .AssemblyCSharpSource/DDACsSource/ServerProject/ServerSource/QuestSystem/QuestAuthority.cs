namespace DeepDivingArmory.Quests;

public static partial class QuestRuntime
{
    private static bool CanDeliver(Item item)
    {
        if (item.Removed || item.IdFreed || item.IsInRemoveQueue || item.Condition <= 0 || item.OwnInventories.Any(i => i.AllItems.Any())) { return false; }
        var owner = item.GetRootInventoryOwner();
        return owner is Character c ? c.IsOnPlayerTeam && !c.IsDead :
            owner.Submarine != null && owner.Submarine == Submarine.MainSub;
    }

    private static bool RefreshStock()
    {
        var targets = State.Active.Keys.Where(Rules.Quests.ContainsKey).SelectMany(id => Rules.Quests[id].Objectives)
            .Where(o => o.Type == ObjectiveType.DeliverItem).Select(o => o.Target).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        if (targets.Count > 0)
        {
            foreach (var item in Item.ItemList)
            {
                string id = item.Prefab.Identifier.Value;
                if (targets.Contains(id) && CanDeliver(item)) { counts[id] = counts.GetValueOrDefault(id) + 1; }
            }
        }
        if (counts.Count == State.Stock.Count && counts.All(p => State.Stock.GetValueOrDefault(p.Key) == p.Value)) { return false; }
        State.Stock.Clear();
        foreach (var pair in counts) { State.Stock.Add(pair.Key, pair.Value); }
        return true;
    }

    private static int TakeItems(string target, int remaining, Character actor)
    {
        if (Entity.Spawner is not { } spawner) { return 0; }
        var items = Item.ItemList.Where(i => i.Prefab.Identifier == target && CanDeliver(i))
            .OrderByDescending(i => i.GetRootInventoryOwner() == actor).ThenBy(i => i.ID).Take(remaining);
        int taken = 0;
        foreach (var item in items)
        {
            spawner.AddEntityToRemoveQueue(item);
            if (item.IsInRemoveQueue) { taken++; }
        }
        return taken;
    }

    private static bool Settle(Quest q, Character actor)
    {
        var spawner = Entity.Spawner;
        if (spawner == null || actor.Inventory == null || campaign == null) { return false; }
        var changes = new Dictionary<Reputation, long>();
        foreach (var (id, amount) in q.Rewards.Reputation)
        {
            if (campaign.GetMatchingFaction(id.ToIdentifier())?.Reputation is not { } reputation) { return false; }
            // "location" can resolve to another faction named in the same reward.
            changes[reputation] = changes.GetValueOrDefault(reputation) + amount;
        }
        var rewards = q.Rewards.Items.Select(r => (Prefab: ItemPrefab.FindByIdentifier(r.Id.ToIdentifier()) as ItemPrefab, r.Count)).ToArray();
        if (rewards.Any(r => r.Prefab == null)) { return false; }
        if (q.Rewards.Marks > 0) { campaign.Bank.Give(q.Rewards.Marks); }
        foreach (var (reputation, amount) in changes)
        {
            if (amount != 0) { reputation.AddReputation(amount); }
        }
        foreach (var reward in rewards)
        {
            for (int i = 0; i < reward.Count; i++) { spawner.AddItemToSpawnQueue(reward.Prefab, actor.Inventory); }
        }
        return true;
    }

    internal static bool Handle(QuestRequest req, Character? actor, bool preview = false)
    {
        if (!Authority || actor is not { IsDead: false, Removed: false, IsOnPlayerTeam: true } || actor.IsIncapacitated ||
            GameMain.GameSession is not { IsRunning: true, Campaign: { } mode } || !EnsureCampaign(mode) || req.Round != Round || req.Revision != Revision ||
            req.Quest == null || !Rules.Quests.TryGetValue(req.Quest, out var q)) { return false; }
        var speaker = Entity.FindEntityByID(req.Speaker) as Character;
        bool atPublisher = (preview && GameMain.IsSingleplayer) || (Match(speaker)?.Id == q.Npc && InReach(actor, speaker!));
        var action = (QuestAction)req.Action;
        bool changed = action == QuestAction.Deliver
            ? State.Deliver(q, req.ObjectiveId, atPublisher, (target, remaining) => TakeItems(target, remaining, actor))
            : State.Apply(Rules, q, action, atPublisher, quest => Settle(quest, actor));
        bool stockChanged = RefreshStock();
        if (changed || stockChanged) { Changed(changed); }
        return changed;
    }
}