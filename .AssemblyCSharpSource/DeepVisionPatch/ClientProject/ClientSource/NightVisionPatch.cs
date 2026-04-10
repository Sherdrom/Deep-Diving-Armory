using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

/// <summary>
/// Manages night vision device states through Lua hooks
/// Tracks which items have night vision enabled/disabled
/// </summary>
[HarmonyPatch(typeof(Character), nameof(Character.Control))]
public class NightVisionPatch
{
    /// <summary>
    /// Tracks night vision status for items (item ID -> is enabled)
    /// </summary>
    public static Dictionary<ushort, bool> NightVisionStatus { get; } = new Dictionary<ushort, bool>();

    /// <summary>
    /// Sets up Lua hooks for night vision control
    /// Called after character control patch
    /// </summary>
    public static void Postfix()
    {
        // Hook to turn off night vision
        LuaCsSetup.Instance.Hook.Add("NightVision_Off", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            // Only update if the item exists and is currently enabled
            if (!NightVisionStatus.TryGetValue(item.ID, out bool currentStatus) || currentStatus)
            {
                NightVisionStatus[item.ID] = false;
            }
            return null;
        });

        // Hook to turn on night vision
        LuaCsSetup.Instance.Hook.Add("NightVision_On", (object[] args) =>
        {
            Item item = (Item)args[2];
            if (item == null) return null;

            // Only update if the item exists and is currently disabled
            if (!NightVisionStatus.TryGetValue(item.ID, out bool currentStatus) || !currentStatus)
            {
                NightVisionStatus[item.ID] = true;
            }
            return null;
        });
    }
}