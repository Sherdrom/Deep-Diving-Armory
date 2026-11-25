using System.Xml.Linq;
using Barotrauma.Items.Components;
using Barotrauma.Networking;
using VCE_VirtualizedMagazine;

namespace DDA.AmmoLoading;

public sealed partial class DeepAmmoLoader : ItemComponent, IServerSerializable, IClientSerializable
{
    public AmmoStock Stock { get; private set; } = new();
    private ItemContainer? inputContainer, targetContainer, outputContainer;
    private XElement? invalidStock;
    private uint revision;
    private float scanTimer;

    [Serialize(0, IsPropertySaveable.No)]
    public int InputContainerIndex { get; set; }

    [Serialize(2, IsPropertySaveable.No)]
    public int TargetContainerIndex { get; set; } = 2;

    [Serialize(1, IsPropertySaveable.No)]
    public int OutputContainerIndex { get; set; } = 1;

    [Serialize(false, IsPropertySaveable.No)]
    public bool UseSupplyStorage { get; set; }

    [Serialize("", IsPropertySaveable.No)]
    public string TextPrefix { get; set; } = "";

    public VirtualizedMagazine? Target { get; private set; }
    public ItemContainer? InputContainer => inputContainer;
    public ItemContainer? TargetContainer => targetContainer;
    public ItemContainer? OutputContainer => outputContainer;
    public uint StateRevision => revision;
    private bool IsAuthority => GameMain.NetworkMember is not { IsClient: true };
    public bool Ready => invalidStock == null && inputContainer != null && targetContainer != null &&
        inputContainer != targetContainer && Item.Condition > 0;

    public DeepAmmoLoader(Item item, ContentXElement element) : base(item, element)
    {
        IsActive = true;
        SupplyResolver = DdaSupply.Resolve;
    }

    public override void OnItemLoaded()
    {
        var containers = Item.GetComponents<ItemContainer>().ToArray();
        inputContainer = containers.ElementAtOrDefault(InputContainerIndex);
        targetContainer = containers.ElementAtOrDefault(TargetContainerIndex);
        outputContainer = containers.ElementAtOrDefault(OutputContainerIndex);
        if (outputContainer == inputContainer || outputContainer == targetContainer) { outputContainer = null; }
        if (inputContainer == targetContainer || targetContainer?.Inventory?.Capacity != 1)
        {
            inputContainer = targetContainer = null;
            Barotrauma.LuaCsLogger.Log(
                $"DeepAmmoLoader on {Item.Prefab.Identifier} needs separate input and one-slot target ItemContainers.");
        }
        InitClient();
    }

    partial void InitClient();
    partial void UpdateTargetSelection();

    public static bool IsProjectile(string id) =>
        ElementHelper.GetFirstComponentElementByID<Projectile>(id.ToIdentifier()) != null;

    public static bool IsCompatible(VirtualizedMagazine? magazine, string id) =>
        IsProjectile(id) && (magazine == null || magazine.IsAmmoCompatible(id.ToIdentifier()));

    private static VirtualizedMagazine? GetOwnedMagazine(Item? item, Character? character) =>
        item is { Removed: false, IsInRemoveQueue: false } && character != null && item.IsOwnedBy(character)
            ? item.GetComponent<VirtualizedMagazine>() : null;

    public static ItemPrefab? FindWithdrawalPackage(string id)
    {
        if (!IsProjectile(id)) { return null; }
        var identifier = id.ToIdentifier();
        return FindWithdrawalPackages([identifier]).GetValueOrDefault(identifier);
    }

    private static Dictionary<Identifier, ItemPrefab> FindWithdrawalPackages(HashSet<Identifier> ammo)
    {
        var packages = new Dictionary<Identifier, ItemPrefab>();
        if (ammo.Count == 0) { return packages; }
        foreach (var prefab in ItemPrefab.Prefabs)
        {
            if (!float.IsFinite(prefab.Health) || prefab.Health < 1 || prefab.Health >= int.MaxValue) { continue; }
            Identifier id = Identifier.Empty;
            bool foundStorage = false, hasContainer = false;
            foreach (var element in prefab.ConfigElement.Elements())
            {
                string name = element.Name.ToString();
                if (name.Equals(nameof(ItemContainer), StringComparison.OrdinalIgnoreCase))
                { hasContainer = true; break; }
                if (!foundStorage && name.Equals(nameof(VirtualizedAmmoStorage), StringComparison.OrdinalIgnoreCase))
                { id = element.GetAttributeIdentifier("ProjectileIdentifier", Identifier.Empty); foundStorage = true; }
            }
            if (!foundStorage || hasContainer || !ammo.Contains(id)) { continue; }
            if (!packages.TryGetValue(id, out var best) || prefab.Health > best.Health ||
                (prefab.Health == best.Health && string.CompareOrdinal(prefab.Identifier.Value, best.Identifier.Value) < 0))
            { packages[id] = prefab; }
        }
        return packages;
    }

