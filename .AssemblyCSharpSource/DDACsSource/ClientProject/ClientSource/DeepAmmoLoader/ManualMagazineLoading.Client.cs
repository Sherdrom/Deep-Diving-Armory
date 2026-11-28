using Barotrauma.Extensions;
using Barotrauma.Networking;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace DDA.AmmoLoading;

[HarmonyPatch]
public sealed partial class ManualMagazineLoading
{
    private static KeyOrMouse StopKey => DeepDivingArmory.PluginSettings.GetKey("StopManualLoading", Keys.Escape);
    private static uint nextSession;
    private static ManualMagazineLoading? local;
    private static ManualMagazineLoading? justFinished;
    private static SoundPrefab? lastPressSound;
    private static double hideAt;
    private GUIButton? unloadButton;

    private sealed record Request(uint Session, ushort[] Sources, (ushort Owner, int Container, int Slot) Target = default) : IEventData;
    public override bool ValidateEventData(NetEntityEvent.IData data) => TryExtractEventData<Request>(data, out _);
    public void ClientEventWrite(IWriteMessage msg, NetEntityEvent.IData extraData = null!)
    {
        var request = ExtractEventData<Request>(extraData);
        msg.WriteUInt32(request.Session);
        msg.WriteUInt16(request.Sources.Length > 1 ? ushort.MaxValue : request.Sources.FirstOrDefault());
        if (request.Sources.Length == 0) { return; }
        msg.WriteUInt16(request.Target.Owner);
        msg.WriteInt32(request.Target.Container);
        msg.WriteInt32(request.Target.Slot);
        if (request.Sources.Length == 1) { return; }
        msg.WriteByte((byte)request.Sources.Length);
        foreach (ushort id in request.Sources) { msg.WriteUInt16(id); }
    }

    public void ClientEventRead(IReadMessage msg, float sendingTime)
    {
        ushort user = msg.ReadUInt16();
        uint token = msg.ReadUInt32();
        int rounds = msg.ReadInt32();
        float seconds = msg.ReadSingle();
        if (local != this || Character.Controlled?.ID != user || session != token) { return; }
        if (seconds != 0 && (duration == 0 || (Unloading ? rounds < loaded : rounds > loaded)))
        {
            // The first server response supplies the starting count.
            if (duration > 0) { PlayPressSound(); }
            loaded = rounds;
        }
        if (seconds <= 0)
        {
            if (seconds == 0 && duration == 0) { SoundPlayer.PlayUISound(GUISoundType.PickItemFail); }
            End(seconds < 0);
            return;
        }
        elapsed = 0;
        duration = seconds;
    }

    private static void PlayPressSound()
    {
        lastPressSound = SoundPrefab.Prefabs.GetRandomUnsynced(p => p.ElementName == "dda_manual_press" && p != lastPressSound);
        lastPressSound?.Sound?.Play(null, lastPressSound.Volume, Rand.Range(0.94f, 1.06f, Rand.RandSync.Unsynced));
    }

    public override void AddToGUIUpdateList(int order = 0)
    {
        if (Screen.Selected != GameMain.GameScreen || Character.Controlled is not { } user || !HeldBy(user) ||
            !CharacterHUD.ShouldDrawInventory(user) || user.SelectedItem != null && user.SelectedItem != Item) { return; }
        int top = HUDLayoutSettings.InventoryTopY;
        if (top <= 0) { return; }
        var size = new Point((int)(144 * GUI.Scale), (int)(34 * GUI.Scale));
        int gap = (int)(6 * GUI.Scale);
        unloadButton ??= new GUIButton(new RectTransform(size, GUI.Canvas, Anchor.TopCenter), "", style: "GUIButtonSmallFreeScale")
        {
            OnClicked = (_, _) =>
            {
                if (local == this && Unloading) { CancelLocal(); return true; }
                bool started = Character.Controlled is { } player && StartLocal(player, [Item]);
                if (!started) { SoundPlayer.PlayUISound(GUISoundType.PickItemFail); }
                return started;
            }
        };
        bool left = user.HasEquippedItem(Item, InvSlotType.LeftHand);
        unloadButton.RectTransform.NonScaledSize = size;
        unloadButton.RectTransform.AbsoluteOffset = new Point((left ? -1 : 1) * (size.X + gap) / 2, Math.Max(0, top - size.Y - gap));
        unloadButton.Text = TextManager.Get(Unloading ? "dda.manualunload.stop" : "dda.manualunload.start");
        unloadButton.ToolTip = Item.Name;
        unloadButton.Enabled = Unloading || (local == null && user.CanInteract && magazine is { LoadedCount: > 0 });
        unloadButton.AddToGUIUpdateList(order: order);
    }

