using Barotrauma;
using HarmonyLib;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(Character),nameof(Character.Control))]
public class NightVisionPatch
{
    public static Dictionary<ushort, bool> NightVisionStatus = new Dictionary<ushort, bool> { };
    //两个LuaHook，通过xml调用
    public static void Postfix()
    {
        GameMain.LuaCs.Hook.Add("NightVision_Off", (object[] args) =>
        {
            Item item =(Item)args[2];
            if(item == null) return null;
            if(!(!NightVisionStatus.TryGetValue(item.ID, out _) || (NightVisionStatus.TryGetValue(item.ID, out bool status) && status))) return null;
            NightVisionStatus[item.ID] = false;    //夜视仪关闭为false
            return null;
        });
        GameMain.LuaCs.Hook.Add("NightVision_On", (object[] args) =>
        {
            Item item =(Item)args[2];
            if(item == null) return null;
            if(!(!NightVisionStatus.TryGetValue(item.ID, out _) ||(NightVisionStatus.TryGetValue(item.ID, out bool status)&&!status))) return null;
            NightVisionStatus[item.ID] = true;     //夜视仪打开为true
            return null;
        });
    }
}