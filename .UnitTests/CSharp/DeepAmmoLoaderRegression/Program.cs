using System.Xml.Linq;
using VCE_VirtualizedMagazine;
using DDA.AmmoLoading;

int checks = 0;
void Check(bool condition, string message)
{
    checks++;
    if (!condition) { throw new Exception(message); }
}
Dictionary<string, int> Amount(string id, int count) => new() { [id] = count };

var stock = new AmmoStock();
Check(stock.TryAdd(Amount("a", 120)) && stock.TryAdd(Amount("b", 24)), "package deposit");
Check(stock["A"] == 120, "case-insensitive identity");
Check(!stock.TryAdd(Amount("a", -1)), "negative deposit");
Check(!stock.TryTake(new Dictionary<string, int> { ["a"] = 1, ["b"] = 25 }), "reject entire insufficient plan");
Check(stock["a"] == 120 && stock["b"] == 24, "failed plan must not deduct");
Check(!stock.TryTake(new Dictionary<string, int> { ["a"] = 100, ["A"] = 100 }), "case alias double debit");
Check(!stock.TryAdd(new Dictionary<string, int> { ["a"] = int.MaxValue - 120, ["A"] = 1 }), "case alias overflow");

AmmoRun[] plan = [new("a", 2), new("b", 1), new("a", 1)];
Check(AmmoPlan.IsValid(plan, 30), "valid mixed plan");
Check(!AmmoPlan.IsValid(plan, 3), "capacity limit");
Check(!AmmoPlan.IsValid([new("a", int.MaxValue), new("b", int.MaxValue)], 30), "count overflow");
Check(!AmmoPlan.IsValid([null!], 30), "malformed preset");
Check(!AmmoPlan.IsValid(Enumerable.Repeat(new AmmoRun("a", 1), 97).ToArray(), 4096), "network group limit");
var feedOrder = AmmoPlan.Expand(plan).ToArray();
var magazine = new Stack<string>(feedOrder.Reverse());
Check(magazine.SequenceEqual(new[] { "a", "a", "b", "a" }), "top-first plan must survive bottom-first insertion");
Check(stock.TryTake(AmmoStock.Count(feedOrder)), "load deduction");
Check(stock["a"] == 117 && stock["b"] == 23, "exact mixed debit");
Check(stock.TryAdd(AmmoStock.Count(magazine)), "unload return");
magazine.Clear();
Check(stock["a"] == 120 && stock["b"] == 24, "load/unload conservation");
Check(AmmoPlan.Compact(new[] { "a", "A", "b", "a" }).SequenceEqual(plan), "merge only adjacent identical rounds");

Check(stock.TryAdd(Amount("missing_mod_round", 7)), "unknown mod identifiers retained");
var saved = stock.Save();
stock.Load(saved);
stock.Load(saved);
Check(stock["a"] == 120 && stock["missing_mod_round"] == 7, "save/load idempotence and missing mods");
try
{
    stock.Load(XElement.Parse("<Stock><Ammo id='a' count='1'/><Ammo id='A' count='2'/></Stock>"));
    Check(false, "duplicate saved identity accepted");
}
catch (FormatException) { Check(stock["a"] == 120, "bad save must not replace stock"); }
var full = new AmmoStock();
Check(full.TryAdd(Amount("a", int.MaxValue)), "max stock");
Check(!full.TryAdd(new Dictionary<string, int> { ["b"] = 1, ["a"] = 1 }) && full["b"] == 0, "atomic overflow rejection");

var random = new Random(41);
for (int trial = 0; trial < 1000; trial++)
{
    string[] sequence = Enumerable.Range(0, random.Next(1, 100)).Select(_ => random.Next(2) == 0 ? "a" : "b").ToArray();
    var compact = AmmoPlan.Compact(sequence);
    Check(AmmoPlan.Expand(compact).SequenceEqual(sequence), "mixed run roundtrip");
    var demand = AmmoStock.Count(sequence);
    var before = stock.Save().ToString();
    if (stock.TryTake(demand))
    {
        Check(stock.TryAdd(demand), "refund after successful debit");
    }
    Check(stock.Save().ToString() == before, "random load/unload conservation");
}
Console.WriteLine($"Ammo loader regression: {checks} checks passed.");

var bulletA = new ItemPrefab("a", 1, "compatible");
var bulletB = new ItemPrefab("b", 2, "compatible");
var wrongBullet = new ItemPrefab("wrong", 3, "different");
ItemPrefab.Prefabs.Values.AddRange([bulletA, bulletB, wrongBullet]);
ManualMagazineLoadingTests.Run(Check);
var player = new Character();
var client = new Client { Character = player };
var machine = new Item(10, bulletA);
var intake = new ItemContainer(machine, 6);
var targetSlot = new ItemContainer(machine, 1);
var loader = new DeepAmmoLoader(machine, new(new XElement("DeepAmmoLoader"))) { TargetContainerIndex = 1 };
machine.Components.AddRange([intake, targetSlot, loader]);
loader.OnItemLoaded();
var magItem = new Item(20, bulletA);
var mag = new VCE_VirtualizedMagazine.VirtualizedMagazine(magItem);
magItem.Components.Add(mag);
magItem.ParentInventory = player.Inventory;
var packItem = new Item(30, bulletA) { Condition = 120, MaxCondition = 120 };
var pack = new VirtualizedAmmoStorage(packItem, new(XElement.Parse("<VirtualizedAmmoStorage ProjectileIdentifier='a' />")));
packItem.Components.Add(pack);
intake.Inventory.AllItems.Add(packItem);
loader.Update(1, new Camera());
Check(loader.Stock["a"] == 120 && packItem.Condition == 0 && packItem.IsInRemoveQueue, "deposit drains VCE storage before deletion");
packItem.IsInRemoveQueue = false;
loader.Update(1, new Camera());
Check(loader.Stock["a"] == 120 && packItem.IsInRemoveQueue, "queued/saved package cannot redeem twice");

