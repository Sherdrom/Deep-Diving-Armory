using Microsoft.Xna.Framework;
using System;
using System.Collections.Generic;
using Barotrauma;

namespace Barotrauma.Items.Components
{
    partial class Modify
    {
        public static readonly Color ModifyColor = new Color(255, 215, 0);
        public static readonly Color ModifyNegativeColor = new Color(255, 100, 100);

        public override void AddTooltipInfo(ref LocalizedString name, ref LocalizedString description)
        {
            if (modifyLevel == 0) return;

            bool isNegative = modifyLevel < 0;
            string colorStr = XMLExtensions.ToStringHex(isNegative ? ModifyNegativeColor : ModifyColor);

            string levelKey = $"modify.level.{modifyLevel}";
            LocalizedString suffixStr = TextManager.Get(levelKey).Fallback(isNegative ? "Negative Modification" : "Modification");
            name += $" ‖color:{colorStr}‖{suffixStr.Value}‖color:end‖";

            foreach (var statValue in statValues)
            {
                int roundedValue = (int)Math.Round(statValue.Value * modifyLevel * 100);
                if (roundedValue == 0) continue;

                string statKey = "modifystattypenames." + statValue.Key.ToString();
                LocalizedString statNameLocalized = TextManager.Get(statKey).Fallback(statValue.Key.ToString());
                description += $"\n  ‖color:{colorStr}‖{roundedValue.ToString("+0;-#")}%‖color:end‖ {statNameLocalized.Value}";
            }
        }
    }
}
