using System;
using System.Collections.Generic;
using System.Xml.Linq;
using Microsoft.Xna.Framework;

namespace Barotrauma.Items.Components
{
    partial class Modify : ItemComponent
    {
        public const int MaxModifyLevel = 5;
        public const int MinModifyLevel = -5;

        public enum StatType
        {
            Condition = 0,
            ExplosionRadius = 1,
            ExplosionDamage = 2,
            RepairSpeed = 3,
            RepairToolStructureRepairMultiplier = 4,
            RepairToolStructureDamageMultiplier = 5,
            RepairToolDeattachTimeMultiplier = 6,
            FirepowerMultiplier = 7,
            StrikingPowerMultiplier = 8,
            StrikingSpeedMultiplier = 9,
            FiringRateMultiplier = 10,
            RangedSpreadReduction = 11
        }

        private readonly Dictionary<StatType, float> statValues = new Dictionary<StatType, float>();

        private int modifyLevel;

        [Editable(MinValueInt = MinModifyLevel, MaxValueInt = MaxModifyLevel), Serialize(0, IsPropertySaveable.Yes)]
        public int ModifyLevel
        {
            get { return modifyLevel; }
            set
            {
                if (value == modifyLevel) { return; }

                bool wasInFullCondition = item.IsFullCondition;
                modifyLevel = MathHelper.Clamp(value, MinModifyLevel, MaxModifyLevel);
                item.RecalculateConditionValues();
                if (wasInFullCondition && statValues.ContainsKey(StatType.Condition))
                {
                    item.Condition = item.MaxCondition;
                }
            }
        }

        public Modify(Item item, ContentXElement element) : base(item, element)
        {
            foreach (XElement subElement in element.Elements())
            {
                switch (subElement.Name.ToString().ToLower())
                {
                    case "stattype":
                    case "statvalue":
                    case "modifystat":
                        string statTypeString = subElement.GetAttributeString("stattype", "");
                        if (!Enum.TryParse(statTypeString, true, out StatType statType))
                        {
                            DebugConsole.ThrowError("Invalid modify stat type \"" + statTypeString + "\" in item (" + ((MapEntity)item).Prefab.Identifier + ")",
                                contentPackage: element.ContentPackage);
                        }
                        float statValue = subElement.GetAttributeFloat("value", 0f);
                        statValues.TryAdd(statType, statValue);
                        break;
                }
            }

            IsActive = true;
        }

        public float GetValue(StatType statType)
        {
            if (!statValues.ContainsKey(statType)) { return 0.0f; }
            return statValues[statType] * modifyLevel;
        }

        public static int GetMaxModifyLevel()
        {
            return MaxModifyLevel;
        }
    }
}