uint Revision() => loader.StateRevision;
void Send(byte command, uint rev, ushort target, bool allowed = true, params (uint Id, ushort Count)[] groups)
{
    client.Allowed = allowed;
    SendAs(client, command, rev, target, groups);
}
void SendAs(Client sender, byte command, uint rev, ushort target, params (uint Id, ushort Count)[] groups)
{
    var msg = new Message();
    msg.WriteByte(command); msg.WriteUInt32(rev); msg.WriteUInt16(target); msg.WriteByte((byte)groups.Length);
    foreach (var group in groups) { msg.WriteUInt32(group.Id); msg.WriteUInt16(group.Count); }
    loader.ServerEventRead(msg.Rewind(), sender);
    Timing.TotalTime++;
}
loader.Stock.TryAdd(Amount("b", 24));
{
    var carrier = new Character();
    var sender = new Client { Character = carrier };
    ushort nextId = 900;
    Item Store(Inventory inventory, int slot, ItemPrefab prefab, float condition = 100)
    {
        var item = new Item(nextId++, prefab) { Condition = condition };
        Check(inventory.TryPutItem(item, slot, false, false, carrier), "place batch fixture");
        return item;
    }
    VirtualizedMagazine Magazine(Inventory inventory, int slot, ItemPrefab prefab)
    {
        var item = Store(inventory, slot, prefab, condition: 0);
        var component = new VirtualizedMagazine(item) { MaxSize = 20 };
        item.Components.Add(component);
        return component;
    }
    ItemContainer Container(Item item, int capacity)
    {
        var container = new ItemContainer(item, capacity);
        container.Inventory.Owner = item;
        item.Components.Add(container);
        return container;
    }
    var bagItem = Store(carrier.Inventory, 0, bulletB);
    var bag = Container(bagItem, 3);
    var belt = Container(Store(bag.Inventory, 0, bulletB), 2);
    var firstEmpty = Magazine(belt.Inventory, 0, bulletA);
    var lastEmpty = Magazine(belt.Inventory, 1, bulletA);
    var selected = Magazine(carrier.Inventory, 1, bulletA);
    selected.LoadedAmmoIdentifiersArray = ["a".ToIdentifier()];
    var partial = Magazine(carrier.Inventory, 2, bulletA);
    partial.LoadedAmmoIdentifiersArray = ["a".ToIdentifier()];
    var otherModel = Magazine(bag.Inventory, 1, bulletB);
    var gun = Store(bag.Inventory, 2, bulletB);
    gun.Components.Add(new RangedWeapon(gun, new(new XElement("RangedWeapon"))));
    var inserted = Magazine(Container(gun, 1).Inventory, 0, bulletA);
    var crewMate = new Character();
    var theirs = Magazine(crewMate.Inventory, 0, bulletA);
    var start = Revision();
    SendAs(sender, 4, start, selected.Item.ID, (2, 10));
    Check(selected.LoadedCount == 11 && firstEmpty.LoadedCount == 10 && lastEmpty.LoadedCount == 0 && loader.Stock["b"] == 4,
        "batch applies one plan per magazine, selected first, then nested empties, and stops before a partial debit");
    Check(partial.LoadedCount == 1 && otherModel.LoadedCount == 0 && inserted.LoadedCount == 0 && theirs.LoadedCount == 0,
        "batch skips other partial magazines, other models, magazines in weapons, and other characters");
    var reply = new NetEntityEvent.Wrapper(machine.Events.Last());
    string Feedback(Client recipient)
    {
        var msg = new Message();
        loader.ServerEventWrite(msg, recipient, reply);
        msg.Rewind(); msg.ReadUInt32();
        Check(msg.ReadInt32() == -1 && msg.ReadInt32() == 0, "batch reply is separate from stock pages");
        return msg.ReadString();
    }
    var result = System.Text.Json.JsonDocument.Parse(Feedback(sender)).RootElement;
    Check(result.GetProperty("Loaded").GetInt32() == 2 && result.GetProperty("Total").GetInt32() == 3 &&
        result.GetProperty("Shortage").GetBoolean() && Feedback(client) == "", "only the requester receives the batch result and shortage");
    SendAs(sender, 4, start, selected.Item.ID, (2, 1));
    SendAs(sender, 4, Revision(), inserted.Item.ID, (2, 1));
    SendAs(sender, 4, Revision(), theirs.Item.ID, (2, 1));
    Check(loader.Stock["b"] == 4 && selected.LoadedCount == 11 && lastEmpty.LoadedCount == 0,
        "replayed batches, weapon-contained templates and another character's templates cannot start a batch");
    selected.MaxSize = selected.LoadedCount;
    SendAs(sender, 4, Revision(), selected.Item.ID, (2, 1));
    Check(selected.LoadedCount == 11 && lastEmpty.LoadedCount == 1 && loader.Stock["b"] == 3,
        "a full selected magazine can be used as the template for the remaining empties");
    foreach (var target in new[] { selected, firstEmpty, lastEmpty }) { SendAs(sender, 2, Revision(), target.Item.ID); }
    Check(loader.Stock.TryTake(Amount("a", 1)) && loader.Stock["a"] == 120 && loader.Stock["b"] == 24,
        "batch loading and unloading conserve shared stock");

    var twoSlots = new Character();
    twoSlots.Inventory.Capacity = 2;
    var empties = Enumerable.Range(0, 3).Select(_ => Magazine(twoSlots.Inventory, 0, bulletA)).ToArray();
    foreach (var empty in empties) { empty.Item.MaxCondition = empty.MaxSize = 2; }
    var batchUser = new Client { Character = twoSlots };
    SendAs(batchUser, 4, Revision(), empties[0].Item.ID, (1, 2));
    Check(twoSlots.Inventory.GetItemAt(0) == null && twoSlots.Inventory.GetItemsAt(1).SequenceEqual(empties.Select(m => m.Item)) &&
        empties.All(m => m.LoadedCount == 2) && loader.Stock["a"] == 114,
        "the entire batch including its last empty magazine forms one loaded stack and frees the original slot");
    foreach (var filled in empties) { SendAs(batchUser, 2, Revision(), filled.Item.ID); }
    Check(twoSlots.Inventory.GetItemAt(1) == null && twoSlots.Inventory.GetItemsAt(0).SequenceEqual(empties.Select(m => m.Item)) &&
        empties.All(m => m.LoadedCount == 0) && loader.Stock["a"] == 120,
        "unloading the last magazine frees the loaded slot, stacks all three empties and credits each round once");
    var packed = new Character();
    packed.Inventory.Capacity = 1;
    var stack = Enumerable.Range(0, 3).Select(_ =>
    {
        var item = new Item(nextId++, bulletA) { Condition = 0 };
        var mag = new VirtualizedMagazine(item);
        item.Components.Add(mag);
        Check(packed.Inventory.TryPutItem(item, 0, false, false, packed), "stack an empty magazine");
        return mag;
    }).ToArray();
    int eventsBefore = machine.Events.Count;
    SendAs(new Client { Character = packed }, 4, Revision(), stack[0].Item.ID, (1, 2));
    Check(stack.All(m => m.LoadedCount == 2) && stack.Take(2).All(m => m.Item.DroppedBy == packed) &&
        packed.Inventory.GetItemsAt(0).Single() == stack[2].Item && loader.Stock["a"] == 114,
        "a batch continues with the saved item list after its selected magazine drops and charges once per instance");
    Check(machine.Events.Skip(eventsBefore).Count(e => e.GetType().Name == "SnapshotPage") == 1,
        "batch publishes the small final stock snapshot once");
    loader.Stock.TryAdd(Amount("a", 6));
}
{
    var carrier = new Character();
    var sender = new Client { Character = carrier };
    var bag = new Item(750, bulletA) { ParentInventory = carrier.Inventory };
    var slots = new ItemInventory(4) { Owner = bag };
    ushort nextId = 751;
    VirtualizedMagazine PutMagazine(int slot, params string[] feedOrder)
    {
        var item = new Item(nextId++, bulletA) { MaxCondition = 2 };
        var magazineComponent = new VirtualizedMagazine(item) { MaxSize = 2 };
        item.Components.Add(magazineComponent);
        magazineComponent.LoadedAmmoIdentifiersArray = feedOrder.Reverse().Select(s => s.ToIdentifier()).ToArray();
        Check(slots.TryPutItem(item, slot, false, false, carrier), "set up magazine stack");
        return magazineComponent;
    }
    var selected = PutMagazine(0);
    var spare = PutMagazine(0);
    var reversed = PutMagazine(1, "b", "a");
    var matching = PutMagazine(3, "a", "b");
    SendAs(sender, 1, Revision(), selected.Item.ID, (1, 1), (2, 1));
    Check(slots.GetItemsAt(0).Single() == spare.Item && slots.GetItemsAt(1).Single() == reversed.Item &&
        slots.GetItemAt(2) == null && slots.GetItemsAt(3).SequenceEqual([matching.Item, selected.Item]),
        "mapped load splits only the selected instance and prefers an identical firing order over a free slot");
    SendAs(sender, 1, Revision(), spare.Item.ID, (1, 1), (2, 1));
    Check(slots.GetItemAt(0) == null && slots.GetItemsAt(3).SequenceEqual([matching.Item, selected.Item, spare.Item]),
        "loading the last empty magazine frees its original slot and joins the matching loaded stack");
    SendAs(sender, 2, Revision(), spare.Item.ID);
    SendAs(sender, 2, Revision(), selected.Item.ID);
    Check(slots.GetItemsAt(0).SequenceEqual([spare.Item, selected.Item]) && slots.GetItemsAt(3).Single() == matching.Item,
        "unloading one full magazine rejoins the empty stack and leaves the other full magazine alone");
    SendAs(sender, 1, Revision(), selected.Item.ID, (2, 1));
    Check(slots.GetItemAt(2) == selected.Item && selected.LoadedCount == 1 && spare.LoadedCount == 0,
        "a partial load uses an empty slot in its own bag");
    SendAs(sender, 2, Revision(), selected.Item.ID);
    Check(slots.GetItemAt(2) == null && slots.GetItemsAt(0).SequenceEqual([spare.Item, selected.Item]),
        "a partially loaded magazine rejoins the empty stack in its own bag after unloading");
    Check(slots.TryPutItem(selected.Item, 2, false, false, carrier), "occupy the free bag slot for the overflow case");
    var another = PutMagazine(0);
    carrier.Inventory.SlotTypes[0] = InvSlotType.LeftHand;
    SendAs(sender, 1, Revision(), another.Item.ID, (1, 1));
    Check(carrier.Inventory.GetItemAt(1) == another.Item && slots.GetItemAt(0) == spare.Item,
        "a full bag falls back to character storage without equipping the loaded magazine");
    SendAs(sender, 2, Revision(), another.Item.ID);
    var overflow = PutMagazine(0);
    carrier.Inventory.Capacity = 2;
    uint beforeOverflow = Revision();
    SendAs(sender, 1, beforeOverflow, overflow.Item.ID, (3, 1));
    Check(overflow.Item.ParentInventory == slots && overflow.LoadedCount == 0 && Revision() == beforeOverflow,
        "a failed load keeps the stack intact even when there is nowhere to put the result");
    SendAs(sender, 1, beforeOverflow, overflow.Item.ID, (1, 2));
    Check(overflow.Item.ParentInventory == null && overflow.Item.DroppedBy == carrier && overflow.LoadedCount == 2 &&
        slots.GetItemsAt(0).Single() == spare.Item && spare.Item.DroppedBy == null && loader.Stock["a"] == 118,
        "only the completed magazine drops beside its owner and its ammunition is paid for once");
    SendAs(sender, 1, beforeOverflow, overflow.Item.ID, (1, 2));
    Check(overflow.LoadedCount == 2 && loader.Stock["a"] == 118, "replaying the request for a dropped magazine cannot debit again");
    carrier.Inventory.Capacity = 3;
    Check(carrier.Inventory.TryPutItem(overflow.Item, 2, false, false, carrier), "pick up the dropped magazine");
    SendAs(sender, 2, Revision(), overflow.Item.ID);
    Check(loader.Stock["a"] == 120 && loader.Stock["b"] == 24, "picking up and unloading the dropped magazine conserves ammunition");
}
uint beforeLoad = Revision();
Send(1, beforeLoad, 20, false, (1, 2), (2, 1));
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 120, "inaccessible client rejected");
Send(1, beforeLoad, 21, true, (1, 2));
Check(mag.LoadedCount == 0, "stale target rejected");
Send(1, beforeLoad, 20, true, (3, 1));
Check(mag.LoadedCount == 0, "incompatible type rejected");
Send(1, beforeLoad, 20, true, (1, 2), (2, 1), (1, 1));
Check(mag.LoadedAmmoIdentifiers.Select(id => id.Value).SequenceEqual(new[] { "a", "a", "b", "a" }), "real loader preserves feed order");
Check(loader.Stock["a"] == 117 && loader.Stock["b"] == 23, "real loader exact debit");
Send(1, beforeLoad, 20, true, (1, 2), (2, 1), (1, 1));
Check(mag.LoadedCount == 4 && loader.Stock["a"] == 117, "replayed command cannot load twice");
uint beforeUnload = Revision();
Send(2, beforeUnload, 20);
Send(2, beforeUnload, 20);
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 120 && loader.Stock["b"] == 24, "repeated unload returns once");
var otherPlayer = new Character();
var otherClient = new Client { Character = otherPlayer };
var otherMagItem = new Item(21, bulletA) { ParentInventory = otherPlayer.Inventory };
var otherMag = new VirtualizedMagazine(otherMagItem);
otherMagItem.Components.Add(otherMag);
uint sharedRevision = Revision();
SendAs(client, 1, sharedRevision, 20, (1, 2));
SendAs(otherClient, 1, sharedRevision, 21, (2, 3));
Check(mag.LoadedCount == 2 && otherMag.LoadedCount == 3 && loader.Stock["a"] == 118 && loader.Stock["b"] == 21,
    "two players load their own magazines from the same snapshot without invalidating each other");