    private string WithdrawalProblem(string id, ItemPrefab? package)
    {
        if (!Ready || Item.Removed || Item.IsInRemoveQueue) { return "unavailable"; }
        if (outputContainer?.Inventory == null) { return "nooutput"; }
        if (package == null) { return "nopackage"; }
        int available = WithdrawalAmount(id);
        if (available < 1) { return "notenough"; }
        return outputContainer.Inventory.CanProbablyBePut(package, Math.Min(available, (int)package.Health), quality: 0)
            ? "withdraw" : "outputfull";
    }

    private bool TryWithdraw(string id)
    {
        if (!IsAuthority) { return false; }
        if (RefreshSupplies()) { Changed(); }
        var package = FindWithdrawalPackage(id);
        if (WithdrawalProblem(id, package) != "withdraw" || Entity.Spawner is not { Removed: false } spawner)
        { return false; }
        var inventory = outputContainer!.Inventory;
        if (spawner.IsInSpawnQueue(info => info is EntitySpawner.ItemSpawnInfo pending && pending.Inventory == inventory))
        { return false; }
        int requested = Math.Min(WithdrawalAmount(id), (int)package!.Health);
        // Charge only after the queued item reaches the output, using the then-current supplies.
        spawner.AddItemToSpawnQueue(package, inventory, condition: requested, quality: 0, spawnIfInventoryFull: false,
            onSpawned: spawned =>
            {
                uint before = revision;
                if (RefreshSupplies()) { Changed(); }
                int amount = Math.Min(requested, WithdrawalAmount(id));
                var demand = new Dictionary<string, int> { [id] = amount };
                var quote = UseSupplyStorage ? QuoteSupply(demand) : new SupplyQuote(demand, [], Stock.CanTake(demand));
                bool delivered = false;
                try
                {
                    if (Ready && !Item.Removed && !Item.IsInRemoveQueue && !spawned.Removed && !spawned.IsInRemoveQueue &&
                        spawned.ParentInventory == inventory && outputContainer?.Inventory == inventory &&
                        spawned.GetComponent<VirtualizedAmmoStorage>()?.AmmoIdentifier == id.ToIdentifier() &&
                        !spawned.ContainedItems.Any() && amount > 0)
                    {
                        spawned.Condition = amount;
                        delivered = (double)spawned.Condition == amount && TryPrepareSupplyDebit(quote, out var debits) &&
                            TryCommitSupplyDebit(quote, debits);
                    }
                }
                catch (Exception e)
                {
                    Barotrauma.LuaCsLogger.Log($"DeepAmmoLoader package delivery failed: {e.Message}");
                }
                if (delivered) { RefreshSupplies(); Changed(); }
                else
                {
                    try { spawned.Condition = 0; }
                    finally { spawner.AddItemToRemoveQueue(spawned); }
                }
                if (revision != before) { PublishState(); }
            });
        return true;
    }

    public override void Update(float deltaTime, Camera cam)
    {
        UpdateTargetSelection();
        if (!IsAuthority) { return; }
#if CLIENT
        if (Screen.Selected == GameMain.SubEditorScreen) { return; }
#endif
        scanTimer -= deltaTime;
        if (scanTimer > 0) { return; }
        scanTimer = 0.25f;
        bool changed = RefreshSupplies();
        if (Ready && !supplyError && Entity.Spawner is { Removed: false } spawner)
        {
            foreach (var source in inputContainer!.Inventory.AllItems.ToArray())
            {
                if (supplyByItem.ContainsKey(source)) { continue; }
                var package = source.GetComponent<VirtualizedAmmoStorage>();
                if (package == null || source.Removed || source.IsInRemoveQueue) { continue; }
                string id = package.AmmoIdentifier.Value;
                if (!IsProjectile(id) || source.ContainedItems.Any()) { continue; }
                if (source.Condition <= 0) { spawner.AddItemToRemoveQueue(source); continue; }
                int amount = (int)source.Condition;
                if (UseSupplyStorage)
                {
                    if (amount < 1 || !TryPrepareReturn(new Dictionary<string, int> { [id] = amount }, out var stored, out var credits)) { continue; }
                    credits.Add((source, source.Condition, source.Condition - amount));
                    if (!TryApplySupplyChanges(credits)) { continue; }
                    Stock.TryAdd(stored);
                    if (source.Condition == 0) { spawner.AddItemToRemoveQueue(source); }
                    RefreshSupplies();
                    changed = true;
                    continue;
                }
                if (!Stock.TryAdd(new Dictionary<string, int> { [id] = amount })) { continue; }
                // Zero the saved VCE storage before queuing removal, so it cannot be deposited twice.
                source.Condition = 0;
                spawner.AddItemToRemoveQueue(source);
                changed = true;
            }
        }
        if (changed) { Changed(); PublishState(); }
    }

