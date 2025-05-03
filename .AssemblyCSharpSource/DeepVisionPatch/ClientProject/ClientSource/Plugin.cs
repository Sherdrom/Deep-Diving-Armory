using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;
using Barotrauma.Items.Components;
using Barotrauma.Lights;

namespace DeepVisionPatch
{
    [HarmonyPatch(typeof(LightManager),nameof(LightManager.UpdateObstructVision))]
    public static class Patch_LightManager_UpdateObstructVision
    {
        public static float FieldOfView { get; set; } = MathF.PI * 8/9; // Default to 8/9 PI degrees
        public static readonly Dictionary<string,float> ObstructVision = new Dictionary<string, float>
        {
            ["ObstructVision_30"]=MathF.PI/6,
            ["ObstructVision_45"]=MathF.PI/4
        };
        public static bool Prefix(LightManager __instance, GraphicsDevice graphics, SpriteBatch spriteBatch, Camera cam, ref Vector2 lookAtPosition)
        {
            Character character = Character.Controlled;
            if (character == null) return true;
            // 检查玩家是否在使用枪械物品并按住右键
            // if (Character.Controlled.SelectedItem?.GetComponent<Holdable>() == null) return;
            Item rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand);
            Item leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand);
            Item headItem = character.Inventory.GetItemInLimbSlot(InvSlotType.Head);
            if (rightHand == null && leftHand == null && headItem == null){ return true; }
            if (!((rightHand != null && rightHand.HasTag("weapon")) || (leftHand != null && leftHand.HasTag("weapon")) || headItem != null && headItem.HasTag("ObstructVision"))){return true;}
            if(!(rightHand?.Prefab.ContentPackage?.Name == "Deep Diving Armory" || leftHand?.Prefab.ContentPackage?.Name == "Deep Diving Armory")){return true;}
            if (character == null || (!character.IsKeyDown(InputType.Aim)&&(headItem == null || !headItem.HasTag("ObstructVision")))|| !character.CanAim) { return true;}

            // Custom logic for reduced vision cone
            if ((!__instance.LosEnabled || __instance.LosMode == LosMode.None) && __instance.ObstructVisionAmount <= 0.0f) { return false; }
            if (__instance.ObstructVisionAmount > 0.0f) { return true; }
            if (LightManager.ViewTarget == null) { return false; }
            float leftHandSpread = 0;
            float rightHandSpread = 0;
            if (rightHand != null) 
                rightHandSpread = (float?)Traverse.Create(rightHand?
                                                     .GetComponent<RangedWeapon>())?
                                                     .Method("GetSpread", character)?
                                                     .GetValue() ?? 0f;
            if (leftHand != null) 
                leftHandSpread = (float?)Traverse.Create(leftHand?
                                                        .GetComponent<RangedWeapon>())?
                                                        .Method("GetSpread",character)?
                                                        .GetValue() ?? 0f;
            if(headItem != null && headItem.HasTag("ObstructVision"))
            {
                foreach(KeyValuePair<string,float> kvp in ObstructVision)
                {
                    if(headItem.HasTag(kvp.Key)) FieldOfView = kvp.Value;
                }
            }
            else 
            {   
                if(!(rightHandSpread == 0 && leftHandSpread == 0))
                    FieldOfView = MathHelper.Clamp(MathF.Max(leftHandSpread,rightHandSpread)*50*MathF.PI/9,MathF.PI/6, MathF.PI * 8/9);
            }

            graphics.SetRenderTarget(__instance.LosTexture);

                graphics.Clear(Color.Black);
                Vector2 diff = lookAtPosition - LightManager.ViewTarget.WorldPosition;
                diff.Y = -diff.Y;
                if (diff.LengthSquared() > 20.0f * 20.0f) { __instance.losOffset = diff; }
                float rotation = MathUtils.VectorToAngle(__instance.losOffset);