SendAs(client, 1, sharedRevision, 20, (1, 2));
SendAs(otherClient, 1, sharedRevision, 21, (2, 3));
Check(mag.LoadedCount == 2 && otherMag.LoadedCount == 3 && loader.Stock["a"] == 118 && loader.Stock["b"] == 21,
    "each player's old successful request remains protected against replay");
SendAs(client, 2, Revision(), 21);
SendAs(otherClient, 1, Revision(), 20, (2, 1));
Check(mag.LoadedCount == 2 && otherMag.LoadedCount == 3, "clients cannot load or unload another player's magazine");
sharedRevision = Revision();
SendAs(client, 2, sharedRevision, 20);
SendAs(otherClient, 2, sharedRevision, 21);
Check(loader.Stock["a"] == 120 && loader.Stock["b"] == 24 && mag.LoadedCount == 0 && otherMag.LoadedCount == 0,
    "simultaneous unloads return each magazine's rounds exactly once");
otherMagItem.ParentInventory = null;
SendAs(otherClient, 1, Revision(), 21, (2, 1));
Check(otherMag.LoadedCount == 0, "a dropped magazine cannot be loaded using an old selection");
otherMagItem.ParentInventory = otherPlayer.Inventory;
otherMagItem.IsInRemoveQueue = true;
SendAs(otherClient, 1, Revision(), 21, (2, 1));
Check(otherMag.LoadedCount == 0, "a magazine queued for removal cannot consume ammunition");
otherMagItem.IsInRemoveQueue = false;
otherClient.Character = null;
SendAs(otherClient, 1, Revision(), 21, (2, 1));
Check(otherMag.LoadedCount == 0, "a disconnected character cannot use a retained selection");
otherClient.Character = otherPlayer;
var carriedBag = new Item(22, bulletA) { ParentInventory = otherPlayer.Inventory };
otherMagItem.ParentInventory = new ItemInventory(6) { Owner = carriedBag };
SendAs(otherClient, 1, Revision(), 21, (2, 1));
Check(otherMag.LoadedCount == 1, "a magazine inside the player's carried bag is selectable");
SendAs(otherClient, 2, Revision(), 21);
SendAs(client, 1, Revision() + 1, 20, (1, 1));
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 120 && loader.Stock["b"] == 24,
    "future revisions remain invalid and concurrent operations conserve shared stock");
