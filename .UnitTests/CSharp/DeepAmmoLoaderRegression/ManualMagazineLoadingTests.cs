using System.Xml.Linq;
using DDA.AmmoLoading;
using VCE_VirtualizedMagazine;

internal static class ManualMagazineLoadingTests
{
    internal static void Run(Action<bool, string> check)
    {
        var user = new Character { ID = 501 };
        var client = new Client { Character = user };
        var prefab = new ItemPrefab("test_package", 700, "deep_ammopackage");
        var source = new Item(502, prefab) { ParentInventory = user.Inventory, Condition = 8 };
        var stackMate = new Item(503, prefab) { ParentInventory = user.Inventory, Condition = 30 };
        var target = new Item(504, prefab) { ParentInventory = user.Inventory };
        var magazine = new VirtualizedMagazine(target);
        var element = new ContentXElement(new XElement("ManualMagazineLoading"));
        var loading = new ManualMagazineLoading(target, element);
        target.Components.AddRange([magazine, loading]);
        var storage = new VirtualizedAmmoStorage(source, new(XElement.Parse("<Storage ProjectileIdentifier='a' />")));
        source.Components.Add(storage);
        user.Inventory.AllItems.AddRange([source, stackMate, target]);
        loading.OnItemLoaded();
        List<Identifier> initial = Enumerable.Repeat("b".ToIdentifier(), 12).ToList();
        magazine.LoadAmmoArray(ref initial);

        void Request(uint id, ushort sourceId, Client? sender = null)
        {
            var msg = new Message();
            msg.WriteUInt32(id);
            msg.WriteUInt16(sourceId);
            loading.ServerEventRead(msg.Rewind(), sender ?? client);
        }
        (ushort User, uint Token, int Loaded, float Seconds) LastState()
        {
            var msg = new Message();
            loading.ServerEventWrite(msg, client, new NetEntityEvent.Wrapper(target.Events[^1]));
            msg.Rewind();
            return (msg.ReadUInt16(), msg.ReadUInt32(), msg.ReadInt32(), msg.ReadSingle());
        }
        void Tick(float seconds) => loading.Update(seconds, new Camera());

        Request(1, source.ID);
        check(LastState() == (user.ID, 1u, 12, 1f), "manual load starts at the existing count with skill 0");
        check(loading.CapacityProgress == 12f / 30, "ring starts at the existing count");
        user.WeaponsSkill = 50;
        Tick(0.9f);
        check(loading.CapacityProgress == 12f / 30, "ring holds still between completed rounds");
        check(source.Condition == 8 && magazine.LoadedCount == 12, "partially timed round consumes nothing");
        Tick(0.1f);
        check(loading.CapacityProgress == 13f / 30, "one completed round advances the ring by one step");
        check(magazine.LoadedCount == 13 && source.Condition == 7 && Math.Abs(LastState().Seconds - .7f) < .00001,
            "each new round reads the effective skill");
        Request(2, 0);
        Request(1, 0, new Client { Character = new Character() });
        check(loading.IsActive, "stale and foreign cancellations do not interrupt the owner");
        Tick(.35f);
        Request(1, 0);
        Tick(1f);
        check(!loading.IsActive && magazine.LoadedCount == 13 && source.Condition == 7, "stop preserves finished rounds only");

        Request(1, source.ID);
        check(!loading.IsActive, "repeating a completed request cannot restart the timer");
        user.WeaponsSkill = 150;
        Request(3, source.ID);
        check(Math.Abs(LastState().Seconds - .4f) < .00001, "skill above 100 uses 0.4 seconds");
        for (int i = 0; i < 7; i++) { Tick(.4f); }
        check(!loading.IsActive && LastState() == (user.ID, 3u, 20, -1f) && source.IsInRemoveQueue &&
            stackMate.Condition == 30 && source.StatusEvents == 8 && magazine.LoadedAmmoIdentifiers.Take(8).All(id => id.Value == "a"),
            "eight from the chosen package reach 20/30 and keep the original feed order");
        check(loading.CapacityProgress == 20f / 30, "empty source must not fill the ring");

        source.IsInRemoveQueue = false;
        source.Condition = 20;
        Request(4, source.ID);
        user.Inventory.AllItems.Reverse();
        Tick(1);
        check(!loading.IsActive && source.Condition == 20 && magazine.LoadedCount == 20, "moving a slot cancels before debit");
        Request(5, source.ID);
        source.IgnoreConditionChanges = true;
        Tick(1);
        source.IgnoreConditionChanges = false;
        check(!loading.IsActive && magazine.LoadedCount == 20 && source.Condition == 20, "rejected debit rolls back the append");
        Request(6, source.ID);
        magazine.ThrowOnRefresh = true;
        Tick(1);
        magazine.ThrowOnRefresh = false;
        check(!loading.IsActive && magazine.LoadedCount == 20 && source.Condition == 20, "VCE exception cannot duplicate ammunition");
        source.ParentInventory = new Character().Inventory;
        Request(7, source.ID);
        check(!loading.IsActive, "foreign source rejected by server");
        source.ParentInventory = user.Inventory;
        storage.AmmoIdentifier = "wrong".ToIdentifier();
        Request(8, source.ID);
        check(!loading.IsActive && source.Condition == 20, "wrong caliber rejected");
        storage.AmmoIdentifier = "a".ToIdentifier();
        Request(9, source.ID);
        client.InGame = false;
        Tick(1);
        check(!loading.IsActive && source.Condition == 20, "disconnect stops the timer before debit");
        client.InGame = true;
        Request(10, source.ID);
        for (int i = 0; i < 9; i++) { Tick(.4f); }
        Tick(.39f);
        check(loading.CapacityProgress == 29f / 30, "ring holds at 29/30 until the final round is loaded");
        Tick(.02f);
        check(!loading.IsActive && magazine.LoadedCount == 30 && source.Condition == 10 &&
            loading.CapacityProgress == 1, "only a full magazine fills the ring");
        Request(11, source.ID);
        check(!loading.IsActive, "full magazine rejects a new drag");

        Request(12, target.ID);
        check(!loading.IsActive, "a backpack magazine cannot be manually unloaded");
        user.HeldItem = target;
        Request(13, target.ID);
        Tick(.39f);
        check(loading.CapacityProgress == 1 && source.Condition == 10, "starting unload keeps the full ring until one round completes");
        Tick(.02f);
        check(loading.CapacityProgress == 29f / 30 && source.Condition == 11 && LastState().Loaded == 29,
            "one tick credits one matching package and reduces the ring by one");
        Request(13, 0);
        Tick(2);
        check(!loading.IsActive && source.Condition == 11 && magazine.LoadedCount == 29, "stop preserves the unprocessed rounds");
        Request(14, target.ID);
        user.HeldItem = null;
        Tick(1);
        check(!loading.IsActive && magazine.LoadedCount == 29, "putting the magazine away stops unloading");
        user.HeldItem = target;
        Request(15, target.ID);
        source.IgnoreConditionChanges = true;
        Tick(1);
        source.IgnoreConditionChanges = false;
        check(!loading.IsActive && source.Condition == 11 && magazine.LoadedCount == 29, "rejected package credit restores the magazine");

        magazine.LoadedAmmoIdentifiers.Clear();
        magazine.LoadedAmmoIdentifiersArray = ["a".ToIdentifier(), "b".ToIdentifier(), "a".ToIdentifier()];
        var packB = new ItemPrefab("manual_pack_b", 701, "deep_ammopackage") { Health = 30,
            ConfigElement = new(XElement.Parse("<Item><VirtualizedAmmoStorage ProjectileIdentifier='b'/></Item>")) };
        ItemPrefab.Prefabs.Values.Add(packB);
        Request(16, target.ID);
        Tick(.4f);
        Tick(.4f);
        check(source.Condition == 12 && magazine.LoadedCount == 2 && Entity.Spawner.Pending.Count == 1,
            "mixed magazine returns the top round first and waits for a new matching package");
        Request(16, 0);
        Request(17, target.ID);
        Entity.Spawner.ProcessQueue();
        check(magazine.LoadedCount == 2 && loading.IsActive && !user.Inventory.AllItems.Any(i => i.Prefab == packB),
            "canceled spawn cannot mint a round or interrupt a later session");
        Tick(.4f);
        user.Inventory.RejectInsertion = true;
        Entity.Spawner.ProcessQueue();
        user.Inventory.RejectInsertion = false;
        check(!loading.IsActive && magazine.LoadedCount == 2 && !user.Inventory.AllItems.Any(i => i.Prefab == packB),
            "failed insertion leaves the next round in the magazine");
        Request(18, target.ID);
        Tick(.4f);
        user.Inventory.Capacity = user.Inventory.AllItems.Count;
        Entity.Spawner.ProcessQueue();
        Tick(.4f);
        check(!loading.IsActive && magazine.LoadedCount == 2, "full inventory cancels even when the spawn callback is skipped");
        user.Inventory.Capacity = 20;
        Request(19, target.ID);
        Tick(.4f);
        Tick(.4f);
        check(Entity.Spawner.Pending.Count == 1, "delayed spawning only enqueues one package");
        Entity.Spawner.ProcessQueue();
        check(user.Inventory.AllItems.Single(i => i.Prefab == packB).Condition == 1 &&
            magazine.LoadedCount == 1 && loading.CapacityProgress == 1f / 30, "new package receives exactly its first round");
        Tick(.4f);
        check(!loading.IsActive && LastState() == (user.ID, 19u, 0, -1f) && loading.CapacityProgress == 0 &&
            source.Condition == 13, "mixed magazine ends empty, with all three rounds accounted for");
        ItemPrefab.Prefabs.Values.Remove(packB);
    }
}
