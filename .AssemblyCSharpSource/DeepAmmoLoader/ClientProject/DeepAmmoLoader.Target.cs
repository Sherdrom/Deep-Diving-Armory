using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;

namespace DDA.AmmoLoading;

public sealed partial class DeepAmmoLoader
{
    private GUICustomComponent? targetSlot;
    private VisualSlot? targetVisualSlot;
    private Inventory.SlotReference? targetTooltipSlot;
    private bool draggingTargetSelection;

    private void CreateTargetSlot()
    {
        if (TargetContainer?.Inventory?.visualSlots.FirstOrDefault() is not { } nativeSlot) { return; }
        targetVisualSlot = new VisualSlot(nativeSlot.Rect);
        targetSlot = new GUICustomComponent(new RectTransform(nativeSlot.Rect.Size, targetHolder!.RectTransform, Anchor.Center)
            { AbsoluteOffset = nativeSlot.Rect.Center - targetHolder.Rect.Center }, DrawTargetSlot)
        {
            HoverCursor = CursorState.Hand,
            AlwaysOverrideCursor = true,
            OnDrawToolTip = _ => UpdateTargetTooltip()
        };
        UpdateTargetSlot();
    }

    private void UpdateTargetSlot()
    {
        if (TargetContainer == null || targetSlot == null) { return; }
        // Keep saved magazines reachable through the old native slot until players take them back.
        TargetContainer.DrawInventory = TargetContainer.Inventory.AllItems.Any();
        // Hidden native inventories still intercept hover while registered in ActiveHUDs.
        TargetContainer.CanBeSelected = TargetContainer.DrawInventory;
        if (!TargetContainer.DrawInventory && TargetContainer.guiCustomComponent is { } nativeInventory)
        { nativeInventory.Visible = false; }
        targetSlot.Visible = !TargetContainer.DrawInventory;
        targetHolder!.ToolTip = !targetSlot.Visible ? L("legacytargethint") : Target == null ? L("targethint") : "";
    }

    partial void UpdateTargetSelection()
    {
        bool open = Character.Controlled?.IsAnySelectedItem(Item) == true;
        if (!open) { draggingTargetSelection = false; }
        if (Target != null && (!open || GetOwnedMagazine(Target.Item, Character.Controlled) != Target))
        {
            Target = null;
            uiDirty = true;
        }
    }

    private bool SelectTarget(Item? item)
    {
        var magazine = GetOwnedMagazine(item, Character.Controlled);
        if (magazine == null) { return false; }
        Target = magazine;
        uiDirty = true;
        return true;
    }

    internal static DeepAmmoLoader? ActiveTargetLoader => GUI.InputBlockingMenuOpen ? null :
        Character.Controlled?.SelectedItem?.ActiveHUDs.OfType<DeepAmmoLoader>().FirstOrDefault(loader =>
            loader.GuiFrame is { Visible: true } frame && frame.RectTransform.Parent != null &&
            loader.targetSlot is { Visible: true });

    internal bool HandleTargetDrop()
    {
        bool hovered = targetSlot!.Rect.Contains(PlayerInput.MousePosition);
        if (draggingTargetSelection)
        {
            if (!PlayerInput.PrimaryMouseButtonHeld())
            {
                draggingTargetSelection = false;
                if (PlayerInput.PrimaryMouseButtonClicked() && !hovered) { Target = null; uiDirty = true; }
            }
            return true;
        }
        if (!Inventory.DraggingItems.Any())
        {
            if (Target != null && hovered && GUI.IsMouseOn(targetSlot) && PlayerInput.PrimaryMouseButtonDown())
            {
                draggingTargetSelection = true;
                return true;
            }
            return false;
        }
        if (!hovered || !PlayerInput.PrimaryMouseButtonReleased()) { return false; }
        bool accepted = SelectTarget(Inventory.DraggingItems.FirstOrDefault());
        // Like Gunsmith's workbench, consume the drag without moving the real item.
        Inventory.DraggingItems.Clear();
        Inventory.DraggingSlot = null;
        SoundPlayer.PlayUISound(accepted ? GUISoundType.PickItem : GUISoundType.PickItemFail);
        return true;
    }

