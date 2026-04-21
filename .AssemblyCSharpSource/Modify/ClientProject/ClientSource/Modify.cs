using Microsoft.Xna.Framework;
using System;
using System.Collections.Generic;
using Barotrauma;

namespace Barotrauma.Items.Components
{
    partial class Modify
    {
        public static readonly Color ModifyColor = new Color(255, 215, 0);

        public override void AddTooltipInfo(ref LocalizedString name, ref LocalizedString description)
        {
            if (modifyLevel <= 0) return;

            string colorStr = XMLExtensions.ToStringHex(ModifyColor);

            // 使用 TextManager 获取翻译后的后缀名称
            LocalizedString suffixStr = TextManager.Get("modify.extrememodification").Fallback("Extreme Modification");
            name += $" ‖color:{colorStr}‖{suffixStr.Value}‖color:end‖";

            foreach (var statValue in statValues)
            {
                int roundedValue = (int)Math.Round(statValue.Value * modifyLevel * 100);
                if (roundedValue == 0) continue;

                // 使用 TextManager 获取翻译后的属性名称 (key: "modifystattypenames.Condition" 等)
                string statKey = "modifystattypenames." + statValue.Key.ToString();
                LocalizedString statNameLocalized = TextManager.Get(statKey).Fallback(statValue.Key.ToString());
                description += $"\n  ‖color:{colorStr}‖{roundedValue.ToString("+0;-#")}%‖color:end‖ {statNameLocalized.Value}";
            }
        }
    }
}
