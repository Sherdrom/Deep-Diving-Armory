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
    private Inventory? sourceInventory, targetInventory;
    private int sourceSlot, targetSlot, loaded, remaining;
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

    private bool Begin(Character user, Item source, uint token)
    {
        if (owner != null || active.ContainsKey(user) || !user.CanInteract || magazine == null || !Accessible(Item, user))
        { return false; }
        VirtualizedAmmoStorage? storage = null;
        // The magazine's own ID requests unloading; zero is reserved for cancellation.
        if (source == Item)
        {
            if (!HeldBy(user) || magazine.LoadedCount == 0) { return false; }
        }
        else
        {
            storage = source.GetComponent<VirtualizedAmmoStorage>();
            if (!Accessible(source, user) || !source.HasTag(packageTag) || storage == null || source.Condition < 1 ||
                magazine.LoadedCount >= magazine.MaxSize || !DeepAmmoLoader.IsCompatible(magazine, storage.AmmoIdentifier.Value))
            { return false; }
        }

        sourceInventory = source.ParentInventory;
        targetInventory = Item.ParentInventory;
        sourceSlot = sourceInventory?.FindIndex(source) ?? -1;
        targetSlot = targetInventory?.FindIndex(Item) ?? -1;
        if (sourceSlot < 0 || targetSlot < 0) { return false; }

        owner = user;
        package = storage;
        session = token;
        loaded = magazine.LoadedCount;
        remaining = storage == null ? loaded : Math.Min((int)source.Condition, magazine.MaxSize - loaded);
        elapsed = 0;
        duration = RoundTime(user);
        active.Add(user, this);
        IsActive = true;
        return true;
    }

    private bool HeldBy(Character user) => user.HasEquippedItem(Item, InvSlotType.LeftHand | InvSlotType.RightHand);

    private bool StillInPlace(Character user, Item source) =>
        user.CanInteract && Accessible(Item, user) && Accessible(source, user) &&
        (source != Item || HeldBy(user)) &&
        source.ParentInventory == sourceInventory && Item.ParentInventory == targetInventory &&
        sourceInventory!.FindIndex(source) == sourceSlot && targetInventory!.FindIndex(Item) == targetSlot;

    private bool CanContinue(Character user, Item source) =>
#if SERVER
        (requester == null || (requester.InGame && requester.Character == user)) &&
#else
        Character.Controlled == user &&
#endif
        StillInPlace(user, source);

    public override void Update(float deltaTime, Camera cam)
    {
        if (owner == null || magazine == null) { return; }
        Item source = package?.Item ?? Item;
#if CLIENT
        if (owner != Character.Controlled) { CancelLocal(); return; }
        if (GameMain.Client != null)
        {
            // The empty package may disappear just before the server's final progress event.
            if ((Unloading || (!source.IsInRemoveQueue && !source.Removed)) && !StillInPlace(owner, source))
            { CancelLocal(); return; }
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
        if (source.Condition == 0 && !source.IsInRemoveQueue) { Entity.Spawner?.AddItemToRemoveQueue(source); }
        FinishRound();
    }

    private void FinishRound()
    {
        loaded = magazine!.LoadedCount;
#if CLIENT
        PlayPressSound();
#endif
        remaining--;
        if (remaining == 0 || package?.Item.Condition < 1)
        {
            End(true);
            return;
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

    private static bool CommitRound(VirtualizedAmmoStorage storage, VirtualizedMagazine magazine, bool unloading)
    {
        var original = magazine.LoadedAmmoIdentifiersArray;
        float before = storage.Item.Condition;
        float after = before + (unloading ? 1 : -1);
        try
        {
            if (unloading)
            {
                if (after > storage.Item.MaxCondition || !magazine.LoadedAmmoIdentifiers.TryPeek(out var top) ||
                    top != storage.AmmoIdentifier) { return false; }
                magazine.LoadedAmmoIdentifiers.Pop();
                magazine.UpdateAmmoData();
            }
            else
            {
                List<Identifier> round = [storage.AmmoIdentifier];
                magazine.LoadAmmoArray(ref round);
                if (round.Count != 0) { return false; }
            }
            storage.Item.Condition = after;
            if (storage.Item.Condition == after)
            {
#if SERVER
                // Vanilla may defer a one-point condition change until a second round is loaded.
                storage.Item.CreateStatusEvent(loadingRound: false);
#endif
                return true;
            }
        }
        catch (Exception e) { LuaCsLogger.Log($"DDA manual loading failed: {e.Message}"); }

        DeepAmmoLoader.RestoreMagazine(magazine, original);
        if (storage.Item.Condition != before) { storage.Item.SetCondition(before, isNetworkEvent: false, executeEffects: false); }
        return false;
    }

    private void End(bool finished)
    {
        if (owner == null) { return; }
        NotifyEnd(finished);
        active.Remove(owner);
        owner = null;
        package = null;
        pendingPackage = null;
        targetInventory = sourceInventory = null;
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
