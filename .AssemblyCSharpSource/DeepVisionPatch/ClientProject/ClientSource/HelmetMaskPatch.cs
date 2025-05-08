using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(Character),nameof(Character.Control))]
public class HelmetMaskPatch
{
    public static Dictionary<ushort,bool> MaskStatus = new Dictionary<ushort, bool>{};
    public static void Postfix()
    {
        GameMain.LuaCs.Hook.Add("ALTYN_Origin", (object[] args) =>
        {
            Item item =(Item)args[2];
            if(item == null) return null;
            if(!(!MaskStatus.TryGetValue(item.ID, out _) || (MaskStatus.TryGetValue(item.ID, out bool status) && status))) return null;
            MaskStatus[item.ID] = false;    //面罩关闭为false
            return null;
        });
        GameMain.LuaCs.Hook.Add("ALTYN_Open", (object[] args) =>
        {
            Item item =(Item)args[2];
            if(item == null) return null;
            if(!(!MaskStatus.TryGetValue(item.ID, out _) ||(MaskStatus.TryGetValue(item.ID, out bool status)&&!status))) return null;
            MaskStatus[item.ID] = true;     //面罩打开为true
            return null;
        });
    }
}