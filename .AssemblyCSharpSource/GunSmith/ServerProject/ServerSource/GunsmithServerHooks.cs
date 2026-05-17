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
    }
}