                //the visible area stretches to the maximum when the cursor is this far from the character
                const float MaxOffset = 256.0f;
                // Texture2D texture = new CreateViewTexture().CreateSectorTexture(graphics,256,FieldOfView,Color.Black);
                DeepVisionPatch.viewTexture.UpdateSectorTexture(FieldOfView, new Color(255,255,255,30));
                Texture2D texture = DeepVisionPatch.viewTexture.GetTexture();
                //the magic numbers here are just based on experimentation
                float MinHorizontalScale = MathHelper.Lerp(5f, 1.5f, 0);
                float MaxHorizontalScale = MinHorizontalScale * 5f;
                float VerticalScale = MathHelper.Lerp(4.0f, 1.25f, 0);

                //Starting point and scale-based modifier that moves the point of origin closer to the edge of the texture if the player moves their mouse further away, or vice versa.
                float relativeOriginStartPosition = 0.1f; //Increasing this value moves the origin further behind the character
                float originStartPosition = texture.Width * relativeOriginStartPosition * MinHorizontalScale;
                // float relativeOriginLookAtPosModifier = -0.055f; //Increase this value increases how much the vision changes by moving the mouse
                // float originLookAtPosModifier = texture.Width * relativeOriginLookAtPosModifier;
                
                // 获取玩家头部位置
                var headLimb = Character.Controlled.AnimController.GetLimb(LimbType.Head);
                if (headLimb == null) return false;
                Vector2 headPosition = headLimb.WorldPosition;

                Vector2 scale = new Vector2(
                    MathHelper.Clamp(__instance.losOffset.Length() / MaxOffset, MinHorizontalScale, MaxHorizontalScale), VerticalScale);

                spriteBatch.Begin(SpriteSortMode.Deferred, transformMatrix: cam.Transform * Matrix.CreateScale(new Vector3(GameSettings.CurrentConfig.Graphics.LightMapScale, GameSettings.CurrentConfig.Graphics.LightMapScale, 1.0f)));
                spriteBatch.Draw(texture, new Vector2(headPosition.X, -headPosition.Y), null, Color.White, rotation,
                    new Vector2(originStartPosition, texture.Height / 2), scale, SpriteEffects.None, 0.0f);
                spriteBatch.End();
                        
