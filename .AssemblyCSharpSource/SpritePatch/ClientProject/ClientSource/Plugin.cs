using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework;
using System.Collections.Generic;

namespace SpritePatch
{
    [HarmonyPatch]
    public static class UniversalSpritePatch
    {
        // 存储所有物品的独立Sprite实例
        private static readonly Dictionary<Item, Sprite> itemSprites = new Dictionary<Item, Sprite>();

        // 存储原始Sprite引用（用于恢复）
        private static readonly Dictionary<Item, Sprite> originalSprites = new Dictionary<Item, Sprite>();

        /// <summary>
        /// 物品更新时确保初始化独立Sprite
        /// </summary>
        [HarmonyPatch(typeof(Item), nameof(Item.Update))]
        [HarmonyPostfix]
        private static void EnsureSpriteInitialized(Item __instance)
        {
            if (__instance.Sprite == null || itemSprites.ContainsKey(__instance)) return;

            originalSprites[__instance] = __instance.Sprite;
            itemSprites[__instance] = CloneSprite(__instance.Sprite);
        }

        /// <summary>
        /// 拦截Sprite设置
        /// </summary>
        [HarmonyPatch(typeof(Sprite), nameof(Sprite.SourceRect), MethodType.Setter)]
        [HarmonyPrefix]
        private static bool BeforeSetSourceRect(Sprite __instance, Rectangle value)
        {
            // 查找关联物品
            foreach (var kvp in itemSprites)
            {
                if (kvp.Value == __instance)
                {
                    // 允许修改独立Sprite
                    return true;
                }
            }
            // 非受控Sprite放行修改
            return true;
        }

        /// <summary>
        /// 强制使用独立Sprite
        /// </summary>
        [HarmonyPatch(typeof(Item), nameof(Item.SetActiveSprite))]
        [HarmonyPrefix]
        private static bool OverrideActiveSprite(Item __instance)
        {
            if (itemSprites.TryGetValue(__instance, out var customSprite))
            {
                __instance.activeSprite = customSprite;
                return false; // 跳过原始方法
            }
            return true; // 继续执行原始方法
        }

        /// <summary>
        /// 返回独立Sprite实例
        /// </summary>
        [HarmonyPatch(typeof(Item), nameof(Item.Sprite), MethodType.Getter)]
        [HarmonyPostfix]
        private static void OverrideSpriteGetter(Item __instance, ref Sprite __result)
        {
            if (itemSprites.TryGetValue(__instance, out var customSprite))
            {
                __result = customSprite;
            }
        }

        /// <summary>
        /// 深度复制Sprite
        /// </summary>
        private static Sprite CloneSprite(Sprite original)
        {
            if (original == null) return null;
            Sprite clone = new Sprite(original);
            clone.Origin = original.Origin; 
            clone.Depth = original.Depth;   
            clone.size = original.size; 
            clone.effects = original.effects; 
            clone.identifier = original.identifier; 
            clone.cannotBeLoaded = original.cannotBeLoaded;
            clone.loadingAsync = false; 
            clone.LazyLoad = original.LazyLoad;
            clone.RelativeSize = original.RelativeSize;
            clone.Compress = original.Compress; 
            clone.SourceElement = original.SourceElement; 
            clone.EntityIdentifier = original.EntityIdentifier; 
            clone.Name = original.Name;
            return clone;
        }
    }
}