sharedRevision = Revision();
SendAs(client, 1, sharedRevision, 20, (2, 20));
SendAs(otherClient, 1, sharedRevision, 21, (2, 20));
Check(mag.LoadedCount == 20 && otherMag.LoadedCount == 0 && loader.Stock["b"] == 4,
    "competing requests use remaining shared stock without partial loading or double spending");
SendAs(client, 2, Revision(), 20);
magItem.ParentInventory = targetSlot.Inventory;
targetSlot.Inventory.AllItems.Add(magItem);
SendAs(client, 1, Revision(), 20, (1, 1));
Check(mag.LoadedCount == 0 && targetSlot.Inventory.GetItemAt(0) == magItem && loader.Stock["a"] == 120,
    "a legacy stored magazine stays available for retrieval but cannot be loaded as a personal selection");
targetSlot.Inventory.AllItems.Clear();
magItem.ParentInventory = player.Inventory;
mag.MaxSize = 6;
Send(1, Revision(), 20, true, (2, 1), (1, 1));
uint beforeTopUp = Revision();
mag.ThrowOnRefresh = true;
Send(1, beforeTopUp, 20, true, (3, 2), (1, 3), (2, 2));
Check(mag.LoadedAmmoIdentifiers.Select(id => id.Value).SequenceEqual(new[] { "b", "a" }) &&
    loader.Stock["a"] == 119 && loader.Stock["b"] == 23 && Revision() == beforeTopUp,
    "failed top-up restores existing rounds and order without charging stock");
mag.ThrowOnRefresh = false;
Send(1, beforeTopUp, 20, true, (3, 2), (1, 3), (2, 2));
Check(mag.LoadedAmmoIdentifiers.Select(id => id.Value).SequenceEqual(new[] { "a", "a", "b", "b", "b", "a" }),
    "top-up retains the tail, clips inside a group, and preserves the old rounds underneath");
Check(loader.Stock["a"] == 117 && loader.Stock["b"] == 21 && loader.Stock["wrong"] == 0,
    "top-up charges only inserted rounds, ignoring incompatible excess");
uint fullRevision = Revision();
Send(1, fullRevision, 20, true, (1, 1));
Check(mag.LoadedCount == 6 && loader.Stock["a"] == 117 && Revision() == fullRevision,
    "a full magazine rejects loading without changing stock or revision");
Send(2, Revision(), 20);
Check(loader.Stock["a"] == 120 && loader.Stock["b"] == 24, "top-up/unload conserves both old and new rounds");
Send(1, Revision(), 20, true, (3, 1), (2, 100), (1, 6));
Check(mag.LoadedCount == 6 && mag.LoadedAmmoIdentifiers.All(id => id.Value == "a") &&
    loader.Stock["a"] == 114 && loader.Stock["b"] == 24,
    "an oversized plan fills an empty magazine without requiring stock or compatibility for excess rounds");
Send(2, Revision(), 20);
mag.MaxSize = 30;
Send(1, Revision(), 20, true, (1, 26), (2, 5));
Check(mag.LoadedAmmoIdentifiers.Select(id => id.Value).SequenceEqual(Enumerable.Repeat("a", 25).Concat(Enumerable.Repeat("b", 5))) &&
    loader.Stock["a"] == 95 && loader.Stock["b"] == 19,
    "a 31-round plan in a 30-round magazine drops round 1 and retains round 31 with exact stock debit");
Send(2, Revision(), 20);
uint beforeIncompatibleTail = Revision();
Send(1, beforeIncompatibleTail, 20, true, (1, 30), (3, 1));
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 120 && loader.Stock["b"] == 24 && Revision() == beforeIncompatibleTail,
    "incompatible ammunition in the retained tail rejects the entire load");
Send(1, Revision(), 20, true, (1, 1));
uint beforeShortage = Revision();
Send(1, beforeShortage, 20, true, (2, 25));
Check(mag.LoadedCount == 1 && mag.LoadedAmmoIdentifiers.Peek().Value == "a" &&
    loader.Stock["a"] == 119 && loader.Stock["b"] == 24 && Revision() == beforeShortage,
    "insufficient stock for the fitting tail rejects the whole top-up and keeps existing rounds");
Send(1, beforeShortage, 20, true, (1, AmmoPlan.MaxRounds + 1));
Check(mag.LoadedCount == 1 && loader.Stock["a"] == 119,
    "capacity clipping does not bypass the request round limit");
Send(2, Revision(), 20);
mag.ThrowOnRefresh = true;
Send(1, Revision(), 20, true, (1, 5));
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 120, "external failure rolls back load");
mag.ThrowOnRefresh = false;
Send(1, Revision(), 20, true, (1, 5));
mag.ThrowOnRefresh = true;
Send(2, Revision(), 20);
Check(mag.LoadedCount == 5 && loader.Stock["a"] == 115, "external failure rolls back unload");
mag.ThrowOnRefresh = false;
Send(2, Revision(), 20);

var save = loader.Save(new XElement("Item"));
loader.Load(new(save), false, new IdRemap(), false);
loader.Load(new(save), false, new IdRemap(), false);
Check(loader.Stock["a"] == 120, "machine save/load replaces stock");
var oldPage = loader.ServerGetEventData();
for (int i = 0; i < 300; i++) { loader.Stock.TryAdd(Amount("mod_" + i, 100000)); }
int beforeRefresh = machine.Events.Count;
Send(0, Revision(), 20);
var snapshotEvents = machine.Events.Skip(beforeRefresh).ToArray();
Check(snapshotEvents.Length > 1 && snapshotEvents[0].Equals(oldPage),
    "mid-round sync reuses the same page identity across stock revisions");
