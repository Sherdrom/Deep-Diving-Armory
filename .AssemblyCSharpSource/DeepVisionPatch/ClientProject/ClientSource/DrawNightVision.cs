using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(GameScreen),nameof(GameScreen.DrawMap))]
public class DrawNightVision
{
    private static CreateNightVisionTexture _nvTexture = DeepVisionPatch.nvTexture_Green;   // 默认为绿色

    private static readonly Dictionary<string, CreateNightVisionTexture> nvColor = new Dictionary<string, CreateNightVisionTexture>
    {
        ["NVG_Green"] = DeepVisionPatch.nvTexture_Green,     // 绿色夜视仪
        ["NVG_Blue"]  = DeepVisionPatch.nvTexture_Blue       // 蓝色夜视仪
        
    };

    public static void Postfix(GameScreen __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, double deltaTime)
    {
        Character character = Character.Controlled;
        if (character == null) return;
        Item headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
        if (headItem == null) return;
        IEnumerable<Item> headItems = headItem.ContainedItems; // 获取头盔内的item

        bool hasNightVision = false;
        // 头盔Hook 战术设备(夜视仪)的开关判断
        foreach (KeyValuePair<ushort, bool> nightVisionStatus in NightVisionPatch.NightVisionStatus)
        {
            if (headItem != null && headItem.ID == nightVisionStatus.Key)
            {
                hasNightVision = true;
                if (nightVisionStatus.Value == false)
                {
                    return;
                }
            }
        }

        if (!hasNightVision) return; // 如果没有夜视仪，直接返回

        // 以下通过_nvTexture和item的Tag来设置夜视仪的颜色
        foreach (Item item in headItems)
        {
            if (item != null && item.HasTag("NightVisionGoggle")) // 获取夜视仪item
            {
                // 通过字典设置_nvTexture
                foreach (KeyValuePair<string, CreateNightVisionTexture> kvp in nvColor)
                {
                    if (item.HasTag(kvp.Key))
                    {
                        _nvTexture = kvp.Value;
                    }
                }
            }
        }

        DrawNightVisionTexture(spriteBatch, deltaTime, graphics, _nvTexture);
    }
    
    public static void DrawNightVisionTexture(SpriteBatch spriteBatch, double deltaTime, GraphicsDevice graphics, CreateNightVisionTexture nvTexture)
    {
        nvTexture.Update((float)deltaTime);
        Texture2D texture = nvTexture.GetTexture();
        spriteBatch.Begin(SpriteSortMode.Deferred, null, GUI.SamplerState, null, GameMain.ScissorTestEnable);
        // 计算屏幕中心并以纹理中心为原点绘制
        var viewport = graphics.Viewport;
        var center = new Vector2(viewport.Width * 0.5f, viewport.Height * 0.5f);
        if (texture != null)
        {
            var origin = new Vector2(texture.Width * 0.5f, texture.Height * 0.5f);
            spriteBatch.Draw(texture, center, null, Color.White, 0f, origin, new Vector2(viewport.Width / texture.Width * 1.3f, viewport.Height / texture.Height * 1.1f), SpriteEffects.None, 0f);
        }
        spriteBatch.End();
    }
}
