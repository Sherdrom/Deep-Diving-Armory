using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

/// <summary>
/// Manages helmet mask states through Lua hooks
/// Tracks which items have masks enabled/disabled
/// Supports multiple mask types (ALTYN, MASKA)
/// </summary>
[HarmonyPatch(typeof(Character), nameof(Character.Control))]
public class HelmetMaskPatch
{
    /// <summary>
    /// Tracks mask status for items (item ID -> is open)
    /// </summary>
    public static Dictionary<ushort, bool> MaskStatus { get; } = new Dictionary<ushort, bool>();

    public HelmetMaskPatch(ILuaEventService luaEventService)
    {
        // 在构造函数中只注册一次 Hook
        RegisterHooks(luaEventService);
    }

    /// <summary>
    /// Sets up Lua hooks for mask control
    /// Called after character control patch
    /// </summary>
    private void RegisterHooks(ILuaEventService luaEventService)
    {
        // ALTYN mask - close
        luaEventService.Add("ALTYN_Origin", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleHelmetMask(item, false);
            }
            return null;
        });

        // ALTYN mask - open
        luaEventService.Add("ALTYN_Open", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleHelmetMask(item, true);
            }
            return null;
        });

        // MASKA mask - close
        luaEventService.Add("MASKA_Origin", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleHelmetMask(item, false);
            }
            return null;
        });

        // MASKA mask - open
        luaEventService.Add("MASKA_Open", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleHelmetMask(item, true);
            }
            return null;
        });
    }

    private void HandleHelmetMask(Item item, bool enabled)
    {
        Character character = Character.Controlled;
        // 检查逻辑：物品是否属于当前玩家控制的角色
        if (character != null && item.ParentInventory?.Owner == character)
        {
            MaskStatus[item.ID] = enabled;
        }
    }
}