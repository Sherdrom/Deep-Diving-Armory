namespace GunSmith
{
    public static partial class GunsmithGui
    {
        private static LocalizedString L(string key)
            => TextManager.Get(key).Fallback(key);

        private static string LocalizeKey(string key)
            => L(key).Value;

        private static LocalizedString FormatL(string key, params object?[] args)
            => (LocalizedString)FormatLValue(key, args);

        private static string FormatLValue(string key, params object?[] args)
        {
            string value = LocalizeKey(key);
            for (int i = 0; i < args.Length; i++)
            {
                value = value.Replace("{" + i + "}", args[i]?.ToString() ?? string.Empty, StringComparison.Ordinal);
            }
            return value;
        }

        private static string LocalizePathLabel(string pathLabel)
        {
            if (string.IsNullOrWhiteSpace(pathLabel)) { return LocalizeKey("deep.gunsmith.ui.weapon_root"); }
            return string.Join(" > ",
                pathLabel
                    .Split('>', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Select(LocalizeKey));
        }

        private static string LocalizedItemName(Item? item)
        {
            string identifier = item?.Prefab?.Identifier.Value ?? string.Empty;
            return string.IsNullOrWhiteSpace(identifier)
                ? string.Empty
                : TextManager.Get("entityname." + identifier).Fallback(identifier).Value;
        }

        private static string InstallButtonText(GunsmithGuiPart part, bool installed)
        {
            if (installed || part.Status == "installed") { return LocalizeKey("deep.gunsmith.action.installed"); }
            return part.Status switch
            {
                "missing" => LocalizeKey("deep.gunsmith.action.missing"),
                "incompatible" => LocalizeKey("deep.gunsmith.action.incompatible"),
                "disabled" => LocalizeKey("deep.gunsmith.action.disabled"),
                _ => LocalizeKey(part.Id == EmptyPartId ? "deep.gunsmith.action.remove" : "deep.gunsmith.action.install")
            };
        }

        private static string FormatStatsLine(GunsmithStats stats)
            => $"{LocalizeKey("deep.gunsmith.stat.ergonomics")} {stats.Ergonomics:+0.##;-0.##;0} | {LocalizeStatType(StatTypes.RangedSpreadReduction)} {stats.Get(StatTypes.RangedSpreadReduction) * 100:+0.#;-0.#;0}% | {LocalizeStatType(StatTypes.RangedAttackSpeed)} {stats.Get(StatTypes.RangedAttackSpeed) * 100:+0.#;-0.#;0}% | {LocalizeStatType(StatTypes.RangedAttackMultiplier)} {stats.Get(StatTypes.RangedAttackMultiplier) * 100:+0.#;-0.#;0}%";

        private static List<string> FormatPartStats(GunsmithStats stats)
        {
            List<string> lines = new();

            AddNonZeroStatLine(lines, "deep.gunsmith.stat.ergonomics", stats.Ergonomics, "0.##");
            foreach (KeyValuePair<StatTypes, float> stat in stats.Values.OrderBy(stat => stat.Key))
            {
                AddNonZeroStatTypeLine(lines, stat.Key, stat.Value);
            }
            if (lines.Count == 0)
            {
                lines.Add(LocalizeKey("deep.gunsmith.stat.none"));
            }
            return lines;
        }

        private static void AddNonZeroPercentLine(List<string> lines, string key, float value)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            lines.Add($"{LocalizeKey(key)}: {value * 100:+0.#;-0.#;0}%");
        }

        private static void AddNonZeroStatTypeLine(List<string> lines, StatTypes statType, float value)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            if (IsFlatStat(statType))
            {
                lines.Add($"{LocalizeStatType(statType)}: {value:+0.#;-0.#;0}");
            }
            else
            {
                lines.Add($"{LocalizeStatType(statType)}: {value * 100:+0.#;-0.#;0}%");
            }
        }

        private static void AddNonZeroStatLine(List<string> lines, string key, float value, string format)
        {
            if (Math.Abs(value) < 0.0001f) { return; }
            lines.Add($"{LocalizeKey(key)}: {value.ToString("+" + format + ";-" + format + ";0", System.Globalization.CultureInfo.InvariantCulture)}");
        }

        private static string LocalizeStatType(StatTypes statType)
        {
            string key = $"deep.gunsmith.stattypes.{statType}";
            return TextManager.Get(key).Fallback(statType.ToString()).Value;
        }

        private static bool IsFlatStat(StatTypes statType)
            => statType.ToString().EndsWith("SkillBonus", StringComparison.Ordinal) ||
               statType.ToString().EndsWith("SkillOverride", StringComparison.Ordinal) ||
               statType is StatTypes.ExtraLevelGain or
                   StatTypes.ExtraMissionCount or
                   StatTypes.ExtraSpecialSalesCount or
                   StatTypes.MaxAttachableCount or
                   StatTypes.LockedTalents or
                   StatTypes.InventoryExtraStackSize;

        private static string FormatPartStatsBlock(GunsmithStats stats)
            => string.Join("\n", FormatPartStats(stats));
    }
}


