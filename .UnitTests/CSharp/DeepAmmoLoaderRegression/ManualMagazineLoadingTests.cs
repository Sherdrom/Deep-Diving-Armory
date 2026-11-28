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
            if (sourceId != 0) { WriteOrigin(msg); }
            loading.ServerEventRead(msg.Rewind(), sender ?? client);
        }
        void WriteOrigin(Message msg)
        {
            msg.WriteUInt16(user.ID);
            msg.WriteInt32(-1);
            msg.WriteInt32(user.Inventory.FindIndices(target).First(i => user.Inventory.SlotTypes[i] == InvSlotType.Any));
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
        user.Inventory.SlotTypes[19] = InvSlotType.RightHand;
        user.Inventory.ForceToSlot(target, 19);
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
        user.Inventory.ForceRemoveFromSlot(target, 19);
        Tick(1);
        check(!loading.IsActive && magazine.LoadedCount == 29, "putting the magazine away stops unloading");
        user.Inventory.ForceToSlot(target, 19);
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
        user.Inventory.AllItems.Clear();
        magazine.MaxSize = 100;
        packB.MaxStackSize = 3;
        bool Place(Item item, int slot) => user.Inventory.IsInSlot(item, slot) || user.Inventory.TryPutItem(item, slot, false, false, user);
        check(Place(target, 1), "place the 100-round magazine");
        user.Inventory.ForceToSlot(target, 19);
        Item[] SpawnStack()
        {
            int start = Entity.Spawner.Spawned.Count;
            for (int i = 0; i < 3; i++) { Entity.Spawner.AddItemToSpawnQueue(packB, user.Inventory); }
            Entity.Spawner.ProcessQueue();
            var packs = Entity.Spawner.Spawned.Skip(start).ToArray();
            foreach (var pack in packs) { check(Place(pack, 0), "place full 30-round package in the source stack"); }
            return packs;
        }
        void Drag(uint token, params Item[] packs)
        {
            var msg = new Message();
            msg.WriteUInt32(token);
            msg.WriteUInt16(ushort.MaxValue);
            WriteOrigin(msg);
            msg.WriteByte((byte)packs.Length);
            foreach (var pack in packs) { msg.WriteUInt16(pack.ID); }
            loading.ServerEventRead(msg.Rewind(), client);
        }
        void Advance(int count)
        {
            for (int i = 0; i < count; i++) { Tick(.4f); Entity.Spawner.ProcessQueue(); }
        }
        var packs = SpawnStack();
        Drag(20, packs[0], packs[0]);
        check(!loading.IsActive, "a batch cannot name the same package twice");
        check(Place(packs[2], 4), "move third package outside the source stack");
        Drag(21, packs);
        check(!loading.IsActive, "a batch cannot include packages from another slot");
        check(Place(packs[2], 0), "return third package to stack");
        user.Inventory.Capacity = 2;
        Drag(22, packs);
        Advance(1);
        check(!loading.IsActive && magazine.LoadedCount == 0 && packs.All(p => p.Condition == 30),
            "no room to split preserves the entire source stack");
        user.Inventory.Capacity = 20;
        packs[0].IgnoreConditionChanges = true;
        Drag(23, packs);
        Advance(1);
        packs[0].IgnoreConditionChanges = false;
        check(!loading.IsActive && magazine.LoadedCount == 0 && user.Inventory.GetItemsAt(0).Count() == 3,
            "rejected debit restores both the magazine and the split stack");
        Drag(24, packs);
        Advance(1);
        check(Place(packs[1], 4), "move a queued package during the session");
        Advance(29);
        check(!loading.IsActive && magazine.LoadedCount == 30 && packs[1].Condition == 30 && packs[2].Condition == 30,
            "a moved queued package stops the session without debiting either remaining package");
        Request(25, target.ID);
        Advance(30);
        packs = user.Inventory.AllItems.Where(p => p.Prefab == packB).ToArray();
        foreach (var pack in packs.Where(p => user.Inventory.FindIndex(p) != 0))
        { check(Place(pack, 0), "bring the three packages back to the source slot"); }
        Drag(26, packs);
        Advance(1);
        check(loading.IsActive && magazine.LoadedCount == 1 && packs[0].Condition == 29 &&
            user.Inventory.FindIndex(packs[0]) != 0 && packs.Skip(1).All(p => user.Inventory.FindIndex(p) == 0),
            "only the package being consumed moves to its own slot");
        Advance(89);
        check(!loading.IsActive && LastState() == (user.ID, 26u, 90, -1f) && packs.All(p => p.Removed),
            "one drag transfers 3 x 30 into the 100-round magazine");
        Request(27, target.ID);
        Advance(90);
        var returned = user.Inventory.AllItems.Where(i => i.Prefab == packB).ToArray();
        check(!loading.IsActive && magazine.LoadedCount == 0 && returned.Length == 3 &&
            returned.All(p => p.Condition == 30) && returned.Select(user.Inventory.FindIndex).Distinct().Count() == 1,
            "unloading the same 90 rounds produces one stack of three full packages");
        Drag(28, returned[1], returned[2]);
        Advance(60);
        check(!loading.IsActive && magazine.LoadedCount == 60 && returned[0].Condition == 30 && !returned[0].Removed,
            "dragging a subset consumes only the selected packages");
        check(Place(returned[0], 5), "set the unselected package aside");
        var extra = SpawnStack();
        Drag(29, extra);
        Advance(40);
        check(!loading.IsActive && magazine.LoadedCount == 100 && extra[0].Removed && extra[1].Condition == 20 &&
            extra[2].Condition == 30 && user.Inventory.FindIndex(extra[1]) != user.Inventory.FindIndex(extra[2]),
            "reaching capacity stops mid-package and leaves the untouched package intact");
        StackedMagazines(check);
        ItemPrefab.Prefabs.Values.Remove(packB);
    }

    private static void StackedMagazines(Action<bool, string> check)
    {
        var user = new Character { ID = 850 };
        var client = new Client { Character = user };
        var inventory = user.Inventory;
        inventory.SlotTypes[0] = InvSlotType.LeftHand;
        inventory.SlotTypes[1] = InvSlotType.RightHand;
        var prefab = new ItemPrefab("manual_mag", 851) { MaxStackSize = 5 };
        var packPrefab = new ItemPrefab("manual_pack", 852, "deep_ammopackage");
        var element = new ContentXElement(new XElement("ManualMagazineLoading"));
        ushort nextId = 853;
        VirtualizedMagazine Magazine(int index, params string[] rounds)
        {
            var item = new Item(nextId++, prefab) { MaxCondition = 2 };
            var mag = new VirtualizedMagazine(item) { MaxSize = 2 };
            var component = new ManualMagazineLoading(item, element);
            item.Components.AddRange([mag, component]);
            component.OnItemLoaded();
            mag.LoadedAmmoIdentifiersArray = rounds.Select(r => r.ToIdentifier()).ToArray();
            check(inventory.TryPutItem(item, index, false, false, user), "place test magazine");
            return mag;
        }

        Item Pack(int index, string ammo, int rounds = 1)
        {
            var item = new Item(nextId++, packPrefab) { MaxCondition = rounds, Condition = rounds };
            item.Components.Add(new VirtualizedAmmoStorage(item, new(XElement.Parse($"<Storage ProjectileIdentifier='{ammo}'/>"))));
            check(inventory.TryPutItem(item, index, false, false, user), "place test package");
            return item;
        }

        var target = Magazine(6, "a", "b");
        var loading = target.Item.GetComponent<ManualMagazineLoading>()!;
        int Position() => inventory.FindIndices(target.Item).Single(i => inventory.SlotTypes[i] == InvSlotType.Any);
        uint token = 0;
        void Start(int origin, params Item[] sources)
        {
            var msg = new Message();
            msg.WriteUInt32(++token);
            msg.WriteUInt16(sources.Length == 1 ? sources[0].ID : ushort.MaxValue);
            msg.WriteUInt16(user.ID);
            msg.WriteInt32(-1);
            msg.WriteInt32(origin);
            if (sources.Length > 1)
            {
                msg.WriteByte((byte)sources.Length);
                foreach (var source in sources) { msg.WriteUInt16(source.ID); }
            }
            loading.ServerEventRead(msg.Rewind(), client);
        }
        void Cancel()
        {
            var msg = new Message();
            msg.WriteUInt32(token);
            msg.WriteUInt16(0);
            loading.ServerEventRead(msg.Rewind(), client);
        }
        void Tick() => loading.Update(1, new Camera());

        var fullPeers = new[] { Magazine(6, "a", "b"), Magazine(6, "a", "b") };
        Magazine(2, "b", "a"); // Equal count and condition, different firing order.
        var emptyPeers = Enumerable.Range(0, 4).Select(_ => Magazine(3)).ToArray();
        var packA = Pack(4, "a");
        var packB = Pack(5, "b");
        packA.Condition = packB.Condition = 0;
        inventory.ForceToSlot(target.Item, 0);
        inventory.Capacity = 7;
        Start(6, target.Item);
        check(!loading.IsActive && target.Item.DroppedBy == null && Position() == 6 &&
            user.HasEquippedItem(target.Item, InvSlotType.LeftHand) && packB.Condition == 0 && target.LoadedCount == 2,
            "full inventory rejects held unload before any split, spawn or debit");
        inventory.Capacity = 20;
        Start(6, target.Item);
        int isolated = Position();
        check(loading.IsActive && isolated != 6 && inventory.GetItemsAt(isolated).Single() == target.Item &&
            inventory.GetItemsAt(6).SequenceEqual(fullPeers.Select(p => p.Item)) &&
            user.HasEquippedItem(target.Item, InvSlotType.LeftHand) && !user.HasEquippedItem(target.Item, InvSlotType.RightHand),
            "unloading splits x3 on Begin and retains the original left hand even when its index comes first");
        Tick();
        check(loading.IsActive && target.LoadedCount == 1 && packB.Condition == 1 && packA.Condition == 0 &&
            fullPeers.All(p => p.LoadedCount == 2) && loading.CapacityProgress == .5f, "one round changes only the isolated magazine");
        Tick();
        check(!loading.IsActive && Position() == 3 && inventory.GetItemsAt(3).Count() == 5 &&
            user.HasEquippedItem(target.Item, InvSlotType.LeftHand) && inventory.GetItemAt(isolated) == null &&
            target.LoadedCount == 0 && packA.Condition == 1 && inventory.NetworkEvents == 2,
            "empty magazine joins x4 empties, keeps the hand slot and publishes both slot moves");

        inventory.ForceRemoveFromSlot(target.Item, 0);
        inventory.Capacity = 7;
        Start(3, packA);
        check(!loading.IsActive && Position() == 3 && packA.Condition == 1 && target.Item.DroppedBy == null,
            "full inventory rejects loading before touching x5 empty magazines or the package");
        inventory.Capacity = 8; // Only the target fits; the first debit will also need to split its source.
        packA.Condition = packA.MaxCondition = 2;
        var reserve = Pack(4, "a", 2);
        Start(3, packA);
        check(loading.IsActive && Position() == 7, "the only free slot belongs to the target for the whole first round");
        Tick();
        check(!loading.IsActive && Position() == 3 && target.LoadedCount == 0 && packA.Condition == 2 && reserve.Condition == 2 &&
            inventory.GetItemsAt(4).Count() == 2, "source split failure rolls the target back and debits neither package");
        inventory.Capacity = 20;
        check(inventory.TryPutItem(reserve, 19, false, false, user), "set the spare source aside");
        packA.Condition = packA.MaxCondition = 1;
        Start(3, packA, packB);
        check(!loading.IsActive && Position() == 3, "reject an invalid multi-package drag before splitting the magazine");
        Start(3, packA);
        check(loading.IsActive && Position() != 3 && inventory.GetItemsAt(3).Count() == 4, "x5 empties split at the start of loading");
        Cancel();
        check(!loading.IsActive && Position() == 3 && inventory.GetItemsAt(3).Count() == 5 &&
            packA.Condition == 1 && target.LoadedCount == 0, "zero-round cancellation rejoins the original stack");

        // Select two equal packages out of a stack of three. Use two rounds of a to distinguish full stacks.
        var matchingFull = Magazine(8, "a", "a");
        var second = Pack(4, "a");
        var untouched = Pack(4, "a");
        Start(3, packA, second);
        isolated = Position();
        Tick();
        check(loading.IsActive && Position() == isolated && target.LoadedCount == 1 && emptyPeers.All(p => p.LoadedCount == 0) &&
            packA.Condition == 0 && second.Condition == 1 && untouched.Condition == 1, "switch selected sources without moving the target");
        Tick();
        check(!loading.IsActive && Position() == 8 && inventory.GetItemsAt(8).SequenceEqual([matchingFull.Item, target.Item]) &&
            untouched.Condition == 1 && second.Condition == 0, "full result joins only identical contents");

        inventory.ForceToSlot(target.Item, 1);
        Start(8, target.Item);
        isolated = Position();
        inventory.ForceRemoveFromSlot(target.Item, 1);
        Tick();
        check(!loading.IsActive && Position() == isolated && target.LoadedCount == 2,
            "stowing the split right-hand magazine cancels and respects the player's placement");
        inventory.ForceToSlot(target.Item, 1);
        Pack(11, "a").Condition = 0;
        Start(isolated, target.Item);
        Tick();
        Cancel();
        check(!loading.IsActive && Position() == isolated && target.LoadedCount == 1 && user.HasEquippedItem(target.Item, InvSlotType.RightHand),
            "a partial magazine stays isolated and held");
        Start(isolated, untouched);
        check(inventory.TryPutItem(target.Item, 12, false, false, user), "manually move the loading target");
        Tick();
        check(!loading.IsActive && Position() == 12 && target.LoadedCount == 1 && untouched.Condition == 1,
            "an authoritative inventory move cancels before debit and never pulls the item back");
        Start(isolated, untouched);
        check(!loading.IsActive && Position() == 12, "a late start naming the pre-move slot is rejected");
        Start(12, untouched);
        Tick();
        check(!loading.IsActive && Position() == 8 && target.LoadedCount == 2, "the correct slot can start a fresh session");

        target = emptyPeers[0];
        loading = target.Item.GetComponent<ManualMagazineLoading>()!;
        Start(3, packB);
        Tick();
        var lastA = Pack(15, "a");
        Start(Position(), lastA);
        Tick();
        check(!loading.IsActive && Position() == 2 && target.LoadedAmmoIdentifiers.Select(id => id.Value).SequenceEqual(["a", "b"]) &&
            inventory.GetItemsAt(6).Count() == 2, "equal counts and ammo types with reversed feed order cannot merge");

        target = emptyPeers[3];
        loading = target.Item.GetComponent<ManualMagazineLoading>()!;
        var partialPeer = Magazine(12, "b");
        var oneB = Pack(14, "b");
        Start(3, oneB);
        Tick();
        check(!loading.IsActive && Position() == 12 && inventory.GetItemsAt(12).SequenceEqual([partialPeer.Item, target.Item]),
            "identical partial magazines can rejoin without mixing different rounds or conditions");
        var oneA = Pack(18, "a");
        Start(12, oneA);
        Cancel();
        check(!loading.IsActive && Position() == 12 && oneA.Condition == 1, "zero-round rollback also restores a partial stack");

        var bag = new Item(nextId++, new ItemPrefab("bag", 900));
        var container = new ItemContainer(bag, 1);
        bag.Components.Add(container);
        bag.OwnInventory = container.Inventory;
        container.Inventory.Container = container;
        container.Inventory.Owner = bag;
        check(inventory.TryPutItem(bag, 16, false, false, user), "place carried bag");
        target = emptyPeers[1];
        loading = target.Item.GetComponent<ManualMagazineLoading>()!;
        check(container.Inventory.TryPutItem(target.Item, 0, false, false, user) &&
            container.Inventory.TryPutItem(emptyPeers[2].Item, 0, false, false, user), "place two empty magazines in a one-slot bag");
        var fromBag = new Message();
        fromBag.WriteUInt32(++token);
        fromBag.WriteUInt16(Pack(17, "a").ID);
        fromBag.WriteUInt16(bag.ID);
        fromBag.WriteInt32(0);
        fromBag.WriteInt32(0);
        loading.ServerEventRead(fromBag.Rewind(), client);
        check(loading.IsActive && target.Item.ParentInventory == inventory &&
            container.Inventory.GetItemsAt(0).Single() == emptyPeers[2].Item, "full source bag splits into a free hotbar slot");
        Cancel();
        check(!loading.IsActive && target.Item.ParentInventory == container.Inventory &&
            container.Inventory.GetItemsAt(0).Count() == 2, "zero-round cancellation prefers the original bag over other matching empties");
    }
}