    private void DrawTargetSlot(SpriteBatch spriteBatch, GUICustomComponent component)
    {
        // The HUD can still draw for a frame after a campaign transition releases the character.
        if (Character.Controlled is not { Removed: false } user || Item.Removed || !user.IsAnySelectedItem(Item)) { return; }
        var slot = targetVisualSlot!;
        slot.Rect = slot.InteractRect = component.Rect;
        var dragged = Inventory.DraggingItems.FirstOrDefault();
        bool hovered = !GUI.InputBlockingMenuOpen && component.Rect.Contains(PlayerInput.MousePosition) &&
            (dragged != null || GUI.IsMouseOn(component));
        slot.HighlightColor = !hovered ? Color.Transparent : dragged == null ? Color.White * 0.35f :
            GetOwnedMagazine(dragged, Character.Controlled) != null ? GUIStyle.Green : GUIStyle.Red;
        Inventory.DrawSlot(spriteBatch, null, slot, Target?.Item, -1,
            drawItem: !draggingTargetSelection || component.Rect.Contains(PlayerInput.MousePosition));
    }

    private void UpdateTargetTooltip()
    {
        targetSlot!.ToolTip = Target == null ? L("targethint") : "";
        if (draggingTargetSelection || Inventory.DraggingItems.Any() ||
            Target?.Item is not { ParentInventory: { } inventory } item) { return; }
        int index = inventory.FindIndex(item);
        if (index < 0) { return; }
        if (targetTooltipSlot?.Item != item || targetTooltipSlot.ParentInventory != inventory || targetTooltipSlot.SlotIndex != index)
        { targetTooltipSlot = new Inventory.SlotReference(inventory, targetVisualSlot!, index, isSubSlot: false); }
        else if (targetTooltipSlot.TooltipNeedsRefresh()) { targetTooltipSlot.RefreshTooltip(); }
        targetSlot.ToolTip = targetTooltipSlot.Tooltip;
    }

    internal void DrawTargetDrag(SpriteBatch spriteBatch)
    {
        if (!draggingTargetSelection || Target?.Item is not { } item || targetSlot!.Rect.Contains(PlayerInput.MousePosition)) { return; }
        var sprite = item.OverrideInventorySprite ?? item.Prefab.InventoryIcon ?? item.Sprite;
        if (sprite == null) { return; }
        float size = 64 * GUI.Scale;
        float scale = Math.Min(Math.Min(size / sprite.size.X, size / sprite.size.Y), 1.5f);
        sprite.Draw(spriteBatch, PlayerInput.MousePosition, item.GetInventoryIconColor(), scale: scale);
        GUI.DrawString(spriteBatch, PlayerInput.MousePosition + new Vector2(size * 0.5f, 0),
            L("cleartarget"), Color.LightYellow, Color.Black * 0.65f, 0, GUIStyle.SmallFont);
    }

    internal bool IsMouseOnTargetSlot => targetSlot!.Rect.Contains(PlayerInput.MousePosition);
    internal GUIComponent TargetSlot => targetSlot!;
}

[HarmonyPatch]
internal static class DeepAmmoLoaderTargetInputPatch
{
    [HarmonyPatch(typeof(Inventory), nameof(Inventory.UpdateDragging))]
    [HarmonyPrefix]
    private static bool BeforeDragging() => DeepAmmoLoader.ActiveTargetLoader?.HandleTargetDrop() != true && !ManualMagazineLoading.HandleDrop();

    [HarmonyPatch(typeof(Inventory), nameof(Inventory.DrawFront))]
    [HarmonyPrefix]
    private static void BeforeDraw(out bool __state)
    {
        __state = GUI.MouseOn == null && Inventory.DraggingItems.Any() &&
            DeepAmmoLoader.ActiveTargetLoader is { IsMouseOnTargetSlot: true };
        if (__state) { GUI.ForceMouseOn(DeepAmmoLoader.ActiveTargetLoader!.TargetSlot); }
    }

    [HarmonyPatch(typeof(Inventory), nameof(Inventory.DrawFront))]
    [HarmonyFinalizer]
    private static void AfterDraw(bool __state)
    {
        if (__state) { GUI.ForceMouseOn(null); }
    }

    [HarmonyPatch(typeof(Inventory), nameof(Inventory.DrawFront))]
    [HarmonyPostfix]
    private static void DrawSelection(SpriteBatch spriteBatch) => DeepAmmoLoader.ActiveTargetLoader?.DrawTargetDrag(spriteBatch);
}
