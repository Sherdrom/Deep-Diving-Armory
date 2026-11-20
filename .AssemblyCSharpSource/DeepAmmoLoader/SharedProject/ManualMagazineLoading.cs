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

    public ManualMagazineLoading(Item item, ContentXElement element) : base(item, element)
    {
        UpdateWhenBroken = true; // An empty virtual magazine has zero condition.
        IsActive = false;
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
        if (owner != null || active.ContainsKey(user) || !user.CanInteract || magazine == null ||
            !Accessible(Item, user) || !Accessible(source, user) || !source.HasTag(packageTag) ||
            source.GetComponent<VirtualizedAmmoStorage>() is not { } storage || source.Condition < 1 ||
            magazine.LoadedCount >= magazine.MaxSize || !DeepAmmoLoader.IsCompatible(magazine, storage.AmmoIdentifier.Value))
        { return false; }

        sourceInventory = source.ParentInventory;
        targetInventory = Item.ParentInventory;
        sourceSlot = sourceInventory?.FindIndex(source) ?? -1;
        targetSlot = targetInventory?.FindIndex(Item) ?? -1;
        if (sourceSlot < 0 || targetSlot < 0) { return false; }

        owner = user;
        package = storage;
        session = token;
        loaded = magazine.LoadedCount;
        remaining = Math.Min((int)source.Condition, magazine.MaxSize - loaded);
        elapsed = 0;
        duration = RoundTime(user);
        active.Add(user, this);
        IsActive = true;
        return true;
    }

    private bool StillInPlace(Character user, Item source) =>
        user.CanInteract && Accessible(Item, user) && Accessible(source, user) &&
        source.ParentInventory == sourceInventory && Item.ParentInventory == targetInventory &&
        sourceInventory!.FindIndex(source) == sourceSlot && targetInventory!.FindIndex(Item) == targetSlot;

    public override void Update(float deltaTime, Camera cam)
    {
        if (owner == null || package == null || magazine == null) { return; }
#if CLIENT
        if (owner != Character.Controlled) { CancelLocal(); return; }
        if (GameMain.Client != null)
        {
            // The empty package may disappear just before the server's final progress event.
            if (!package.Item.IsInRemoveQueue && !package.Item.Removed && !StillInPlace(owner, package.Item))
            { CancelLocal(); return; }
            elapsed += deltaTime;
            if (duration == 0 && elapsed > 10) { CancelLocal(); }
            return;
        }
#endif
        if (!StillInPlace(owner, package.Item)) { End(false); return; }
#if SERVER
        if (requester != null && (!requester.InGame || requester.Character != owner)) { End(false); return; }
#endif
        if (package.Item.Condition < 1 || magazine.LoadedCount != loaded || loaded >= magazine.MaxSize)
        { End(false); return; }
        elapsed += deltaTime;
        if (elapsed < duration) { return; }
        if (!CommitRound(package, magazine)) { End(false); return; }
        loaded++;
        remaining--;
        if (remaining == 0 || package.Item.Condition < 1 || loaded >= magazine.MaxSize)
        {
            if (package.Item.Condition == 0 && !package.Item.IsInRemoveQueue) { Entity.Spawner?.AddItemToRemoveQueue(package.Item); }
            End(true);
            return;
        }
        elapsed -= duration;
        duration = RoundTime(owner);
        PublishProgress();
    }

    private static bool CommitRound(VirtualizedAmmoStorage storage, VirtualizedMagazine magazine)
    {
        var original = magazine.LoadedAmmoIdentifiersArray;
        float before = storage.Item.Condition;
        List<Identifier> round = [storage.AmmoIdentifier];
        try
        {
            magazine.LoadAmmoArray(ref round);
            if (round.Count != 0) { return false; }
            storage.Item.Condition = before - 1;
            if (storage.Item.Condition == before - 1)
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
        targetInventory = sourceInventory = null;
        IsActive = false;
    }

    partial void PublishProgress();
    partial void NotifyEnd(bool finished);

    public override void RemoveComponentSpecific()
    {
        End(false);
        base.RemoveComponentSpecific();
    }
}
