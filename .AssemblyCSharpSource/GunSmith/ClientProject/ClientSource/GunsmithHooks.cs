namespace GunSmith
{
    public static partial class GunsmithApi
    {
        public static void RegisterLuaHooks(Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
        {
            hook.Add("DeepGunsmithApply", args =>
            {
                Item? item = FindArg<Item>(args);
                string? signature = FindStringArg(args, 0);
                string? layerSpec = FindStringArg(args, 1);
                string? inventorySpec = FindStringArg(args, 2);
                string? worldSpec = FindStringArg(args, 3);
                int width = FindIntArg(args, 0);
                int height = FindIntArg(args, 1);
                if (item != null && signature != null && layerSpec != null)
                {
                    ApplyFromLua(item, signature, layerSpec, inventorySpec ?? string.Empty, worldSpec ?? string.Empty, width, height);
                }
                return null;
            });

            hook.Add("DeepGunsmithOpen", args =>
            {
                Item? item = FindArg<Item>(args);
                string? title = FindStringArg(args, 0);
                string? slotSpec = FindStringArg(args, 1);
                if (item != null && title != null && slotSpec != null)
                {
                    OpenFromLua(item, title, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithRequestState", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    string savedState = item.GetComponent<Barotrauma.Items.Components.GunsmithData>()?.SavedState ?? string.Empty;
                    CallLuaHook("DeepGunsmithReceiveState", item, savedState);
                }
                return null;
            });

            hook.Add("DeepGunsmithSaveState", args =>
            {
                Item? item = FindArg<Item>(args);
                string? savedState = FindStringArg(args, 0);
                Barotrauma.Items.Components.GunsmithData? data = item?.GetComponent<Barotrauma.Items.Components.GunsmithData>();
                if (data != null && savedState != null)
                {
                    data.SavedState = savedState;
                }
                return null;
            });
        }

        private static void CallLuaHook(string hookName, params object[] args)
        {
            try
            {
                if (LuaCsSetup.Instance?.Hook is Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
                {
                    hook.Call(hookName, args);
                }
            }
            catch (Exception ex)
            {
                LuaCsSetup.PrintCsMessage($"[Gunsmith] Failed to call Lua hook '{hookName}': {ex.Message}");
            }
        }

        private static T? FindArg<T>(IEnumerable<object> args) where T : class
        {
            foreach (object arg in args)
            {
                if (arg is T value) { return value; }
            }
            return null;
        }

        private static string? FindStringArg(IReadOnlyList<object> args, int stringIndex)
        {
            int index = 0;
            foreach (object arg in args)
            {
                if (arg is string value)
                {
                    if (index == stringIndex) { return value; }
                    index++;
                }
            }
            return null;
        }

        private static int FindIntArg(IReadOnlyList<object> args, int intIndex)
        {
            int index = 0;
            foreach (object arg in args)
            {
                if (arg is int intValue)
                {
                    if (index == intIndex) { return intValue; }
                    index++;
                }
                if (arg is double doubleValue)
                {
                    if (index == intIndex) { return (int)doubleValue; }
                    index++;
                }
                if (arg is float floatValue)
                {
                    if (index == intIndex) { return (int)floatValue; }
                    index++;
                }
            }
            return 0;
        }
    }
}