string[] chunks = new string[snapshotEvents.Length];
for (int i = 0; i < snapshotEvents.Length; i++)
{
    var msg = new Message();
    loader.ServerEventWrite(msg, client, new NetEntityEvent.Wrapper(i == 0 ? oldPage : snapshotEvents[i]));
    msg.Rewind();
    Check(msg.ReadUInt32() == Revision() && msg.ReadInt32() == i && msg.ReadInt32() == chunks.Length,
        "queued page writes the current snapshot revision and page count");
    chunks[i] = msg.ReadString();
}
var decode = typeof(DeepAmmoLoader).GetMethod("DecodeSnapshot", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!;
var encoded = string.Concat(chunks);
var decoded = decode.Invoke(null, [encoded]);
var decodedStock = decoded?.GetType().GetProperty("Stock")!.GetValue(decoded) as IReadOnlyDictionary<string, int>;
Check(encoded.StartsWith('~') && decodedStock?.Count == loader.Stock.Counts.Count && decodedStock["mod_299"] == 100000,
    "large snapshots compress and round-trip stock including unavailable mod types");
Check(decode.Invoke(null, ["~broken"]) == null, "corrupt compressed snapshots are rejected");
foreach (var data in machine.Events)
{
    var msg = new Message();
    loader.ServerEventWrite(msg, new Client(), new NetEntityEvent.Wrapper(data));
    Check(msg.Length < 1024, "snapshot page exceeds game event budget");
}
Console.WriteLine($"Ammo loader including actual server handler: {checks} checks passed (game boundary stubbed).");

var partialPackItem = new Item(31, bulletA) { Condition = 7, MaxCondition = 120 };
partialPackItem.Components.Add(new VirtualizedAmmoStorage(partialPackItem,
    new(XElement.Parse("<VirtualizedAmmoStorage ProjectileIdentifier='a' />"))));
var unrelatedItem = new Item(32, bulletA);
intake.Inventory.AllItems.AddRange([partialPackItem, unrelatedItem]);
int beforeDeposit = loader.Stock["a"];
loader.Update(1, new Camera());
Check(loader.Stock["a"] == beforeDeposit + 7 && partialPackItem.Condition == 0,
    "existing partially used VCE storage deposits its remaining rounds, not its capacity");
Check(!unrelatedItem.IsInRemoveQueue && unrelatedItem.Condition == 100, "intake ignores items without VCE storage");
Console.WriteLine($"Backend including existing VCE storage: {checks} checks passed.");

ItemPrefab Package(string id, uint number, float health, string ammo, bool tagged = true, bool container = false)
{
    var prefab = new ItemPrefab(id, number, tagged ? ["vceammopackage"] : [])
    {
        Health = health,
        ConfigElement = new(new XElement("Item",
            new XElement("VirtualizedAmmoStorage", new XAttribute("ProjectileIdentifier", ammo)),
            container ? new XElement("ItemContainer") : null))
    };
    ItemPrefab.Prefabs.Values.Add(prefab);
    return prefab;
}
var largest = Package("a_package", 10, 120, "a");
Package("z_package", 11, 120, "a");
Package("small_package", 12, 24, "a");
var untagged = Package("untagged_package", 13, 1000, "a", tagged: false);
Check(DeepAmmoLoader.FindWithdrawalPackage("a") == untagged, "storage component identifies packages without a hard-coded tag");
untagged.Tags.Add("renamed_package_tag".ToIdentifier());
Check(DeepAmmoLoader.FindWithdrawalPackage("a") == untagged, "renaming package tags does not change withdrawal eligibility");
ItemPrefab.Prefabs.Values.Remove(untagged);
Package("container_package", 14, 1000, "a", container: true);
Package("infinite_package", 15, float.PositiveInfinity, "a");
Package("oversized_package", 16, float.MaxValue, "a");
var bPackage = Package("b_package", 17, 100, "b");
Check(DeepAmmoLoader.FindWithdrawalPackage("a") == largest, "largest valid package wins with a stable identifier tie-break");
Check(DeepAmmoLoader.FindWithdrawalPackage("wrong") == null && DeepAmmoLoader.FindWithdrawalPackage("unknown") == null,
    "missing packages and unknown projectile types cannot be withdrawn");
uint packageNumber = 10000;
var supplyByRound = new Dictionary<string, (string Box, double Cost)>(StringComparer.OrdinalIgnoreCase);
foreach (var element in XDocument.Load("weapon/ammo/ammobox.xml").Root!.Elements("Item"))
{
    string boxId = (string)element.Attribute("identifier")!;
    var supply = DdaSupply.Resolve(new Item(0, new ItemPrefab(boxId, 0)));
    if (boxId == "deep_ammobox_copper")
    {
        Check(supply == null, "retired copper RIP must not invalidate other supply pools");
        continue;
    }
    Check(supply?.PoolId == "dda." + boxId, $"missing supply pool for {boxId}");
    foreach (var (id, cost) in supply!.Costs)
    {
        Check(double.IsFinite(cost) && cost > 0 && supplyByRound.TryAdd(id, (boxId, cost)), $"invalid or duplicate supply for {id}");
    }
}
var itemFiles = XDocument.Load("filelist.xml").Root!.Elements("Item").Select(e => (string)e.Attribute("file")!).ToArray();
IEnumerable<XElement> AmmoItems(string folder) => itemFiles.Where(p => p.StartsWith("%ModDir%/weapon/ammo/" + folder + "/"))
    .SelectMany(p => XDocument.Load(p["%ModDir%/".Length..]).Root!.Elements("Item"));
var rounds = AmmoItems("NewAmmoRound").Where(e => e.Element("Projectile") != null)
    .ToDictionary(e => (string)e.Attribute("identifier")!, StringComparer.OrdinalIgnoreCase);
var packaged = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
foreach (var element in AmmoItems("NewAmmoPackages"))
{
    string ammo = (string)element.Element("VirtualizedAmmoStorage")!.Attribute("ProjectileIdentifier")!;
    string packageId = (string)element.Attribute("identifier")!;
    string material = packageId.Split("_package_").Last() switch
    {
        "lead" => "lead", "tit" => "titanium", "phy" => "physicorium", "du" => "depleted_uranium",
        "fu" or "m995" or "bs" or "bp" or "m61" => "fulgurium_physicorium",
        "ap" or "ssa_ap" or "7n39" or "mai_ap" or "m993" or "7n37" => "tungsten_physicorium",
        _ => throw new Exception("Unknown package material: " + packageId)
    };
    Check(packaged.Add(ammo) && supplyByRound[ammo].Box == "deep_ammobox_" + material, $"wrong supply for {packageId}");
    ItemPrefab.Prefabs.Values.Add(new ItemPrefab(ammo, packageNumber++) { ConfigElement = new(rounds[ammo]) });
    var definedPackage = new ItemPrefab(packageId, packageNumber++,
        ((string)element.Attribute("tags")!).Split(','))
        { Health = (float)element.Attribute("health")!, ConfigElement = new(element) };
    ItemPrefab.Prefabs.Values.Add(definedPackage);
    Check(DeepAmmoLoader.FindWithdrawalPackage(ammo) == definedPackage, "DDA XML-defined package resolves its configured projectile");
}
Check(packaged.Count > 0 && packaged.SetEquals(rounds.Keys), "every active round must have a package");
Check(supplyByRound["deep_12shell_aa12"] == ("deep_ammobox_titanium", 18.75 / 25) &&
    supplyByRound["deep_slug_aa12"] == ("deep_ammobox_physicorium", 18.75 / 25), "preserve AA-12 supply");
Check(supplyByRound.Count == packaged.Count + 2, "supply must contain only active rounds and the two AA-12 shells");
machine = new Item(40, bulletA);
intake = new ItemContainer(machine, 6);
var pickup = new ItemContainer(machine, 3);
targetSlot = new ItemContainer(machine, 1);
loader = new DeepAmmoLoader(machine, new(new XElement("DeepAmmoLoader")));
machine.Components.AddRange([intake, pickup, targetSlot, loader]);
loader.OnItemLoaded();
Check(loader.InputContainer == intake && loader.OutputContainer == pickup && loader.TargetContainer == targetSlot,
    "default container indices match the left-to-right intake, pickup, magazine order");
loader.Stock.TryAdd(Amount("a", 300));
loader.Stock.TryAdd(Amount("b", 37));
Entity.Spawner = new();
uint beforeWithdraw = Revision();
Send(3, beforeWithdraw, 0, false, (1, 1));
Send(3, beforeWithdraw, 0, true, (1, 2));
Send(3, beforeWithdraw, 0, true, (1, 1), (2, 1));
Send(3, beforeWithdraw, 0, true, (99, 1));
Check(Entity.Spawner.Pending.Count == 0, "withdraw rejects inaccessible clients, forged counts, multiple types and unknown identifiers");
Send(3, beforeWithdraw, 0, true, (1, 1));
Send(3, beforeWithdraw, 0, true, (1, 1));
Check(Entity.Spawner.Pending.Count == 1 && loader.Stock["a"] == 300,
    "concurrent withdrawal requests queue one package without charging unspawned stock");
var pendingSave = loader.Save(new XElement("Item"));
Check((int)pendingSave.Element("Stock")!.Elements("Ammo").Single(e => (string?)e.Attribute("id") == "a").Attribute("count")! == 300,
    "saving before the spawn retains all stock");
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Single().Prefab == largest && pickup.Inventory.AllItems[0].Condition == 120 && loader.Stock["a"] == 180,
    "withdraw creates a full largest package with exact debit and no magazine");
