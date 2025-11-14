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
using System.Reflection;
using Color = Microsoft.Xna.Framework.Color;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using static Barotrauma.Inventory;

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
                    if (codes[i].opcode == OpCodes.Call &&
                        codes[i + 1].opcode == OpCodes.Ldarg_0 &&
                        codes[i + 2].opcode == OpCodes.Ldfld &&
                        codes[i + 2].operand.ToString().Contains("crosshairPointerSprite"))

                    {
                        foundInsertionPoint = true;
                        var injectCode = new List<CodeInstruction>
                        {
                            new CodeInstruction(OpCodes.Ldarg_0),      // this (RangedWeapon)
                            new CodeInstruction(OpCodes.Ldarg_1),      // spriteBatch
                            new CodeInstruction(OpCodes.Call, typeof(RemainedAmmo).GetMethod("DrawMyString"))
                        };
                        codes.InsertRange(i + 1, injectCode);
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
        public static int CurrentAmmoNumber(Item item, ItemContainer itemContainer)
        {
            int currentAmmoNumber = 0;
            int maxAmmoStack = itemContainer.MainContainerCapacity;
            for(int i = 0; i < maxAmmoStack; i++)
            {
                ItemSlot weaponSlot = item.OwnInventory.slots[i];
                if(weaponSlot != null && weaponSlot.items!=null)
                {
                    currentAmmoNumber = currentAmmoNumber + weaponSlot.items.Count;
                }
            }
            return currentAmmoNumber;
        }
        public static void DrawMyString(RangedWeapon rangedWeapon, SpriteBatch spriteBatch)
        {
            if(rangedWeapon.Item.Prefab.ContentPackage == null || !rangedWeapon.Item.Prefab.ContentPackage.Name.Contains("Deep Diving Armory") || rangedWeapon.Item.HasTag("noammocount")) {return;}
            int remainedAmmo = 0;
            var ItemContainer = rangedWeapon.Item.GetComponent<ItemContainer>();
            if (ItemContainer == null) { return; }
            float containedIndicatorState = rangedWeapon.Item.GetComponent<ItemContainer>().GetContainedIndicatorState();
            int targetSlot = Math.Max(ItemContainer.ContainedStateIndicatorSlot, 0);
            if (targetSlot >= ItemContainer.Inventory.Capacity){return;}
            // 获取RemainedAmmo
            IEnumerable<Item> itemsAt = ItemContainer.Inventory.GetItemsAt(targetSlot);
            // if (itemsAt == null) {goto drawRemained;}
            // if(itemsAt.FirstOrDefault() == null) {goto drawRemained;}
            if(itemsAt == null || itemsAt.FirstOrDefault() == null || itemsAt.FirstOrDefault().ownInventory == null) { remainedAmmo = CurrentAmmoNumber(rangedWeapon.Item,ItemContainer);}
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

            // 获取射击模式和弹药类型信息
            string modeText = "";
            string ammoTypeText = "";

            // 尝试获取 SwitchableRangedWeapon 组件
            // 使用 GetComponents 然后查找匹配的类型
            try
            {
                var components = rangedWeapon.Item.GetComponents<ItemComponent>();
                foreach (var comp in components)
                {
                    // 通过类型名称检查是否为 SwitchableRangedWeapon
                    if (comp.GetType().Name == "SwitchableRangedWeapon")
                    {
                        dynamic weapon = comp;

                        // 获取射击模式和弹药类型
                        try
                        {
                            // 使用 dynamic 动态访问私有字段
                            var firemodes = weapon.switchableFiremodes;
                            var projectiles = weapon.switchableProjectiles;

                            if (firemodes != null && firemodes.Count > 0)
                            {
                                modeText = firemodes[weapon.currentFireModeSelected].ToString();
                            }

                            if (projectiles != null && projectiles.Count > 0)
                            {
                                ammoTypeText = projectiles[weapon.currentProjectileSelected].ToString();
                            }
                        }
                        catch { }
                        break;
                    }
                }
            }
            catch
            {
                // 如果不是 SwitchableRangedWeapon 或出错则忽略
            }

            // 绘制相关图像
            // drawRemained:
            string ammoString = "00";
            if(remainedAmmo<10){ammoString = "0" + remainedAmmo;}
            else {ammoString = remainedAmmo.ToString();}
            var scale = rangedWeapon.currentCrossHairScale;
            Color indicatorColor = new Color(230,26,18,255);
            Color modeColor = new Color(255,255,255,200); // 白色半透明
            Color ammoTypeColor = new Color(100,200,255,200); // 浅蓝色半透明
            Vector2 basePos = rangedWeapon.crosshairPos;
            Vector2 modeTextPos = basePos;
            Vector2 ammoTypeTextPos = basePos;
            Vector2 ammoTextPos = basePos;

            // 如果是双持武器，且是左手武器，将文字放在左边
            Character character = (Character)rangedWeapon.Item.ParentInventory.Owner;
            if (character == null) { return; }
            CharacterInventory characterInventory = character.Inventory;
            var leftItem = characterInventory.GetItemInLimbSlot(InvSlotType.LeftHand);
            var rightItem =characterInventory.GetItemInLimbSlot(InvSlotType.RightHand);
            bool isLeftHandWeapon = (leftItem!=null && rightItem!=null && rangedWeapon.Item.ID == leftItem.ID && leftItem.ID != rightItem.ID);

            float leftOffset = isLeftHandWeapon ? -46f : 8f;
            float rightOffset = isLeftHandWeapon ? -46f : 60f;

            // 设置文字位置
            // 弹药数量 - 最下方
            ammoTextPos.X += leftOffset;
            ammoTextPos.Y += 110f * scale * scale;

            // 射击模式 - 中间
            modeTextPos.X += rightOffset;
            modeTextPos.Y += 80f * scale * scale;

            // 弹药类型 - 最上方
            ammoTypeTextPos.X += rightOffset;
            ammoTypeTextPos.Y += 50f * scale * scale;

            // 绘制文字
            if (!string.IsNullOrEmpty(ammoString))
            {
                GUIStyle.DigitalFont.DrawString(spriteBatch, ammoString, ammoTextPos, indicatorColor);
            }
            if (!string.IsNullOrEmpty(modeText))
            {
                GUIStyle.DigitalFont.DrawString(spriteBatch, modeText, modeTextPos, modeColor);
            }
            if (!string.IsNullOrEmpty(ammoTypeText))
            {
                GUIStyle.DigitalFont.DrawString(spriteBatch, ammoTypeText, ammoTypeTextPos, ammoTypeColor);
            }
        }
    }
}
