using Barotrauma.Items.Components;
using Barotrauma.Networking;
using VCE_VirtualizedMagazine;

namespace DDA.AmmoLoading;

public sealed partial class ManualMagazineLoading : ItemComponent, IClientSerializable, IServerSerializable
{
    private static readonly Dictionary<Character, ManualMagazineLoading> active = new();
    private static readonly Identifier packageTag = "deep_ammopackage".ToIdentifier();
    private static readonly Identifier weapons = "weapons".ToIdentifier();
    private VirtualizedMagazine? magazine;
    private VirtualizedAmmoStorage? package;
    private Character? owner;
    private (Inventory? Inventory, int Index) sourceSlot, originalStack, targetSlot;
    private Queue<Item>? nextPackages;
    private int loaded;
    private float elapsed, duration;
    private uint session;
    private ItemPrefab? pendingPackage;
    private bool Unloading => owner != null && package == null;

    public ManualMagazineLoading(Item item, ContentXElement element) : base(item, element)
    {
        UpdateWhenBroken = true; // An empty virtual magazine has zero condition.
        IsActive = false;
#if CLIENT
        DrawHudWhenEquipped = true;
#endif
    }

    public override void OnItemLoaded() => magazine = Item.GetComponent<VirtualizedMagazine>();

    private static float RoundTime(Character user) =>
        1f - 0.6f * (Math.Clamp(user.GetSkillLevel(weapons), 0f, 100f) / 100f);

    internal float CapacityProgress => magazine is { MaxSize: > 0 }
        ? Math.Clamp((float)loaded / magazine.MaxSize, 0f, 1f)
        : 0f;

    private static bool Accessible(Item item, Character user) =>
        !item.Removed && !item.IsInRemoveQueue && item.IsOwnedBy(user) && user.CanInteractWith(item);

    private static (Inventory? Inventory, int Index) SlotOf(Item item) =>
        (item.ParentInventory, item.ParentInventory?.FindIndex(item) ?? -1);

    private bool Begin(Character user, IReadOnlyList<Item> sources, uint token)
    {
        if (sources.Count is 0 or > Inventory.MaxPossibleStackSize || owner != null || active.ContainsKey(user) ||
            !user.CanInteract || magazine == null || !Accessible(Item, user))
        { return false; }
        var source = sources[0];
        var slot = SlotOf(source);
        targetSlot = SlotOf(Item);
        if (slot.Index < 0 || targetSlot.Index < 0) { return false; }
        VirtualizedAmmoStorage? storage = null;
        // The magazine's own ID requests unloading; zero is reserved for cancellation.
        if (source == Item)
        {
            if (sources.Count != 1 || !HeldBy(user) || magazine.LoadedCount == 0) { return false; }
        }
        else
        {
            storage = source.GetComponent<VirtualizedAmmoStorage>();
            if (!Accessible(source, user) || !source.HasTag(packageTag) || storage == null || source.Condition < 1 ||
                magazine.LoadedCount >= magazine.MaxSize || !DeepAmmoLoader.IsCompatible(magazine, storage.AmmoIdentifier.Value))
            { return false; }
            if (sources.Count > 1 && (sources.Distinct().Count() != sources.Count || sources.Skip(1).Any(other =>
                other.Prefab != source.Prefab || SlotOf(other) != slot || !Accessible(other, user) || other.Condition < 1 ||
                other.GetComponent<VirtualizedAmmoStorage>()?.AmmoIdentifier != storage.AmmoIdentifier))) { return false; }
        }

        sourceSlot = originalStack = slot;
        nextPackages = sources.Count > 1 ? new Queue<Item>(sources.Skip(1)) : null;
        owner = user;
        package = storage;
        session = token;
        loaded = magazine.LoadedCount;
        elapsed = 0;
        duration = RoundTime(user);
        active.Add(user, this);
        IsActive = true;
        return true;
    }

    private bool HeldBy(Character user) => user.HasEquippedItem(Item, InvSlotType.LeftHand | InvSlotType.RightHand);

