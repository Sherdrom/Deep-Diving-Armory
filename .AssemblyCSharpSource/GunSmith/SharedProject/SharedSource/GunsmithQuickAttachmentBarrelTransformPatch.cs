using Barotrauma;
using Barotrauma.Items.Components;
using Microsoft.Xna.Framework;
using System;
using System.Collections.Concurrent;
using System.Globalization;

namespace GunSmith
{
    public static class GunsmithQuickAttachmentBarrelTransforms
    {
        public const string PrimaryKey = "primary";
        public const string LowerRailKey = "lower_rail";

        private static readonly ConcurrentDictionary<Item, ConcurrentDictionary<string, BarrelRule>> RulesByItem = new();
        private static readonly ConcurrentDictionary<Item, string> ActiveRuleKeyByItem = new();
        private static readonly ConcurrentDictionary<Item, int> ActiveProjectileSelectionByItem = new();
        private static readonly ConcurrentDictionary<Item, Vector2> CachedLocalPositions = new();

        public static void ClearTransforms(Item item)
        {
            if (item == null) { return; }
            RulesByItem.TryRemove(item, out _);
            ActiveRuleKeyByItem.TryRemove(item, out _);
            ActiveProjectileSelectionByItem.TryRemove(item, out _);
            CachedLocalPositions.TryRemove(item, out _);
        }

        public static void RegisterTransform(Item item, string key, float localX, float localY, float rotationDegrees)
        {
            if (item == null || item.Removed)
            {
                return;
            }

            string normalizedKey = NormalizeKey(key);
            if (string.IsNullOrEmpty(normalizedKey))
            {
                DebugConsole.ThrowError($"GunSmith QAT received a barrel transform with an empty key. weapon={item.Prefab.Identifier.Value}");
                return;
            }

            Vector2 localPosition = new(localX, localY);
            if (!IsFinite(localPosition) || !float.IsFinite(rotationDegrees))
            {
                DebugConsole.ThrowError(
                    $"GunSmith QAT received an invalid barrel transform. " +
                    $"weapon={item.Prefab.Identifier.Value}, " +
                    $"key={normalizedKey}, " +
                    $"localPosition={localPosition}, rotationDegrees={rotationDegrees}");
                return;
            }

            ConcurrentDictionary<string, BarrelRule> rules = RulesByItem.GetOrAdd(
                item,
                _ => new ConcurrentDictionary<string, BarrelRule>(StringComparer.OrdinalIgnoreCase));
            rules[normalizedKey] = new BarrelRule(localPosition, rotationDegrees);
            CachedLocalPositions.TryRemove(item, out _);
            ApplyCurrentBarrelPos(item, reportMissingActiveRule: false);
        }

        public static void ApplySelectedProjectile(Item item, int selectedProjectile)
        {
            if (item == null || item.Removed)
            {
                return;
            }

            ActiveRuleKeyByItem[item] = KeyForProjectileSelection(selectedProjectile);
            ActiveProjectileSelectionByItem[item] = selectedProjectile;
            CachedLocalPositions.TryRemove(item, out _);
            ApplyCurrentBarrelPos(item, reportMissingActiveRule: true);
        }

        public static bool TryGetCurrentLocalPosition(Item item, out Vector2 localPosition)
        {
            localPosition = Vector2.Zero;
            if (item == null || item.Removed)
            {
                return false;
            }

            if (CachedLocalPositions.TryGetValue(item, out localPosition))
            {
                return true;
            }

            if (!RulesByItem.TryGetValue(item, out ConcurrentDictionary<string, BarrelRule>? rules))
            {
                return false;
            }

            string activeKey = GetActiveRuleKey(item);
            if (!rules.TryGetValue(activeKey, out BarrelRule rule) &&
                !rules.TryGetValue(PrimaryKey, out rule))
            {
                return false;
            }

            localPosition = rule.LocalPosition;
            CachedLocalPositions[item] = localPosition;
            return true;
        }

        private static bool ApplyCurrentBarrelPos(Item item, bool reportMissingActiveRule)
        {
            if (item == null || item.Removed)
            {
                return false;
            }

            if (!RulesByItem.TryGetValue(item, out ConcurrentDictionary<string, BarrelRule>? rules))
            {
                return false;
            }

            string activeKey = GetActiveRuleKey(item);
            if (!rules.TryGetValue(activeKey, out BarrelRule rule))
            {
                if (reportMissingActiveRule && activeKey.Equals(LowerRailKey, StringComparison.OrdinalIgnoreCase))
                {
                    ReportMissingActiveRule(item, activeKey, rules);
                }

                if (!rules.TryGetValue(PrimaryKey, out rule))
                {
                    return false;
                }
            }

            RangedWeapon? rangedWeapon = item.GetComponent<RangedWeapon>();
            if (rangedWeapon == null)
            {
                DebugConsole.ThrowError($"GunSmith QAT barrel transform registered for a non-ranged weapon. weapon={item.Prefab.Identifier.Value}");
                return false;
            }

            rangedWeapon.BarrelPos = string.Create(
                CultureInfo.InvariantCulture,
                $"{rule.LocalPosition.X},{rule.LocalPosition.Y}");
            return true;
        }

        private static string GetActiveRuleKey(Item item)
        {
            if (ActiveRuleKeyByItem.TryGetValue(item, out string? key))
            {
                return key;
            }

            if (GunsmithQuickAttachmentBarrelSelectorPatch.TryGetSelectedProjectile(item, out int selectedProjectile))
            {
                key = KeyForProjectileSelection(selectedProjectile);
                ActiveRuleKeyByItem[item] = key;
                ActiveProjectileSelectionByItem[item] = selectedProjectile;
                return key;
            }

            return PrimaryKey;
        }

        private static string KeyForProjectileSelection(int selectedProjectile)
            => selectedProjectile == 1 ? LowerRailKey : PrimaryKey;

        private static string NormalizeKey(string? key)
            => string.IsNullOrWhiteSpace(key) ? string.Empty : key.Trim().ToLowerInvariant();

        private static void ReportMissingActiveRule(Item item, string activeKey, ConcurrentDictionary<string, BarrelRule> rules)
        {
            string selected = ActiveProjectileSelectionByItem.TryGetValue(item, out int selectedProjectile)
                ? selectedProjectile.ToString(CultureInfo.InvariantCulture)
                : "unknown";
            string registeredKeys = rules.IsEmpty ? "<none>" : string.Join(", ", rules.Keys);
            DebugConsole.ThrowError(
                $"GunSmith QAT selected a barrel rule that is not registered. " +
                $"weapon={item.Prefab.Identifier.Value}, " +
                $"selectedProjectile={selected}, " +
                $"activeKey={activeKey}, " +
                $"registeredKeys={registeredKeys}");
        }

        private static bool IsFinite(Vector2 value)
            => float.IsFinite(value.X) && float.IsFinite(value.Y);

        private readonly record struct BarrelRule(Vector2 LocalPosition, float RotationDegrees);
    }
}
