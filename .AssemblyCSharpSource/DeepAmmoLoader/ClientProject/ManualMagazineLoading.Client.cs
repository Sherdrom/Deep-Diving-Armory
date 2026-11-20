using Barotrauma.LuaCs.Data;
using Barotrauma.Networking;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace DDA.AmmoLoading;

[HarmonyPatch]
public sealed partial class ManualMagazineLoading
{
    internal static ISettingControl? StopControl;
    private static readonly KeyOrMouse defaultStop = new(Keys.Escape);
    private static KeyOrMouse StopKey => StopControl?.Value ?? defaultStop;
    private static uint nextSession;
    private static ManualMagazineLoading? local;
    private static ManualMagazineLoading? justFinished;
    private static double hideAt;

    private sealed record Request(uint Session, ushort Source) : IEventData;
    public override bool ValidateEventData(NetEntityEvent.IData data) => TryExtractEventData<Request>(data, out _);
    public void ClientEventWrite(IWriteMessage msg, NetEntityEvent.IData extraData = null!)
    {
        var request = ExtractEventData<Request>(extraData);
        msg.WriteUInt32(request.Session);
        msg.WriteUInt16(request.Source);
    }

    public void ClientEventRead(IReadMessage msg, float sendingTime)
    {
        ushort user = msg.ReadUInt16();
        uint token = msg.ReadUInt32();
        int rounds = msg.ReadInt32();
        float seconds = msg.ReadSingle();
        if (local != this || Character.Controlled?.ID != user || session != token) { return; }
        if (seconds != 0) { loaded = rounds; }
        if (seconds <= 0) { End(seconds < 0); return; }
        elapsed = 0;
        duration = seconds;
    }

    internal static bool HandleDrop()
    {
        if (Screen.Selected != GameMain.GameScreen || GUI.InputBlockingMenuOpen || Character.Controlled is not { } user ||
            !PlayerInput.PrimaryMouseButtonReleased() || Inventory.DraggingItems.FirstOrDefault() is not { } source ||
            !source.HasTag(packageTag) || Inventory.SelectedSlot is not { Item: { } target } slot ||
            !slot.Slot.MouseOn() || !source.IsOwnedBy(user) || !target.IsOwnedBy(user) ||
            target.GetComponent<ManualMagazineLoading>() is not { } loading) { return false; }

        bool accepted = loading.Begin(user, source, ++nextSession);
        if (accepted)
        {
            justFinished = null;
            local = loading;
            if (GameMain.Client != null)
            {
                loading.duration = 0; // Wait for the server's first round before animating.
                loading.Item.CreateClientEvent(loading, new Request(loading.session, source.ID));
            }
            slot.ForceTooltipRefresh = true;
        }
        Inventory.DraggingItems.Clear();
        Inventory.DraggingSlot = null;
        SoundPlayer.PlayUISound(accepted ? GUISoundType.PickItem : GUISoundType.PickItemFail);
        return true;
    }

    private void CancelLocal()
    {
        if (GameMain.Client != null && !Item.Removed && !Item.IsInRemoveQueue)
        { Item.CreateClientEvent(this, new Request(session, 0)); }
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
        StopControl = null;
    }

    public override void AddTooltipInfo(ref LocalizedString name, ref LocalizedString description)
    {
        if (local == this)
        { description += "\n" + TextManager.Get("dda.manualloading.stop").Value.Replace("[key]", StopKey.GetName().Value); }
    }

    [HarmonyPatch(typeof(SettingControl), nameof(SettingControl.GetDefaultStringValue))]
    [HarmonyPostfix]
    private static void RestoreDefaultKey(SettingControl __instance, ref string __result)
    {
        // LuaCs resets every control to NumLock and reserves Escape in the binding picker.
        if (ReferenceEquals(__instance, StopControl)) { __result = defaultStop.ToString(); }
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
    private static void DrawProgress(SpriteBatch spriteBatch, Inventory inventory, VisualSlot slot, Item item, bool drawItem)
    {
        var loading = local ?? justFinished;
        if (loading == null || loading.Item != item || inventory == null || !drawItem || item.ParentInventory != inventory) { return; }
        float progress = CapacityProgress(loading.loaded, loading.magazine!.MaxSize,
            loading == local ? loading.elapsed : 0, loading.duration);
        Vector2 center = slot.Rect.Center.ToVector2() + slot.DrawOffset;
        float radius = Math.Min(slot.Rect.Width, slot.Rect.Height) * 0.43f;
        float width = Math.Max(2, MathF.Round(radius / 10));
        var radii = new Range<float>(radius - width, radius);
        GUI.DrawDonutSection(spriteBatch, center, radii, MathF.Tau, Color.Black * 0.65f);
        if (progress > 0) { GUI.DrawDonutSection(spriteBatch, center, radii, MathF.Tau * progress, GUIStyle.Green); }
    }
}
