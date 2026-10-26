using Barotrauma.Items.Components;
using Microsoft.Xna.Framework.Graphics;
using static Barotrauma.Inventory;

namespace RemainedAmmo
{
    public partial class RemainedAmmo : IAssemblyPlugin
    {
        // Client-specific code
         //patch DrawHUD for RangedWeapon
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

        private static ItemPrefab[]? ddaItemPrefabs;

        private static bool IsDdaPrefab(ItemPrefab prefab)
            => prefab.ContentPackage?.Name == RemainedAmmo.Package.Name;

        private static bool IsDdaItem(Item item) => IsDdaPrefab(item.Prefab);

        private static bool CanContainDdaItem(int targetSlot, ItemContainer itemContainer)
        {
            ddaItemPrefabs ??= ItemPrefab.Prefabs.Where(IsDdaPrefab).ToArray();
            return ddaItemPrefabs.Any(prefab =>
                itemContainer.Inventory.CanBePutInSlot(prefab, targetSlot, condition: null, quality: null));
        }

        private static bool HasDdaAmmoOrCompatibleSlot(int targetSlot, ItemContainer itemContainer)
        {
            if (targetSlot >= itemContainer.Inventory.Capacity) { return false; }

            Item[] loadedItems = itemContainer.Inventory.GetItemsAt(targetSlot).ToArray();
            if (loadedItems.Any(IsDdaItem) ||
                loadedItems.Any(item => item.OwnInventory?.slots.Any(slot => slot.items.Any(IsDdaItem)) == true))
            {
                return true;
            }

            if (loadedItems.Length == 0)
            {
                return CanContainDdaItem(targetSlot, itemContainer);
            }

            foreach (Item loadedItem in loadedItems)
            {
                var nestedContainer = loadedItem.GetComponent<ItemContainer>();
                if (nestedContainer == null) { continue; }

                for (int i = 0; i < nestedContainer.Inventory.Capacity; i++)
                {
                    if (!nestedContainer.Inventory.GetItemsAt(i).Any() && CanContainDdaItem(i, nestedContainer))
                    {
                        return true;
                    }
                }
            }

            return false;
        }

        public static void DrawMyString(object rangedWeaponObj, SpriteBatch spriteBatch)
        {
            // 支持RangedWeapon和SwitchableRangedWeapon
            if (rangedWeaponObj is not RangedWeapon rangedWeapon) { return; }

            if(rangedWeapon.Item.HasTag("noammocount")) {return;}
            Item ammoHostItem = rangedWeapon.Item;
            var itemContainer = rangedWeapon.Item.GetComponent<ItemContainer>();
            if (itemContainer == null) { return; }
            float containedIndicatorState = itemContainer.GetContainedIndicatorState();
            bool selectedAmmoMissing = false;

            // 获取当前选择的弹匣（支持SwitchableRangedWeapon的双弹匣系统）
            int targetSlot = Math.Max(itemContainer.ContainedStateIndicatorSlot, 0);

            // 检查是否为SwitchableRangedWeapon（使用字符串模式匹配避免访问级别问题）
            if (rangedWeapon.GetType().Name == "SwitchableRangedWeapon")
            {
                // 使用反射获取currentProjectileSelected属性，避免dynamic的性能开销
                var currentSelectedProperty = rangedWeapon.GetType().GetProperty("currentProjectileSelected");
                if (currentSelectedProperty != null)
                {
                    targetSlot = Math.Max(Convert.ToInt32(currentSelectedProperty.GetValue(rangedWeapon)), 0);

                    // 处理下挂组件的特殊情况
                    if (targetSlot == 1)
                    {
                        IEnumerable<Item> itemsAt = itemContainer.Inventory.GetItemsAt(targetSlot);
                        Item? hangWeaponItem = itemsAt.FirstOrDefault();
                        var hangWeaponContainer = hangWeaponItem?.GetComponent<ItemContainer>();
                        if (hangWeaponItem == null || hangWeaponContainer == null)
                        {
                            selectedAmmoMissing = true;
                        }
                        else
                        {
                            ammoHostItem = hangWeaponItem;
                            itemContainer = hangWeaponContainer;
                            containedIndicatorState = hangWeaponContainer.GetContainedIndicatorState();
                            targetSlot = 0;
                        }
                    }
                }
            }

            if (!IsDdaItem(rangedWeapon.Item) &&
                !IsDdaItem(ammoHostItem) &&
                !HasDdaAmmoOrCompatibleSlot(targetSlot, itemContainer)) { return; }
            int remainedAmmo = selectedAmmoMissing
                ? 0
                : GetRemainedAmmo(targetSlot, ammoHostItem, itemContainer, containedIndicatorState);

            // 绘制相关图像
            // drawRemained:
            string ammoString = "00";
            if(remainedAmmo<10){ammoString = "0" + remainedAmmo;}
            else {ammoString = remainedAmmo.ToString();}
            var scale = rangedWeapon.currentCrossHairScale;
            Color indicatorColor = new Color(207,207,207,255);
            Vector2 TextPos = rangedWeapon.crosshairPos;
            // 如果是双持武器，且是左手武器，将数字放在左边
            Character character = (Character)rangedWeapon.Item.ParentInventory.Owner;
            CharacterInventory characterInventory = character.Inventory;
            var leftItem = characterInventory.GetItemInLimbSlot(InvSlotType.LeftHand);
            var rightItem =characterInventory.GetItemInLimbSlot(InvSlotType.RightHand);
            if(leftItem!=null && rightItem!=null && rangedWeapon.Item.ID == leftItem.ID && leftItem.ID != rightItem.ID)
            {
                TextPos.X -= 46f;
            }
            else
            {
                TextPos.X += 8f;
            }
            TextPos.Y += 110f * scale * scale;

            GUIStyle.DigitalFont.DrawString(spriteBatch,ammoString,TextPos,indicatorColor);
        }

        public static int GetRemainedAmmo(int targetSlot, Item item, ItemContainer itemContainer, float containedIndicatorState)
        {
            int remainedAmmo = 0;
            // 获取当前选择的弹匣
            if (targetSlot >= itemContainer.Inventory.Capacity){return 0;}
            // 获取RemainedAmmo
            IEnumerable<Item> itemsAt = itemContainer.Inventory.GetItemsAt(targetSlot);
            // if (itemsAt == null) {goto drawRemained;}
            // if(itemsAt.FirstOrDefault() == null) {goto drawRemained;}
            if(itemsAt == null || itemsAt.FirstOrDefault() == null || itemsAt.FirstOrDefault().ownInventory == null) { remainedAmmo = CurrentAmmoNumber(item,itemContainer);}
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
                if(conditionValue == null){return 0;}
                remainedAmmo = (int)Math.Floor(containedIndicatorState*100 / Math.Abs(conditionValue.GetValueOrDefault()));              
            }
            return remainedAmmo;
        }
    }
}
