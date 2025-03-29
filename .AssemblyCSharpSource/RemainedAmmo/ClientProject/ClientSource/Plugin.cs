using System.Collections.Immutable;
using Barotrauma;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Linq;
using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using HarmonyLib;
using System.Reflection.Emit;
using Color = Microsoft.Xna.Framework.Color;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace RemainedAmmo
{
    public partial class RemainedAmmo : IAssemblyPlugin
    {
        // Client-specific code
         //patch DrawHUD
        [HarmonyPatch(typeof(RangedWeapon), nameof(RangedWeapon.DrawHUD))]
        static class RangedWeapon_DrawHUD_Patch
        {
            static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
            {
                var codes = new List<CodeInstruction>(instructions);
                bool foundInsertionPoint = false;
                for (int i = 0; i < codes.Count; i++)
                {
                    if (codes[i].opcode == OpCodes.Ldarg_0 &&
                        codes[i + 1].opcode == OpCodes.Ldfld &&
                        codes[i + 1].operand.ToString().Contains("crossHairPosDirtyTimer"))
                    {
                        foundInsertionPoint = true;
                        var injectCode = new List<CodeInstruction>
                        {
                            new CodeInstruction(OpCodes.Ldarg_0),      // this (RangedWeapon)
                            new CodeInstruction(OpCodes.Ldarg_1),      // spriteBatch
                            new CodeInstruction(OpCodes.Call, typeof(RemainedAmmo).GetMethod("DrawMyString"))
                        };
                        codes.InsertRange(i + 2, injectCode);
                        break;
                    }
                }
                if (!foundInsertionPoint)
                    throw new Exception("Failed to find insertion point in IL code! This may beacuse of other mod(s).");
                return codes;
            }
        }
        public static float? GetConditionValue(StatusEffect statusEffect)
        {
            foreach (var (propertyName, value) in statusEffect.PropertyEffects)
            {
                if (statusEffect.ChangesItemCondition(propertyName, value, out float conditionValue))
                {
                    return conditionValue;
                }
            }
            return null; // 如果没有找到 Condition，返回 null
        }
        public static void DrawMyString(RangedWeapon rangedWeapon, SpriteBatch spriteBatch)
        {
            if(rangedWeapon.Item.Prefab.ContentPackage == null || rangedWeapon.Item.Prefab.ContentPackage.Name != "Deep Diving Armory"){return;}
            int remainedAmmo = 0;
            var ItemContainer = rangedWeapon.Item.GetComponent<ItemContainer>();
            if (ItemContainer == null) { return; }
            float containedIndicatorState = rangedWeapon.Item.GetComponent<ItemContainer>().GetContainedIndicatorState();
            int targetSlot = Math.Max(ItemContainer.ContainedStateIndicatorSlot, 0);
            if (targetSlot >= ItemContainer.Inventory.Capacity){return;}
            // 获取RemainedAmmo
            IEnumerable<Item> itemsAt = ItemContainer.Inventory.GetItemsAt(targetSlot);
            if (itemsAt == null) {goto drawRemained;}
            if(itemsAt.FirstOrDefault() == null) {goto drawRemained;}
            if(itemsAt.FirstOrDefault().ownInventory == null) { remainedAmmo = itemsAt.Count();}
            else
            {
                float? conditionValue = 1.0f;
                if(itemsAt.FirstOrDefault().statusEffectLists.TryGetValue(ActionType.OnUse,out List<StatusEffect> onUseEffects))
                {
                    // 遍历 List<StatusEffect>，查找 Condition 属性
                    foreach (var statusEffect in onUseEffects)
                    {
                        if(GetConditionValue(statusEffect)!=null)
                        {
                            conditionValue = GetConditionValue(statusEffect);
                        }
                    }
                }
                if(conditionValue == null){return;}
                remainedAmmo = (int)Math.Floor(containedIndicatorState*100 / Math.Abs(conditionValue.GetValueOrDefault()));              
            }
            // 绘制相关图像
            drawRemained:
            string ammoString = "00";
            if(remainedAmmo<10){ammoString = "0" + remainedAmmo;}
            else {ammoString = remainedAmmo.ToString();}
            var scale = rangedWeapon.currentCrossHairScale;
            Color indicatorColor = new Color(230,26,18,255);
            Vector2 TextPos = rangedWeapon.crosshairPos;
            TextPos.Y += 65f * scale;
            TextPos.X += 15f * scale;
            GUIStyle.LargeFont.DrawString(spriteBatch,ammoString,TextPos,indicatorColor);                        
        }
    }
}
