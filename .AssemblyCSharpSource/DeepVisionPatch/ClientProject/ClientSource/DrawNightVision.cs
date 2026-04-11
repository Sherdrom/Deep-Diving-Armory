using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(GameScreen),nameof(GameScreen.DrawMap))]
public class DrawNightVision
{
    private static CreateNightVisionTexture _nvTexture = DeepVisionPatch.GreenNightVisionTexture;   // 默认为绿色

    private static readonly Dictionary<string, CreateNightVisionTexture> nvColor = new Dictionary<string, CreateNightVisionTexture>
    {
        ["NVG_Green"] = DeepVisionPatch.GreenNightVisionTexture,     // 绿色夜视仪
        ["NVG_Blue"]  = DeepVisionPatch.BlueNightVisionTexture       // 蓝色夜视仪

    };

    public static void Postfix(GameScreen __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, double deltaTime)
    {
        Character character = Character.Controlled;
        if (character == null) return;
        Item headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
        if (headItem == null) return;
        IEnumerable<Item> headItems = headItem.ContainedItems; // 获取头盔内的item

        if (headItem == null) { return; }

        // 头盔Hook 战术设备(夜视仪)的开关判断
        NightVisionPatch.NightVisionStatus.TryGetValue(headItem.ID, out bool NVStatus);
        if (!NVStatus) { return; }

        // 以下通过_nvTexture和item的Tag来设置夜视仪的颜色
        foreach (Item item in headItems)
        {
            if (item?.HasTag("NightVisionGoggle") != null) // 获取夜视仪item
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

            // X轴和Y轴分别缩放以填充整个屏幕
            var scaleVector = new Vector2(viewport.Width / texture.Width * 1.3f, viewport.Height / texture.Height * 1.3f);
            spriteBatch.Draw(texture, center, null, Color.White, 0f, origin, scaleVector, SpriteEffects.None, 0f);
        }
        spriteBatch.End();
    }
}