    internal static bool HandleDrop()
    {
        if (Screen.Selected != GameMain.GameScreen || GUI.InputBlockingMenuOpen || Character.Controlled is not { } user ||
            !PlayerInput.PrimaryMouseButtonReleased() || Inventory.DraggingItems.FirstOrDefault() is not { } source ||
            !source.HasTag(packageTag) || Inventory.SelectedSlot is not { Item: { } target } slot ||
            !slot.Slot.MouseOn() || !source.IsOwnedBy(user) || !target.IsOwnedBy(user) ||
            target.GetComponent<ManualMagazineLoading>() is not { } loading) { return false; }

        bool accepted = loading.StartLocal(user, Inventory.DraggingItems);
        Inventory.DraggingItems.Clear();
        Inventory.DraggingSlot = null;
        SoundPlayer.PlayUISound(accepted ? GUISoundType.PickItem : GUISoundType.PickItemFail);
        return true;
    }

    private bool StartLocal(Character user, IReadOnlyList<Item> sources)
    {
        if (!Begin(user, sources, ++nextSession)) { return false; }
        justFinished = null;
        local = this;
        if (Inventory.SelectedSlot is { } slot && slot.Item == Item) { slot.ForceTooltipRefresh = true; }
        if (remoteSession)
        {
            duration = 0; // Wait for the server's starting count.
            Item.CreateClientEvent(this, new Request(session, sources.Select(i => i.ID).ToArray(), TargetAddress(Item)));
        }
        return true;
    }

    private void CancelLocal()
    {
        if (remoteSession && GameMain.Client != null && !Item.Removed && !Item.IsInRemoveQueue)
        { Item.CreateClientEvent(this, new Request(session, [])); }
        End(false);
    }

    partial void NotifyEnd(bool finished)
    {
        if (local != this) { return; }
        if (finished)
        {
            justFinished = this;
            hideAt = Timing.TotalTime + 0.15;
        }
        local = null;
        if (Inventory.SelectedSlot is { } slot && slot.Item == Item) { slot.ForceTooltipRefresh = true; }
    }

    internal static void ResetClient()
    {
        local?.End(false);
        justFinished = null;
        lastPressSound = null;
    }

    public override void AddTooltipInfo(ref LocalizedString name, ref LocalizedString description)
    {
        if (local == this && SlotOf(Item) is ({ } inventory, var index) && inventory.GetItemsAt(index).Count() == 1)
        { description += "\n" + TextManager.Get(Unloading ? "dda.manualunload.hint" : "dda.manualloading.stop").Value.Replace("[key]", StopKey.GetName().Value); }
    }

    [HarmonyPatch(typeof(PlayerInput), nameof(PlayerInput.Update))]
    [HarmonyPostfix]
    private static void CheckStopInput()
    {
        if (justFinished != null && Timing.TotalTime >= hideAt) { justFinished = null; }
        if (local == null) { return; }
        if (local.owner != Character.Controlled) { local.CancelLocal(); return; }
        var key = StopKey;
        bool escape = key.MouseButton == MouseButton.None && key.Key == Keys.Escape;
        if (GUI.InputBlockingMenuOpen || (!escape && GUI.KeyboardDispatcher?.Subscriber != null) || !key.IsHit()) { return; }
        if (escape)
        {
            // Consume only this edge before GameMain tests Escape for the pause menu.
            var previous = PlayerInput.oldKeyboardState;
            PlayerInput.oldKeyboardState = new KeyboardState([.. previous.GetPressedKeys(), Keys.Escape],
                previous.CapsLock, previous.NumLock);
        }
        local.CancelLocal();
    }

    [HarmonyPatch(typeof(Inventory), nameof(Inventory.DrawSlot))]
    [HarmonyPostfix]
    private static void DrawProgress(SpriteBatch spriteBatch, Inventory inventory, VisualSlot slot, Item item, int slotIndex, bool drawItem)
    {
        var loading = local ?? justFinished;
        if (loading == null || loading.Item != item || inventory == null || !drawItem || item.ParentInventory != inventory) { return; }
        if (SlotOf(item).Index != slotIndex || inventory.GetItemsAt(slotIndex).Count() != 1) { return; }
        float progress = loading.CapacityProgress;
        Vector2 center = slot.Rect.Center.ToVector2() + slot.DrawOffset;
        float radius = Math.Min(slot.Rect.Width, slot.Rect.Height) * 0.36f;
        float width = Math.Max(3, MathF.Round(radius / 5));
        var radii = new Range<float>(radius - width, radius);
        GUI.DrawDonutSection(spriteBatch, center, radii, MathF.Tau, Color.Black * 0.65f);
        if (progress > 0) { GUI.DrawDonutSection(spriteBatch, center, radii, MathF.Tau * progress, GUIStyle.Green); }
    }
}