    private bool TargetInPlace(Character user) => user.CanInteract && Accessible(Item, user) &&
        SlotOf(Item) == targetSlot && (!Unloading || HeldBy(user));

    private bool CanContinue(Character user, Item source) =>
#if SERVER
        (requester == null || (requester.InGame && requester.Character == user)) &&
#else
        Character.Controlled == user &&
#endif
        TargetInPlace(user) && Accessible(source, user) && SlotOf(source) == sourceSlot;

    public override void Update(float deltaTime, Camera cam)
    {
        if (owner == null || magazine == null) { return; }
        Item source = package?.Item ?? Item;
#if CLIENT
        if (owner != Character.Controlled) { CancelLocal(); return; }
        if (GameMain.Client != null)
        {
            // The authority splits and replaces source packages as the selected stack is consumed.
            if (!TargetInPlace(owner)) { CancelLocal(); return; }
            elapsed += deltaTime;
            if (duration == 0 && elapsed > 10) { CancelLocal(); }
            return;
        }
#endif
        if (!CanContinue(owner, source)) { End(false); return; }
        if (magazine.LoadedCount != loaded || (package != null && (source.Condition < 1 || loaded >= magazine.MaxSize)))
        { End(false); return; }
        if (pendingPackage != null)
        {
            // A full inventory can make the native spawner discard a request without a callback.
            if (Entity.Spawner?.IsInSpawnQueue(s => s is EntitySpawner.ItemSpawnInfo i &&
                i.Inventory == owner.Inventory && i.Prefab == pendingPackage) != true) { End(false); }
            return;
        }
        elapsed += deltaTime;
        if (elapsed < duration) { return; }
        if (package == null) { UnloadRound(owner, magazine); return; }
        if (!CommitRound(package, magazine, unloading: false)) { End(false); return; }
        sourceSlot = SlotOf(source);
        if (source.Condition == 0 && !source.IsInRemoveQueue) { Entity.Spawner?.AddItemToRemoveQueue(source); }
        FinishRound();
    }

    private void FinishRound()
    {
        loaded = magazine!.LoadedCount;
#if CLIENT
        PlayPressSound();
#endif
        if (Unloading ? loaded == 0 : loaded >= magazine.MaxSize)
        {
            End(true);
            return;
        }
        if (package is { Item.Condition: < 1 })
        {
            if (nextPackages == null || !nextPackages.TryDequeue(out var next)) { End(true); return; }
            if (SlotOf(next) != originalStack || !Accessible(next, owner!) || next.Condition < 1 ||
                next.GetComponent<VirtualizedAmmoStorage>() is not { } storage || storage.AmmoIdentifier != package.AmmoIdentifier)
            { End(false); return; }
            package = storage;
            sourceSlot = originalStack;
        }
        elapsed -= duration;
        duration = RoundTime(owner!);
        PublishProgress();
    }

    private void UnloadRound(Character user, VirtualizedMagazine mag)
    {
        if (!mag.LoadedAmmoIdentifiers.TryPeek(out var ammo)) { End(false); return; }
        var destination = user.Inventory.FindItem(i => i.Condition + 1 <= i.MaxCondition &&
            i.GetComponent<VirtualizedAmmoStorage>()?.AmmoIdentifier == ammo && i.GetComponent<ItemContainer>() == null &&
            Accessible(i, user), recursive: true);
        if (destination?.GetComponent<VirtualizedAmmoStorage>() is { } existing)
        {
            if (CommitRound(existing, mag, unloading: true)) { FinishRound(); }
            else { End(false); }
            return;
        }

        var prefab = DeepAmmoLoader.FindWithdrawalPackage(ammo.Value);
        if (prefab == null || Entity.Spawner is not { Removed: false } spawner ||
            !user.Inventory.CanProbablyBePut(prefab, 1, quality: 0)) { End(false); return; }
        uint token = session;
        pendingPackage = prefab;
        // Only debit the magazine once the new package has actually reached this player's inventory.
        spawner.AddItemToSpawnQueue(prefab, user.Inventory, condition: 0, quality: 0, spawnIfInventoryFull: false, onSpawned: item =>
        {
            bool current = session == token && owner == user && pendingPackage == prefab;
            if (current)
            {
                pendingPackage = null;
                if (item.ParentInventory == user.Inventory && Accessible(item, user) && item.Condition == 0 &&
                    CanContinue(user, Item) && mag.LoadedCount == loaded &&
                    item.GetComponent<VirtualizedAmmoStorage>() is { } storage && storage.AmmoIdentifier == ammo &&
                    CommitRound(storage, mag, unloading: true))
                { FinishRound(); return; }
                End(false);
            }
            spawner.AddItemToRemoveQueue(item);
        });
    }