Send(3, beforeWithdraw, 0, true, (1, 1));
Check(Entity.Spawner.Pending.Count == 0, "a completed withdrawal cannot be replayed with its old revision");
Send(3, Revision(), 0, true, (1, 1));
Entity.Spawner.ProcessQueue();
Send(3, Revision(), 0, true, (2, 1));
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Count == 3 && pickup.Inventory.AllItems[^1].Prefab == bPackage &&
    pickup.Inventory.AllItems[^1].Condition == 37 && loader.Stock["b"] == 0 && loader.Stock["a"] == 60,
    "custom pickup capacity holds multiple packages, including a partial final package");
Send(3, Revision(), 0, true, (1, 1));
Check(Entity.Spawner.Pending.Count == 0 && loader.Stock["a"] == 60, "full pickup slots cannot consume stock");
var returnedPackage = pickup.Inventory.AllItems[0];
pickup.Inventory.AllItems.Remove(returnedPackage);
returnedPackage.ParentInventory = intake.Inventory;
intake.Inventory.AllItems.Add(returnedPackage);
loader.Update(1, new Camera());
Check(loader.Stock["a"] == 180 && returnedPackage.Condition == 0,
    "withdrawn packages can be redeposited without creating or losing ammunition");
intake.Inventory.AllItems.Clear();
pickup.Inventory.AllItems.Clear();

Send(3, Revision(), 0, true, (1, 1));
pickup.Inventory.Accepts = _ => false;
Entity.Spawner.ProcessQueue();
Check(loader.Stock["a"] == 180 && pickup.Inventory.AllItems.Count == 0 && Entity.Spawner.Pending.Count == 0,
    "a slot becoming unavailable before spawn cancels without a debit or stuck pending flag");
pickup.Inventory.Accepts = null;
pickup.Inventory.RejectInsertion = true;
Send(3, Revision(), 0, true, (1, 1));
Entity.Spawner.ProcessQueue();
Check(loader.Stock["a"] == 180 && Entity.Spawner.Spawned[^1].Removed && Entity.Spawner.Spawned[^1].Condition == 0,
    "an item that fails actual insertion is removed without granting free ammunition or charging stock");
pickup.Inventory.RejectInsertion = false;
Send(3, Revision(), 0, true, (1, 1));
machine.Condition = 0;
Entity.Spawner.ProcessQueue();
Check(loader.Stock["a"] == 180 && pickup.Inventory.AllItems.Count == 0, "a machine breaking while queued cancels delivery");
machine.Condition = 100;
Send(3, Revision(), 0, true, (1, 1));
Entity.Spawner.Pending.Clear();
loader.Load(new(loader.Save(new XElement("Item"))), false, new IdRemap(), false);
Check(loader.Stock["a"] == 180, "discarding the spawn queue and reloading cannot lose reserved rounds");

loader.Stock.Load(new XElement("Stock", new XElement("Ammo", new XAttribute("id", "a"), new XAttribute("count", 50))));
mag = new VirtualizedMagazine(magItem);
magItem.Components.Clear();
magItem.Components.Add(mag);
magItem.ParentInventory = player.Inventory;
Send(3, Revision(), 20, true, (1, 1));
Send(1, Revision(), 20, true, (1, 25));
Entity.Spawner.ProcessQueue();
Check(mag.LoadedCount == 25 && pickup.Inventory.AllItems.Single().Condition == 25 && loader.Stock["a"] == 0,
    "a load between queueing and delivery leaves only current stock in the package, conserving all 50 rounds");
var completedSave = loader.Save(new XElement("Item"));
loader.Load(new(completedSave), false, new IdRemap(), false);
Check(loader.Stock["a"] == 0 && pickup.Inventory.AllItems.Single().Condition == 25,
    "reloading completed stock does not restore ammunition already packed");
Package("large_condition_package", 18, 20_000_000, "wrong");
loader.Stock.TryAdd(Amount("wrong", 16_777_217));
Send(3, Revision(), 20, true, (3, 1));
Entity.Spawner.ProcessQueue();
Check(loader.Stock["wrong"] == 16_777_217 && Entity.Spawner.Spawned[^1].Removed,
    "a count that cannot be represented exactly by Condition must not lose or create ammunition");
loader.OutputContainerIndex = 0;
loader.OnItemLoaded();
Check(loader.OutputContainer == null && loader.Ready, "overlapping output and intake disables withdrawal without disabling magazine loading");
Console.WriteLine($"Backend including package withdrawal: {checks} checks passed (spawn queue and game boundary stubbed).");

machine = new Item(50, bulletA);
intake = new ItemContainer(machine, 6);
pickup = new ItemContainer(machine, 3);
targetSlot = new ItemContainer(machine, 1);
loader = new DeepAmmoLoader(machine, new(new XElement("DeepAmmoLoader")));
machine.Components.AddRange([intake, pickup, targetSlot, loader]);
loader.OnItemLoaded();
mag = new VirtualizedMagazine(magItem);
magItem.Components.Clear();
magItem.Components.Add(mag);
magItem.ParentInventory = player.Inventory;
var box = new Item(51, largest) { Condition = 2, MaxCondition = 100 };
var otherBox = new Item(52, largest) { Condition = 3, MaxCondition = 100 };
box.Components.Add(new VirtualizedAmmoStorage(box, new(XElement.Parse("<VirtualizedAmmoStorage ProjectileIdentifier='a' />"))));
intake.Inventory.AllItems.AddRange([box, otherBox]);
var costs = new Dictionary<string, double> { ["a"] = 0.5, ["b"] = 1 };
loader.SupplyResolver = item => item == box || item == otherBox ? new("shared", costs) : null;
loader.Update(1, new Camera());
Check(box.Condition == 2 && !box.IsInRemoveQueue && loader.Stock.Counts.Count == 0,
    "recognized supplies stay in intake even if they also have VirtualizedAmmoStorage");
loader.Stock.TryAdd(Amount("a", 2));
uint supplyRevision = Revision();
Send(1, supplyRevision, 20, true, (1, 8), (2, 3));
Check(mag.LoadedCount == 0 && box.Condition == 2 && otherBox.Condition == 3 && loader.Stock["a"] == 2,
    "individually affordable calibers cannot overspend their shared pool in one plan");
mag.ThrowOnRefresh = true;
Send(1, Revision(), 20, true, (1, 6), (2, 3));
Check(mag.LoadedCount == 0 && box.Condition == 2 && otherBox.Condition == 3 && loader.Stock["a"] == 2,
    "magazine failure charges neither supplies nor stored rounds");
mag.ThrowOnRefresh = false;
Send(1, Revision(), 20, false, (1, 6), (2, 3));
Check(mag.LoadedCount == 0 && box.Condition == 2, "inaccessible supply load rejected");
otherBox.BeforeConditionSet = value => { if (value < 3) { throw new InvalidOperationException("Injected supply debit failure"); } };
Send(1, Revision(), 20, true, (1, 6), (2, 3));
Check(mag.LoadedCount == 0 && box.Condition == 2 && otherBox.Condition == 3 && loader.Stock["a"] == 2 &&
    box.BrokenEffects == 0 && otherBox.BrokenEffects == 0,
    "a later box debit failure restores earlier boxes, concrete stock and the magazine");
otherBox.BeforeConditionSet = null;
otherBox.IgnoreConditionChanges = true;
Send(1, Revision(), 20, true, (1, 6), (2, 3));
Check(mag.LoadedCount == 0 && box.Condition == 2 && otherBox.Condition == 3 && box.BrokenEffects == 0 && loader.Stock["a"] == 2,
    "an invulnerable source silently rejecting Condition changes cannot grant free ammo or destroy earlier boxes");
