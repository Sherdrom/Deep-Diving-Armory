using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(Character),nameof(Character.Control))]
public class HelmetMaskPatch
{
    public static Dictionary<ushort,bool> MaskStatus = new Dictionary<ushort, bool>{};
    public static void Postfix()
    {
        GameMain.LuaCs.Hook.Add("ALTYN_Origin", (object[] args) =>
        {
            Item item =(Item)args?[2];
            if(item == null) return null;
            MaskStatus[item.ID] = false;    //面罩关闭为false
            Wearable itemComponent = item.GetComponent<Wearable>();
            if (itemComponent.wearableSprites[0].Sprite == null ) return null;
            itemComponent.wearableSprites[0].Sprite.SourceRect = new Rectangle(9, 6, 128, 108);
            itemComponent.wearableSprites[0].Sprite.RelativeOrigin = new Vector2(0.52f,0.59f);
            return null;
        });
        GameMain.LuaCs.Hook.Add("ALTYN_Open", (object[] args) =>
        {
            Item item =(Item)args?[2];
            if(item == null) return null;
            MaskStatus[item.ID] = true;     //面罩打开为true
            Wearable itemComponent = item.GetComponent<Wearable>();
            if (itemComponent.wearableSprites[0].Sprite == null ) return null;
            itemComponent.wearableSprites[0].Sprite.SourceRect = new Rectangle(9,118,140,121);
            itemComponent.wearableSprites[0].Sprite.RelativeOrigin = new Vector2(0.52f,0.63f);
            return null;
        });
    }
}