    private static bool SameMagazineContents(VirtualizedMagazine magazine, Item other) =>
        other.Prefab == magazine.Item.Prefab && other.GetComponent<VirtualizedMagazine>() is { } peer &&
        peer.LoadedAmmoIdentifiers.SequenceEqual(magazine.LoadedAmmoIdentifiers);

    private static void RestackChangedMagazine(VirtualizedMagazine magazine)
    {
        var item = magazine.Item;
        if (item.ParentInventory is not { } source || item.GetRootInventoryOwner() is not Character user) { return; }
        var indices = source.FindIndices(item);
        bool needsSplit = indices.Any(i => source.GetItemsAt(i).Any(other => other != item && !SameMagazineContents(magazine, other)));
        if (!needsSplit && (indices is not [var slot] ||
            source.GetItemsAt(slot).Any(other => other != item) || InWeapon(item) ||
            (source is CharacterInventory worn && worn.SlotTypes[slot] != InvSlotType.Any))) { return; }

        bool Matches(Item other) => SameMagazineContents(magazine, other);
        if (!TryPlaceCarriedItem(item, user, stack: true, Matches) && needsSplit &&
            !TryPlaceCarriedItem(item, user, stack: false)) { item.Drop(user); }
    }

    internal static bool TryPlaceCarriedItem(Item item, Character user, bool stack, Func<Item, bool>? matches = null)
    {
        if (item.ParentInventory is not { } source) { return false; }
        bool TryPlace(Inventory inventory)
        {
            for (int i = 0; i < inventory.Capacity; i++)
            {
                if ((inventory.GetItemAt(i) != null) != stack ||
                    (inventory is CharacterInventory character && character.SlotTypes[i] != InvSlotType.Any) ||
                    !inventory.CanBePutInSlot(item, i)) { continue; }
                // Full magazines can have the same condition but different firing orders.
                if (stack && !inventory.GetItemsAt(i).All(other => other != item && (matches == null || matches(other)))) { continue; }
                if (inventory.TryPutItem(item, i, allowSwapping: false, allowCombine: false, user, triggerOnInsertedEffects: false))
                { return true; }
            }
            return false;
        }
        return TryPlace(source) || (source != user.Inventory && TryPlace(user.Inventory));
    }

    private static bool InWeapon(Item item)
    {
        for (var owner = item.ParentInventory?.Owner as Item; owner != null; owner = owner.ParentInventory?.Owner as Item)
        {
            if (owner.GetComponent<RangedWeapon>() != null) { return true; }
        }
        return false;
    }

    private static List<VirtualizedMagazine> BatchTargets(Character? user, VirtualizedMagazine? selected)
    {
        var targets = new List<VirtualizedMagazine>();
        if (user?.Inventory == null || selected == null || GetOwnedMagazine(selected.Item, user) != selected || InWeapon(selected.Item))
        { return targets; }
        if (selected.LoadedCount < selected.MaxSize) { targets.Add(selected); }
        void Collect(Inventory inventory)
        {
            foreach (var item in inventory.AllItems)
            {
                if (item.Removed || item.IsInRemoveQueue || item.GetComponent<RangedWeapon>() != null) { continue; }
                if (item.GetComponent<VirtualizedMagazine>() is { } magazine)
                {
                    if (item != selected.Item && item.Prefab == selected.Item.Prefab && magazine.LoadedCount == 0)
                    { targets.Add(magazine); }
                    continue;
                }
                foreach (var container in item.GetComponents<ItemContainer>()) { Collect(container.Inventory); }
            }
        }
        Collect(user.Inventory);
        return targets;
    }

    private sealed record BatchResult(int Loaded, int Total, bool Shortage);

    private BatchResult LoadBatch(Character? user, VirtualizedMagazine? selected, IReadOnlyList<AmmoRun> plan)
    {
        if (!IsAuthority || !Ready || !AmmoPlan.IsValid(plan, AmmoPlan.MaxRounds)) { return new(0, 0, false); }
        // Snapshot the instances before loading moves them to new slots or drops them.
        var targets = BatchTargets(user, selected);
        int loaded = 0;
        bool shortage = false;
        foreach (var magazine in targets)
        {
            if (GetOwnedMagazine(magazine.Item, user) != magazine || InWeapon(magazine.Item) ||
                (magazine != selected && magazine.LoadedCount != 0)) { continue; }
            if (!TryLoadValidated(plan, magazine, out shortage)) { break; }
            loaded++;
        }
        return new(loaded, targets.Count, shortage);
    }

    private bool TryLoad(IReadOnlyList<AmmoRun> plan, VirtualizedMagazine? magazine) =>
        AmmoPlan.IsValid(plan, AmmoPlan.MaxRounds) && TryLoadValidated(plan, magazine, out _);

