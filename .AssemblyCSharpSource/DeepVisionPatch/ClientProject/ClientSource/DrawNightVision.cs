using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(GameScreen),nameof(GameScreen.DrawMap))]
public class DrawNightVision
{
    public static void Postfix(GameScreen __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, double deltaTime)
    {
        Character character = Character.Controlled;
        if (character == null) return;
        Item headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
        if (headItem == null) return;
        // IEnumerable<Item> headItems = headItem.ContainedItems; // 获取头盔内的item

        // if (headItem == null) { return; }
        // 头盔Hook 战术设备(夜视仪)的开关判断
        NightVisionPatch.NightVisionStatus.TryGetValue(headItem.ID, out bool NVStatus);
        if (!NVStatus) { return; }

        DrawNightVisionTexture(spriteBatch, deltaTime, graphics, DeepVisionPatch.CurrentNVTexture);
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
            // Draw lightweight scanline overlay without modifying the main texture
            nvTexture.DrawOverlay(spriteBatch, center, scaleVector);
        }
        spriteBatch.End();
    }
}
