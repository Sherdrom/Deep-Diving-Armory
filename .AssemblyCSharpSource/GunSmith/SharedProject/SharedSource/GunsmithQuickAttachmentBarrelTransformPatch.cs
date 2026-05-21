using Barotrauma;
using Barotrauma.Items.Components;
using Microsoft.Xna.Framework;
using System.Collections.Concurrent;
using System.Globalization;

namespace GunSmith
{
    public static class GunsmithQuickAttachmentBarrelTransforms
    {
        private static readonly ConcurrentDictionary<Item, BarrelRule> RulesByItem = new();

        public static void ClearTransforms(Item item)
        {
            if (item == null) { return; }
            RulesByItem.TryRemove(item, out _);
        }

        public static void RegisterTransform(Item item, float localX, float localY, float rotationDegrees)
        {
            if (item == null || item.Removed)
            {
                return;
            }

            Vector2 localPosition = new(localX, localY);
            if (!IsFinite(localPosition) || !float.IsFinite(rotationDegrees))
            {
                DebugConsole.ThrowError(
                    $"GunSmith QAT received an invalid barrel transform. " +
                    $"weapon={item.Prefab.Identifier.Value}, " +
                    $"localPosition={localPosition}, rotationDegrees={rotationDegrees}");
                return;
            }

            RulesByItem[item] = new BarrelRule(localPosition, rotationDegrees);
            ApplyCurrentBarrelPos(item);
        }

        private static bool ApplyCurrentBarrelPos(Item item)
        {
            if (item == null || item.Removed)
            {
                return false;
            }

            if (!RulesByItem.TryGetValue(item, out BarrelRule rule))
            {
                return false;
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

        private static bool IsFinite(Vector2 value)
            => float.IsFinite(value.X) && float.IsFinite(value.Y);

        private readonly record struct BarrelRule(Vector2 LocalPosition, float RotationDegrees);
    }
}
