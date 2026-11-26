using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

/// <summary>
/// Manages helmet mask states from status effects
/// Tracks which items have masks enabled/disabled
/// Supports multiple mask types (ALTYN, MASKA)
/// </summary>
public class HelmetMaskPatch
{
    /// <summary>
    /// Tracks mask status for items (item ID -> is open)
    /// </summary>
    public static Dictionary<ushort, bool> MaskStatus { get; } = new Dictionary<ushort, bool>();

    internal static void HandleHelmetMask(Item item, bool enabled)
    {
        Character character = Character.Controlled;
        // 检查逻辑：物品是否属于当前玩家控制的角色
        if (character != null && item.ParentInventory?.Owner == character)
        {
            MaskStatus[item.ID] = enabled;
        }
    }
}