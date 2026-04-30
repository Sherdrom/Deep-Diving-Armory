using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

/// <summary>
/// Manages night vision device states through Lua hooks
/// Tracks which items have night vision enabled/disabled
/// </summary>

public class NightVisionPatch
{
    /// <summary>
    /// Tracks night vision status for items (item ID -> is enabled)
    /// </summary>
    public static Dictionary<ushort, bool> NightVisionStatus { get; } = new Dictionary<ushort, bool>();

    public NightVisionPatch(ILuaEventService luaEventService)
    {
        // 在构造函数中只注册一次 Hook
        RegisterHooks(luaEventService);
    }

    /// <summary>
    /// Sets up Lua hooks for night vision control
    /// Called after character control patch
    /// </summary>
    private void RegisterHooks(ILuaEventService luaEventService)
    {
        // Hook to turn off night vision
        luaEventService.Add("NightVision_Off", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleNightVision(item, false);
            }
            return null;
            // Item item = (Item)args[2];
            // if (item == null) return null;
            // Character character = Character.Controlled;
            // if (character == null) return null;
            // if(item.ParentInventory?.Owner != character) return null;

            // // Only update if the item exists and is currently enabled
            // if (!NightVisionStatus.TryGetValue(item.ID, out bool currentStatus) || currentStatus)
            // {
            //     NightVisionStatus[item.ID] = false;
            // }
            // return null;
        });

        // Hook to turn on night vision
        luaEventService.Add("NightVision_On", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleNightVision(item, true);
            }
            return null;
            // Item item = (Item)args[2];
            // if (item == null) return null;
            // Character character = Character.Controlled;
            // if (character == null) return null;
            // if(item.ParentInventory?.Owner != character) return null;

            // // Only update if the item exists and is currently disabled
            // if (!NightVisionStatus.TryGetValue(item.ID, out bool currentStatus) || !currentStatus)
            // {
            //     NightVisionStatus[item.ID] = true;
            // }
            // return null;
        });
    }

    private void HandleNightVision(Item item, bool enabled)
    {
        Character character = Character.Controlled;
        // 检查逻辑：物品是否属于当前玩家控制的角色
        if (character != null && item.ParentInventory?.Owner == character)
        {
            NightVisionStatus[item.ID] = enabled;
        }
    }
}