    private bool TryLoadValidated(IReadOnlyList<AmmoRun> plan, VirtualizedMagazine? magazine, out bool shortage)
    {
        shortage = false;
        if (!IsAuthority || !Ready || magazine == null || magazine.LoadedCount >= magazine.MaxSize)
        {
            return false;
        }
        int planned = plan.Sum(run => run.Count);
        int countToLoad = Math.Min(planned, magazine.MaxSize - magazine.LoadedCount);
        int skip = planned - countToLoad;
        var demand = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var toLoad = new List<Identifier>(countToLoad);
        foreach (var run in plan)
        {
            int skipped = Math.Min(skip, run.Count);
            skip -= skipped;
            int count = run.Count - skipped;
            if (count == 0) { continue; }
            if (!demand.TryGetValue(run.Id, out int previous) && !IsCompatible(magazine, run.Id)) { return false; }
            demand[run.Id] = previous + count;
            var id = run.Id.ToIdentifier();
            for (int j = 0; j < count; j++) { toLoad.Add(id); }
        }
        // The plan's tail is inserted first, with the next round ending up on top.
        toLoad.Reverse();
        if (RefreshSupplies()) { Changed(); }
        var quote = QuoteSupply(demand);
        if (!TryPrepareSupplyDebit(quote, out var debits)) { shortage = !quote.CanLoad; return false; }
        var original = magazine.LoadedAmmoIdentifiersArray;
        try { magazine.LoadAmmoArray(ref toLoad); }
        catch (Exception e)
        {
            RestoreMagazine(magazine, original);
            Barotrauma.LuaCsLogger.Log($"DeepAmmoLoader load rolled back: {e.Message}");
            return false;
        }
        if (toLoad.Count != 0)
        {
            RestoreMagazine(magazine, original);
            return false;
        }
        if (!TryCommitSupplyDebit(quote, debits))
        {
            RestoreMagazine(magazine, original);
            return false;
        }
        RestackChangedMagazine(magazine);
        RefreshSupplies();
        Changed();
        return true;
    }

    private bool TryUnload(VirtualizedMagazine? magazine)
    {
        if (!IsAuthority || !Ready || magazine == null || magazine.LoadedCount == 0) { return false; }
        if (RefreshSupplies()) { Changed(); }
        var returned = AmmoStock.Count(magazine.LoadedAmmoIdentifiers.Select(id => id.Value));
        if (!TryPrepareReturn(returned, out var stored, out var credits)) { return false; }
        var original = magazine.LoadedAmmoIdentifiersArray;
        try { magazine.UnLoadAmmoArray(out _); }
        catch (Exception e)
        {
            RestoreMagazine(magazine, original);
            Barotrauma.LuaCsLogger.Log($"DeepAmmoLoader unload rolled back: {e.Message}");
            return false;
        }
        if (!TryApplySupplyChanges(credits))
        {
            RestoreMagazine(magazine, original);
            return false;
        }
        Stock.TryAdd(stored);
        RestackChangedMagazine(magazine);
        RefreshSupplies();
        Changed();
        return true;
    }

    internal static void RestoreMagazine(VirtualizedMagazine magazine, Identifier[] rounds)
    {
        magazine.LoadedAmmoIdentifiers.Clear();
        try { magazine.LoadedAmmoIdentifiersArray = rounds; }
        catch (Exception e)
        {
            Barotrauma.LuaCsLogger.Log($"DeepAmmoLoader restored rounds; projectile refresh failed: {e.Message}");
        }
    }

    private void Changed() => revision++;

    partial void PublishState();

    public override XElement Save(XElement parentElement)
    {
        var saved = base.Save(parentElement);
        saved.Add(invalidStock == null ? Stock.Save() : new XElement(invalidStock));
        return saved;
    }

    public override void Load(ContentXElement element, bool usePrefabValues, IdRemap idRemap, bool isItemSwap)
    {
        // Old submarine saves must not override the prefab's current container order.
        var containerIndices = (InputContainerIndex, TargetContainerIndex, OutputContainerIndex);
        base.Load(element, usePrefabValues, idRemap, isItemSwap);
        (InputContainerIndex, TargetContainerIndex, OutputContainerIndex) = containerIndices;
        var saved = element?.Element.Element("Stock");
        try { Stock.Load(saved); invalidStock = null; }
        catch (Exception e) when (e is FormatException or OverflowException)
        {
            invalidStock = saved == null ? null : new XElement(saved);
            Barotrauma.LuaCsLogger.Log($"DeepAmmoLoader stock preserved but disabled: {e.Message}");
        }
    }

    private enum Command : byte { Refresh, Load, Unload, Withdraw, LoadBatch }
    private sealed record Request(Command Command, uint Revision, ushort Target, AmmoRun[] Plan) : IEventData;
}
