using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(GameScreen),nameof(GameScreen.DrawMap))]
public class DrawNightVision
{
    public static Texture2D texture = DeepVisionPatch.nvTexture.GetTexture();
    public static void Postfix(GameScreen __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, double deltaTime)
    {
        DeepVisionPatch.nvTexture.Update((float)deltaTime);
        spriteBatch.Begin(SpriteSortMode.Deferred, null, GUI.SamplerState, null, GameMain.ScissorTestEnable);
        // 计算屏幕中心并以纹理中心为原点绘制
        var viewport = graphics.Viewport;
        var center = new Vector2(viewport.Width * 0.5f, viewport.Height * 0.5f);
        if (texture != null)
        {
            var origin = new Vector2(texture.Width * 0.5f, texture.Height * 0.5f);
            spriteBatch.Draw(texture, center, null, Color.White, 0f, origin, new Vector2(viewport.Width/texture.Width*1.3f,viewport.Height/texture.Height*1.1f), SpriteEffects.None, 0f);
        }
        spriteBatch.End();
    }
}