    private bool CommitRound(VirtualizedAmmoStorage storage, VirtualizedMagazine magazine, bool unloading)
    {
        var item = storage.Item;
        float before = item.Condition;
        float after = before + (unloading ? 1 : -1);
        if (unloading && (after > item.MaxCondition || !magazine.LoadedAmmoIdentifiers.TryPeek(out var top) ||
            top != storage.AmmoIdentifier)) { return false; }
        var (inventory, slot) = SlotOf(item);
        if (inventory == null || slot < 0) { return false; }
        bool split = after > 0 && inventory.GetItemsAt(slot).Any(other => other != item);
        if (split && !DeepAmmoLoader.TryPlaceCarriedItem(item, owner!, stack: false)) { return false; }
        var original = magazine.LoadedAmmoIdentifiersArray;
        bool committed = false;
        try
        {
            if (unloading)
            {
                magazine.LoadedAmmoIdentifiers.Pop();
                magazine.UpdateAmmoData();
                item.Condition = after;
            }
            else
            {
                List<Identifier> round = [storage.AmmoIdentifier];
                magazine.LoadAmmoArray(ref round);
                if (round.Count == 0) { item.Condition = after; }
            }
            committed = item.Condition == after;
        }
        catch (Exception e) { DebugConsole.NewMessage($"DDA manual loading failed: {e.Message}"); }

        if (!committed)
        {
            DeepAmmoLoader.RestoreMagazine(magazine, original);
            if (item.Condition != before) { item.SetCondition(before, isNetworkEvent: false, executeEffects: false); }
            if (split) { inventory.TryPutItem(item, slot, false, false, owner!, triggerOnInsertedEffects: false); }
            return false;
        }
#if SERVER
        // Vanilla may defer a one-point condition change until a second round is loaded.
        item.CreateStatusEvent(loadingRound: false);
#endif
        if (unloading && item.Condition == item.MaxCondition) { StackFullPackage(storage, owner!); }
        return true;
    }

    private static void StackFullPackage(VirtualizedAmmoStorage storage, Character user)
    {
        var item = storage.Item;
        var peer = user.Inventory.FindItem(p => p != item && p.Prefab == item.Prefab && Accessible(p, user) &&
            p.GetComponent<VirtualizedAmmoStorage>()?.AmmoIdentifier == storage.AmmoIdentifier &&
            p.ParentInventory is { } parent && parent.CanBePutInSlot(item, parent.FindIndex(p)), recursive: true);
        if (peer?.ParentInventory is { } inventory)
        { inventory.TryPutItem(item, inventory.FindIndex(peer), false, false, user, triggerOnInsertedEffects: false); }
    }

    private void End(bool finished)
    {
        if (owner == null) { return; }
        NotifyEnd(finished);
        active.Remove(owner);
        owner = null;
        package = null;
        pendingPackage = null;
        nextPackages = null;
        sourceSlot = originalStack = targetSlot = default;
        IsActive = false;
    }

    partial void PublishProgress();
    partial void NotifyEnd(bool finished);

    public override void RemoveComponentSpecific()
    {
        End(false);
#if CLIENT
        if (unloadButton != null) { unloadButton.RectTransform.Parent = null; }
#endif
        base.RemoveComponentSpecific();
    }
}
