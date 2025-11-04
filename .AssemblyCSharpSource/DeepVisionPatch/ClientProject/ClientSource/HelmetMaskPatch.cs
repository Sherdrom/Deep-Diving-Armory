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

    /// <summary>
    /// Sets up Lua hooks for mask control
    /// Called after character control patch
    /// </summary>
    public static void Postfix()
    {
        // ALTYN mask - close
        GameMain.LuaCs.Hook.Add("ALTYN_Origin", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            if (!MaskStatus.TryGetValue(item.ID, out bool currentStatus) || currentStatus)
            {
                MaskStatus[item.ID] = false; // Mask closed
            }
            return null;
        });

        // ALTYN mask - open
        GameMain.LuaCs.Hook.Add("ALTYN_Open", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            if (!MaskStatus.TryGetValue(item.ID, out bool currentStatus) || !currentStatus)
            {
                MaskStatus[item.ID] = true; // Mask open
            }
            return null;
        });

        // MASKA mask - close
        GameMain.LuaCs.Hook.Add("MASKA_Origin", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            if (!MaskStatus.TryGetValue(item.ID, out bool currentStatus) || currentStatus)
            {
                MaskStatus[item.ID] = false; // Mask closed
            }
            return null;
        });

        // MASKA mask - open
        GameMain.LuaCs.Hook.Add("MASKA_Open", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            if (!MaskStatus.TryGetValue(item.ID, out bool currentStatus) || !currentStatus)
            {
                MaskStatus[item.ID] = true; // Mask open
            }
            return null;
        });
    }
}