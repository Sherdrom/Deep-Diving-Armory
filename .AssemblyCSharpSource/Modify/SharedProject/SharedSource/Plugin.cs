using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using HarmonyLib;
using Microsoft.Xna.Framework;

namespace Modify
{
    public class ModifyPlugin : IAssemblyPlugin
    {
        public readonly string Name = "Modify System";
        private Harmony? harmonyInstance;

        public void Initialize()
        {
            LuaCsLogger.Log("Modify System loading...");
            harmonyInstance = new Harmony("Modify.System.Plugin");
        }

        public void OnLoadCompleted()
        {
            harmonyInstance?.PatchAll();
            LuaCsLogger.Log("Modify System loaded successfully!");
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
            harmonyInstance?.UnpatchSelf();
            harmonyInstance = null;
        }
    }

    #region Item 扩展方法

    public static class ItemModifyExtensions
    {
        public static int GetModifyLevel(this Item item)
        {
            var modifyComp = item.GetComponent<Barotrauma.Items.Components.Modify>();
            return modifyComp?.ModifyLevel ?? 0;
        }

        public static void SetModifyLevel(this Item item, int value)
        {
            var modifyComp = item.GetComponent<Barotrauma.Items.Components.Modify>();
            if (modifyComp != null)
            {
                modifyComp.ModifyLevel = value;
            }
        }

        public static float GetModifyModifier(this Item item, int statTypeIndex)
        {
            var modifyComp = item.GetComponent<Barotrauma.Items.Components.Modify>();
            if (modifyComp == null) return 0.0f;
            var statType = (Barotrauma.Items.Components.Modify.StatType)statTypeIndex;
            return modifyComp.GetValue(statType);
        }

        public static bool HasModify(this Item item)
        {
            return item.GetComponent<Barotrauma.Items.Components.Modify>() != null;
        }
    }

    #endregion

    #region 加成生效 - 补丁 Item.GetQualityModifier 让 Modify 加成也生效

    [HarmonyPatch(typeof(Item), "GetQualityModifier")]
    public static class Item_GetQualityModifier_Patch
    {
        [HarmonyPostfix]
        public static void Postfix(Item __instance, Quality.StatType statType, ref float __result)
        {
            var modifyComp = __instance.GetComponent<Barotrauma.Items.Components.Modify>();
            if (modifyComp != null && modifyComp.ModifyLevel != 0)
            {
                var modifyStatType = (Barotrauma.Items.Components.Modify.StatType)(int)statType;
                __result += modifyComp.GetValue(modifyStatType);
            }
        }
    }

    #endregion

    #region 散布减少 - 补丁 RangedWeapon.GetSpread 让 Modify.RangedSpreadReduction 降低武器散布

    [HarmonyPatch(typeof(RangedWeapon), "GetSpread")]
    public static class RangedWeapon_GetSpread_Patch
    {
        [HarmonyPostfix]
        public static void Postfix(RangedWeapon __instance, ref float __result)
        {
            var modifyComp = __instance.Item.GetComponent<Barotrauma.Items.Components.Modify>();
            if (modifyComp != null && modifyComp.ModifyLevel != 0)
            {
                float modifySpreadReduction = modifyComp.GetValue(Barotrauma.Items.Components.Modify.StatType.RangedSpreadReduction);
                if (modifySpreadReduction > 0f)
                {
                    __result /= (1f + modifySpreadReduction);
                }
                else if (modifySpreadReduction < 0f)
                {
                    __result /= (1f + modifySpreadReduction);
                }
            }
        }
    }

    #endregion
}