            //--------------------------------------
            if (__instance.LosEnabled && __instance.LosMode != LosMode.None && LightManager.ViewTarget != null)
            {
                Vector2 pos = LightManager.ViewTarget.DrawPosition;
                bool centeredOnHead = false;
                if (LightManager.ViewTarget is Character targetCharacter &&
                    targetCharacter.AnimController?.GetLimb(LimbType.Head) is Limb head &&
                    !head.IsSevered && !head.Removed)
                {
                    pos = head.body.DrawPosition;
                    centeredOnHead = true;
                }

                Rectangle camView = new Rectangle(cam.WorldView.X, cam.WorldView.Y - cam.WorldView.Height, cam.WorldView.Width, cam.WorldView.Height);
                Matrix shadowTransform = cam.ShaderTransform
                    * Matrix.CreateOrthographic(GameMain.GraphicsWidth, GameMain.GraphicsHeight, -1, 1) * 0.5f;

                var convexHulls = ConvexHull.GetHullsInRange(LightManager.ViewTarget.Position, cam.WorldView.Width * 0.75f, LightManager.ViewTarget.Submarine);

                //make sure the head isn't peeking through any LOS segments, and if it is,
                //center the LOS on the character's collider instead
                if (centeredOnHead)
                {
                    foreach (var ch in convexHulls)
                    {
                        if (!ch.Enabled) { continue; }
                        Vector2 currentViewPos = pos;
                        Vector2 defaultViewPos = LightManager.ViewTarget.DrawPosition;
                        if (ch.ParentEntity?.Submarine != null)
                        {
                            defaultViewPos -= ch.ParentEntity.Submarine.DrawPosition;
                            currentViewPos -= ch.ParentEntity.Submarine.DrawPosition;
                        }
                        //check if a line from the character's collider to the head intersects with the los segment (= head poking through it)
                        if (ch.LosIntersects(defaultViewPos, currentViewPos))
                        {
                            pos = LightManager.ViewTarget.DrawPosition;
                        }
                    }
                }

                if (convexHulls != null)
                {
                    LightManager.ShadowVertices.Clear();
                    LightManager.PenumbraVertices.Clear();
                    foreach (ConvexHull convexHull in convexHulls)
                    {
                        if (!convexHull.Intersects(camView)) { continue; }

                        Vector2 relativeViewPos = pos;
                        if (convexHull.ParentEntity?.Submarine != null) 
                        { 
                            relativeViewPos -= convexHull.ParentEntity.Submarine.DrawPosition;
                        }

                        convexHull.CalculateLosVertices(relativeViewPos);

                        for (int i = 0; i < convexHull.ShadowVertexCount; i++)
                        {
                            LightManager.ShadowVertices.Add(convexHull.ShadowVertices[i]);
                        }

                        for (int i = 0; i < convexHull.PenumbraVertexCount; i++)
                        {
                            LightManager.PenumbraVertices.Add(convexHull.PenumbraVertices[i]);
                        }
                    }

                    if (LightManager.ShadowVertices.Count > 0)
                    {
                        ConvexHull.shadowEffect.World = shadowTransform;
                        ConvexHull.shadowEffect.CurrentTechnique.Passes[0].Apply();
                        graphics.DrawUserPrimitives(PrimitiveType.TriangleList, LightManager.ShadowVertices.ToArray(), 0, LightManager.ShadowVertices.Count / 3, VertexPositionColor.VertexDeclaration);

                        if (LightManager.PenumbraVertices.Count > 0)
                        {
                            ConvexHull.penumbraEffect.World = shadowTransform;
                            ConvexHull.penumbraEffect.CurrentTechnique.Passes[0].Apply();
                            graphics.DrawUserPrimitives(PrimitiveType.TriangleList, LightManager.PenumbraVertices.ToArray(), 0, LightManager.PenumbraVertices.Count / 3, VertexPositionTexture.VertexDeclaration);
                        }
                    }
                }
            }
            // Skip the original method
            graphics.SetRenderTarget(null);
            return false;
        }
    }

    // public class CreateViewTexture
    // {
    //     public Texture2D CreateSectorTexture(GraphicsDevice graphicsDevice, int radius, float gapDegrees, Color color)
    //     {
    //         int textureSize = radius * 2;
    //         Texture2D texture = new Texture2D(graphicsDevice, textureSize, textureSize);
    //         Color[] pixels = new Color[textureSize * textureSize];

    //         Vector2 center = new Vector2(radius, radius);
    //         float gapStart = -MathHelper.ToRadians(gapDegrees/2); // 缺口起始角度（0度）
    //         float gapEnd = MathHelper.ToRadians(gapDegrees/2); // 缺口结束角度（30度→弧度）

    //         for (int y = 0; y < textureSize; y++)
    //         {
    //             for (int x = 0; x < textureSize; x++)
    //             {
    //                 Vector2 pixelPos = new Vector2(x, y);
    //                 float angle = MathF.Atan2(pixelPos.Y - center.Y, pixelPos.X - center.X);

    //                 // 确保角度在 [0, 2π] 范围内
    //                 if (angle < 0) angle += MathHelper.TwoPi;

    //                 // 判断是否在扇形内且不在缺口范围内
    //                 if (IsAngleBetween(angle, gapStart, gapEnd))
    //                 {
    //                     pixels[y * textureSize + x] = Color.White;
    //                 }
    //                 else
    //                 {
    //                     pixels[y * textureSize + x] = color;
    //                 }
    //             }
    //         }

    //         texture.SetData(pixels);
    //         return texture;
    //     }

    //     // 辅助方法：检查角度是否在 [start, end] 范围内（处理跨0点情况）
    //     private bool IsAngleBetween(float angle, float start, float end)
    //     {
    //         angle = (angle + MathHelper.TwoPi) % MathHelper.TwoPi;
    //         start = (start + MathHelper.TwoPi) % MathHelper.TwoPi;
    //         end = (end + MathHelper.TwoPi) % MathHelper.TwoPi;
            
    //         if (start <= end) 
    //             return angle >= start && angle <= end;
    //         else 
    //             return angle >= start || angle <= end;
    //     }
    // }
}