otherBox.IgnoreConditionChanges = false;
Send(1, supplyRevision, 20, true, (1, 6), (2, 3));
Check(mag.LoadedCount == 9 && box.Condition == 0 && otherBox.Condition == 0 && loader.Stock["a"] == 0 &&
    mag.LoadedAmmoIdentifiers.Select(i => i.Value).SequenceEqual(Enumerable.Repeat("a", 6).Concat(Enumerable.Repeat("b", 3))),
    "stock is used first and mixed shortages share and exhaust multiple boxes in deterministic order");
Check(box.BrokenEffects == 1 && otherBox.BrokenEffects == 1, "native exhaustion effects run once only after all supply debits commit");
Send(1, supplyRevision, 20, true, (1, 6), (2, 3));
Check(mag.LoadedCount == 9, "a supply load cannot be replayed");
Send(2, Revision(), 20);
Check(loader.Stock["a"] == 6 && loader.Stock["b"] == 3 && box.Condition == 0 && otherBox.Condition == 0,
    "unloading returns concrete ammunition without refunding universal reserves");
box.Condition = 10;
loader.Update(1, new Camera());
Entity.Spawner = new();
Send(3, Revision(), 0, true, (1, 1));
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Single().Condition == 6 && box.Condition == 10 && loader.Stock["a"] == 0,
    "package withdrawal uses only concrete stock and never converts shared reserves");
loader.Stock.Load(null);
mag.MaxSize = 3;
Send(1, Revision(), 20, true, (3, 100), (1, 1), (2, 2));
Check(mag.LoadedCount == 3 && box.Condition == 7.5f && otherBox.Condition == 0,
    "supply cost covers only the fitting plan tail, not excess or incompatible discarded rounds");
Send(2, Revision(), 20);
loader.Stock.Load(null);
intake.Inventory.AllItems.Remove(box);
Send(1, Revision(), 20, true, (1, 1));
Check(mag.LoadedCount == 0 && box.Condition == 7.5f, "a box removed before the periodic scan cannot still supply ammunition");
intake.Inventory.AllItems.Add(box);
box.Condition = 4;
loader.Update(1, new Camera());
supplyRevision = Revision();
box.Condition = 3;
loader.Update(1, new Camera());
Check(Revision() > supplyRevision, "external Condition changes invalidate the published supply state");
Send(1, supplyRevision, 20, true, (1, 1));
Check(mag.LoadedCount == 1 && box.Condition == 2.5f, "an unrelated stock change is revalidated against current supplies");
Send(2, Revision(), 20);
loader.Stock.Load(null);
box.Condition = 3;
GameMain.NetworkMember = new() { IsClient = true };
Send(1, Revision(), 20, true, (1, 1));
Check(mag.LoadedCount == 0 && box.Condition == 3, "only the authority can debit supplies");
GameMain.NetworkMember = null;

foreach (double invalidCost in new[] { 0, -1, double.NaN, double.PositiveInfinity, 1e-100 })
{
    costs["a"] = invalidCost;
    Send(1, Revision(), 20, true, (1, 1));
    Check(mag.LoadedCount == 0 && box.Condition == 3, "invalid or unrepresentable costs cannot provide free rounds");
}
costs["a"] = 0.5;
loader.SupplyResolver = item => new(item.ID.ToString(), costs);
Send(1, Revision(), 20, true, (1, 1));
Check(mag.LoadedCount == 0 && box.Condition == 3, "overlapping projectile mappings across pools fail closed");
loader.SupplyResolver = item => new("shared", item == box ? costs : new Dictionary<string, double> { ["a"] = 1 });
Send(1, Revision(), 20, true, (1, 1));
Check(mag.LoadedCount == 0 && box.Condition == 3, "inconsistent costs within one pool fail closed");
loader.SupplyResolver = _ => throw new InvalidOperationException("Injected adapter failure");
loader.Update(1, new Camera());
Check(!box.IsInRemoveQueue && box.Condition == 3 && loader.Stock.Counts.Count == 0,
    "an adapter failure cannot accidentally deposit and destroy a supply box");
loader.Stock.TryAdd(Amount("a", 1));
Send(1, Revision(), 20, true, (1, 1));
Check(mag.LoadedCount == 1 && box.Condition == 3, "adapter failure still permits loading existing concrete stock");
loader.SupplyResolver = item => new("shared", costs);
Send(2, Revision(), 20);
loader.Update(1, new Camera());
var supplySave = loader.Save(new XElement("Item"));
Check(supplySave.Elements().All(e => e.Name == "Stock"), "supply reserves are saved on their physical items, not duplicated in machine stock");
loader.Load(new(supplySave), false, new IdRemap(), false);
Send(1, Revision(), 20, true, (1, 2));
Check(mag.LoadedCount == 2 && box.Condition == 2.5f && loader.Stock["a"] == 0,
    "restored concrete stock and live item reserves remain separate and usable");
Console.WriteLine($"Backend including custom shared supplies: {checks} checks passed (game boundary stubbed).");

machine = new Item(70, bulletA);
intake = new ItemContainer(machine, 6);
pickup = new ItemContainer(machine, 6);
targetSlot = new ItemContainer(machine, 1);
loader = new DeepAmmoLoader(machine, new(new XElement("DeepAmmoLoader"))) { UseSupplyStorage = true };
machine.Components.AddRange([intake, pickup, targetSlot, loader]);
loader.OnItemLoaded();
mag = new VirtualizedMagazine(magItem);
magItem.Components.Clear();
magItem.Components.Add(mag);
magItem.ParentInventory = player.Inventory;
box = new Item(71, largest) { MaxCondition = 10, Condition = 9 };
otherBox = new Item(72, largest) { MaxCondition = 10, Condition = 9.25f };
intake.Inventory.AllItems.AddRange([box, otherBox]);
costs = new Dictionary<string, double> { ["a"] = 0.5, ["b"] = 1 };
loader.SupplyResolver = item => item == box || item == otherBox ? new("shared", costs) : null;
Entity.Spawner = new();
void FillMagazine(params string[] ids)
{
    mag.LoadedAmmoIdentifiers.Clear();
    foreach (string id in ids.Reverse()) { mag.LoadedAmmoIdentifiers.Push(id.ToIdentifier()); }
    loader.Update(1, new Camera());
}
FillMagazine("a", "a", "a", "b", "b");
Send(2, Revision(), 20);
Check(mag.LoadedCount == 0 && box.Condition == 10 && otherBox.Condition == 9.75f && loader.Stock["a"] == 0 && loader.Stock["b"] == 2,
    "unload refills shared boxes across source boundaries and returns only excess whole rounds to stock");
intake.Inventory.AllItems.Clear();
FillMagazine("a", "b");
Send(2, Revision(), 20);
Check(mag.LoadedCount == 0 && loader.Stock["a"] == 1 && loader.Stock["b"] == 3,
    "missing boxes fall back to concrete stock without losing mixed ammunition");
intake.Inventory.AllItems.AddRange([box, otherBox]);
box.Condition = otherBox.Condition = 10;
FillMagazine("a", "b");
Send(2, Revision(), 20);
Check(mag.LoadedCount == 0 && box.Condition == 10 && otherBox.Condition == 10 && loader.Stock["a"] == 2 && loader.Stock["b"] == 4,
    "full boxes fall back to stock without overfilling");
