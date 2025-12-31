using HarmonyLib;
using Barotrauma;
using Microsoft.Xna.Framework;
using System.Collections.Generic;
using System.Collections.Concurrent;

namespace SpritePatch
{
    [HarmonyPatch]
    public static class UniversalSpritePatch
    {
        // 存储所有物品的独立Sprite实例
        private static readonly ConcurrentDictionary<Item, Sprite> itemSprites = new ConcurrentDictionary<Item, Sprite>();

        /// <summary>
        /// 物品更新时确保初始化独立Sprite
        /// </summary>
        [HarmonyPatch(typeof(Item), nameof(Item.Update))]
        [HarmonyPostfix]
        private static void EnsureSpriteInitialized(Item __instance)
        {
            //只有深潜武装生效
            if(!(__instance!= null && __instance.HasTag("weapon")&&__instance.Prefab.ContentPackage?.Name == "Deep Diving Armory")) return;
            if (__instance.Sprite == null || itemSprites.ContainsKey(__instance)) return;
            itemSprites[__instance] = CloneSprite(__instance.Sprite);
        }

        // /// <summary>
        // /// 强制使用独立Sprite
        // /// </summary>
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