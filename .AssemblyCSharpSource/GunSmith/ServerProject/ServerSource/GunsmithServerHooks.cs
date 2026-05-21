namespace GunSmith
{
    public static class GunsmithServerHooks
    {
        public static void RegisterLuaHooks(Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
        {
            hook.Add("DeepGunsmithRegisterQuickSlotCapacity", args =>
            {
                string? itemIdentifier = FindStringArg(args, 0);
                int maxSlot = FindIntArg(args, 0);
                if (itemIdentifier != null && maxSlot >= 0)
                {
                    GunsmithQuickSlotCapacityPatch.RegisterQuickSlotCapacity(itemIdentifier, maxSlot);
                }
                return null;
            });

            hook.Add("DeepGunsmithClearQuickAttachmentBarrelTransforms", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    GunsmithQuickAttachmentBarrelTransforms.ClearTransforms(item);
                }
                return null;
            });

            hook.Add("DeepGunsmithRegisterQuickAttachmentBarrelTransform", args =>
            {
                Item? item = FindArg<Item>(args);
                string? key = FindStringArg(args, 0);
                if (item == null ||
                    string.IsNullOrWhiteSpace(key) ||
                    !TryFindFloatArg(args, 0, out float localX) ||
                    !TryFindFloatArg(args, 1, out float localY) ||
                    !TryFindFloatArg(args, 2, out float rotation))
                {
                    DebugConsole.ThrowError("GunSmith QAT received a malformed barrel transform payload. Expected item, key, localX, localY, rotation.");
                    return null;
                }

                GunsmithQuickAttachmentBarrelTransforms.RegisterTransform(item, key, localX, localY, rotation);
                return null;
            });
        }

        private static T? FindArg<T>(IEnumerable<object?> args) where T : class
        {
            foreach (object? arg in args)
            {
                if (arg is T value)
                {
                    return value;
                }
            }
            return null;
        }

        private static string? FindStringArg(IReadOnlyList<object?> args, int stringIndex)
        {
            int currentIndex = 0;
            foreach (object? arg in args)
            {
                if (arg is string text)
                {
                    if (currentIndex == stringIndex)
                    {
                        return text;
                    }
                    currentIndex++;
                }
            }
            return null;
        }

        private static int FindIntArg(IReadOnlyList<object?> args, int intIndex)
        {
            int currentIndex = 0;
            foreach (object? arg in args)
            {
                if (arg is int intValue)
                {
                    if (currentIndex == intIndex)
                    {
                        return intValue;
                    }
                    currentIndex++;
                }
                else if (arg is double doubleValue)
                {
                    if (currentIndex == intIndex)
                    {
                        return (int)doubleValue;
                    }
                    currentIndex++;
                }
                else if (arg is float floatValue)
                {
                    if (currentIndex == intIndex)
                    {
                        return (int)floatValue;
                    }
                    currentIndex++;
                }
            }
            return -1;
        }

        private static bool TryFindFloatArg(IReadOnlyList<object?> args, int numberIndex, out float value)
        {
            int currentIndex = 0;
            foreach (object? arg in args)
            {
                float? number = arg switch
                {
                    int intValue => intValue,
                    double doubleValue => (float)doubleValue,
                    float floatValue => floatValue,
                    _ => null
                };

                if (number.HasValue)
                {
                    if (currentIndex == numberIndex)
                    {
                        value = number.Value;
                        return float.IsFinite(value);
                    }
                    currentIndex++;
                }
            }

            value = 0.0f;
            return false;
        }
    }
}