loader.Stock.Load(null);
box.Condition = otherBox.Condition = 9;
FillMagazine("b", "a", "a", "a", "a");
var originalReturnOrder = mag.LoadedAmmoIdentifiers.ToArray();
otherBox.BeforeConditionSet = value => { if (value > 9) { throw new InvalidOperationException("Injected credit failure"); } };
Send(2, Revision(), 20);
Check(mag.LoadedAmmoIdentifiers.SequenceEqual(originalReturnOrder) && box.Condition == 9 && otherBox.Condition == 9 && loader.Stock.Counts.Count == 0,
    "a later refund failure restores earlier boxes, the complete magazine order and overflow stock");
otherBox.BeforeConditionSet = null;
otherBox.IgnoreConditionChanges = true;
Send(2, Revision(), 20);
Check(mag.LoadedAmmoIdentifiers.SequenceEqual(originalReturnOrder) && box.Condition == 9 && loader.Stock.Counts.Count == 0,
    "a silently rejected credit cannot consume magazine rounds");
otherBox.IgnoreConditionChanges = false;
GameMain.NetworkMember = new() { IsClient = true };
Send(2, Revision(), 20);
Check(mag.LoadedAmmoIdentifiers.SequenceEqual(originalReturnOrder) && box.Condition == 9, "clients cannot credit supplies or unload locally");
GameMain.NetworkMember = null;
loader.Stock.TryAdd(Amount("b", int.MaxValue));
Send(2, Revision(), 20);
Check(mag.LoadedAmmoIdentifiers.SequenceEqual(originalReturnOrder) && box.Condition == 9 && otherBox.Condition == 9,
    "overflow fallback rejects the entire return before crediting any boxes");
loader.Stock.Load(null);
FillMagazine();
box.Condition = 2;
otherBox.Condition = 3;
loader.Stock.TryAdd(Amount("a", 2));
loader.Update(1, new Camera());
Send(3, Revision(), 20, true, (1, 1));
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Single().Condition == 12 && loader.Stock["a"] == 0 && box.Condition == 0 && otherBox.Condition == 0 &&
    box.BrokenEffects == 0 && otherBox.BrokenEffects == 0,
    "package withdrawal uses stock then shared reserves, retaining depleted boxes for refilling");
returnedPackage = pickup.Inventory.AllItems.Single();
pickup.Inventory.AllItems.Clear();
returnedPackage.ParentInventory = intake.Inventory;
intake.Inventory.AllItems.Add(returnedPackage);
loader.Update(1, new Camera());
Check(returnedPackage.Condition == 0 && returnedPackage.IsInRemoveQueue && box.Condition == 6 && otherBox.Condition == 0 && loader.Stock.Counts.Count == 0,
    "redepositing the supplied package refills boxes without creating internal stock");
intake.Inventory.AllItems.Remove(returnedPackage);
box.Condition = 2;
otherBox.Condition = 0;
loader.Stock.TryAdd(Amount("a", 1));
loader.Update(1, new Camera());
Send(3, Revision(), 20, true, (1, 1));
intake.Inventory.AllItems.Remove(box);
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Single().Condition == 1 && loader.Stock["a"] == 0 && box.Condition == 2,
    "taking a box away while packing reduces delivery to the remaining concrete stock");
pickup.Inventory.AllItems.Clear();
intake.Inventory.AllItems.Add(box);
loader.Update(1, new Camera());
Send(3, Revision(), 20, true, (1, 1));
intake.Inventory.AllItems.Remove(box);
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Count == 0 && Entity.Spawner.Spawned[^1].Removed && box.Condition == 2,
    "no remaining source cancels a queued package without free ammunition");
intake.Inventory.AllItems.Add(box);
loader.Stock.TryAdd(Amount("a", 1));
loader.Update(1, new Camera());
Send(3, Revision(), 20, true, (1, 1));
box.IgnoreConditionChanges = true;
Entity.Spawner.ProcessQueue();
Check(pickup.Inventory.AllItems.Count == 0 && box.Condition == 2 && loader.Stock["a"] == 1,
    "rejected supply debit cancels package delivery and retains concrete stock");
box.IgnoreConditionChanges = false;
loader.Stock.Load(null);
costs["a"] = 1.5625 / 30;
box.MaxCondition = 100;
box.Condition = 100;
intake.Inventory.AllItems.Remove(otherBox);
loader.Update(1, new Camera());
Send(1, Revision(), 20, true, (1, 30));
Check(mag.LoadedCount == 30 && box.Condition == 98.4375f, "DDA 30-round magazine consumes exactly 1.5625 Condition");
Send(2, Revision(), 20);
Check(mag.LoadedCount == 0 && box.Condition == 100 && loader.Stock.Counts.Count == 0, "full DDA load-return roundtrip conserves box contents");
for (int cycle = 0; cycle < 30; cycle++)
{
    int eventsBefore = box.StatusEvents;
    Send(1, Revision(), 20, true, (1, 1));
    Check(box.StatusEvents == eventsBefore + 1, "a fractional debit publishes the physical box condition");
    Send(2, Revision(), 20);
    Check(box.StatusEvents == eventsBefore + 2, "a fractional refund publishes the physical box condition");
    Check(mag.LoadedCount == 0 && box.Condition == 100 && loader.Stock.Counts.Count == 0, "single-round supply return must not accumulate float drift or leftover stock");
}
Console.WriteLine($"Backend including refillable supplies: {checks} checks passed (game boundary stubbed).");

string presetRoot = SaveUtil.Folder;
string legacyPath = Path.Combine(presetRoot, "VCE", "AmmoLoaderPresets.json");
string ddaPath = Path.Combine(presetRoot, "DDA", "DeepAmmoLoaderPresets.json");
void ResetPresets()
{
    foreach (string field in new[] { "saved", "loadError" })
    { typeof(AmmoPresets).GetField(field, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!.SetValue(null, null); }
}
try
{
    Directory.CreateDirectory(Path.GetDirectoryName(legacyPath)!);
    const string originalPreset = "[{\"Name\":\"Legacy\",\"Rounds\":[{\"Id\":\"a\",\"Count\":3}]}]";
    File.WriteAllText(legacyPath, originalPreset);
    Check(AmmoPresets.Saved.Single().Name == "Legacy" && !File.Exists(ddaPath), "read legacy presets without rewriting either file");
    AmmoPresets.Saved.Add(new AmmoPreset("DDA", [new AmmoRun("b", 2)]));
    AmmoPresets.Save();
    Check(File.ReadAllText(legacyPath) == originalPreset && File.Exists(ddaPath), "save migrated presets only in DDA");
    ResetPresets();
    File.WriteAllText(legacyPath, "[]");
    Check(AmmoPresets.Saved.Count == 2, "prefer DDA presets after first save");
    File.WriteAllText(ddaPath, "broken json");
    ResetPresets();
    Check(AmmoPresets.Saved.Count == 0, "invalid DDA presets must not silently fall back to VCE");
    bool refused = false;
    try { AmmoPresets.Save(); } catch (IOException) { refused = true; }
    Check(refused && File.ReadAllText(ddaPath) == "broken json", "preserve malformed DDA preset files");
    Console.WriteLine($"Backend and preset migration: {checks} checks passed.");
}
finally
{
    foreach (string path in new[] { legacyPath, ddaPath, ddaPath + ".tmp" }) { if (File.Exists(path)) File.Delete(path); }
    foreach (string folder in new[] { Path.GetDirectoryName(legacyPath)!, Path.GetDirectoryName(ddaPath)!, presetRoot })
    { if (Directory.Exists(folder)) Directory.Delete(folder); }
}
