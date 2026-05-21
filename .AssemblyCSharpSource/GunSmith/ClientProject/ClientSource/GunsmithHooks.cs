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
                string? statsSpec = FindStringArg(args, 4);
                string? managedItemSpec = FindStringArg(args, 5);
                int width = FindIntArg(args, 0);
                int height = FindIntArg(args, 1);
                if (item != null && signature != null && layerSpec != null)
                {
                    ApplyFromLua(item, signature, layerSpec, inventorySpec ?? string.Empty, worldSpec ?? string.Empty, statsSpec ?? string.Empty, managedItemSpec ?? string.Empty, width, height);
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
                    GunsmithGui.OpenFromLua(item, title, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithOpenQuick", args =>
            {
                Item? item = FindArg<Item>(args);
                string? title = FindStringArg(args, 0);
                string? slotSpec = FindStringArg(args, 1);
                if (item != null && title != null && slotSpec != null)
                {
                    GunsmithGui.OpenQuickFromLua(item, title, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithRefreshParts", args =>
            {
                Item? item = FindArg<Item>(args);
                string? slotSpec = FindStringArg(args, 0);
                if (item != null && slotSpec != null)
                {
                    GunsmithGui.RefreshPartsFromLua(item, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithRefreshQuick", args =>
            {
                Item? item = FindArg<Item>(args);
                string? slotSpec = FindStringArg(args, 0);
                if (item != null && slotSpec != null)
                {
                    GunsmithGui.RefreshQuickFromLua(item, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithRegisterHiddenQuickSlots", args =>
            {
                string? itemIdentifier = FindStringArg(args, 0);
                string? slotSpec = FindStringArg(args, 1);
                if (itemIdentifier != null && slotSpec != null)
                {
                    GunsmithHiddenQuickSlotsPatch.RegisterHiddenSlots(itemIdentifier, slotSpec);
                }
                return null;
            });

            hook.Add("DeepGunsmithRegisterQuickSlotVisibility", args =>
            {
                string? itemIdentifier = FindStringArg(args, 0);
                int slotIndex = FindIntArg(args, 0);
                string? identifierSpec = FindStringArg(args, 1);
                if (itemIdentifier != null && slotIndex >= 0 && identifierSpec != null)
                {
                    GunsmithHiddenQuickSlotsPatch.RegisterVisibleWhenContained(itemIdentifier, slotIndex, identifierSpec);
                }
                return null;
            });

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

            hook.Add("DeepGunsmithClearQuickSlotLayouts", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    GunsmithQuickSlotLayoutPatch.ClearLayouts(item);
                }
                return null;
            });

            hook.Add("DeepGunsmithRegisterQuickSlotLayout", args =>
            {
                Item? item = FindArg<Item>(args);
                int slotIndex = FindIntArg(args, 0);
                float anchorX = FindFloatArg(args, 1);
                float anchorY = FindFloatArg(args, 2);
                float originX = FindFloatArg(args, 3);
                float originY = FindFloatArg(args, 4);
                float offsetX = FindFloatArg(args, 5);
                float offsetY = FindFloatArg(args, 6);
                float rotation = FindFloatArg(args, 7);
                bool hide = FindIntArg(args, 8) != 0;
                if (item != null && slotIndex >= 0)
                {
                    GunsmithQuickSlotLayoutPatch.RegisterLayout(
                        item,
                        slotIndex,
                        new Vector2(anchorX, anchorY),
                        new Vector2(originX, originY),
                        new Vector2(offsetX, offsetY),
                        rotation,
                        hide);
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
                if (item == null ||
                    !TryFindFloatArg(args, 0, out float localX) ||
                    !TryFindFloatArg(args, 1, out float localY) ||
                    !TryFindFloatArg(args, 2, out float rotation))
                {
                    DebugConsole.ThrowError("GunSmith QAT received a malformed barrel transform payload. Expected item, localX, localY, rotation.");
                    return null;
                }

                GunsmithQuickAttachmentBarrelTransforms.RegisterTransform(item, localX, localY, rotation);
                return null;
            });

            hook.Add("DeepGunsmithBeginQuickSlotMutation", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    GunsmithHiddenQuickSlotsPatch.BeginQuickSlotMutation(item);
                }
                return null;
            });

            hook.Add("DeepGunsmithEndQuickSlotMutation", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    GunsmithHiddenQuickSlotsPatch.EndQuickSlotMutation(item);
                }
                return null;
            });

            hook.Add("DeepGunsmithIsQuickSlotMutation", args =>
            {
                Item? item = FindArg<Item>(args);
                return item != null && GunsmithHiddenQuickSlotsPatch.IsQuickSlotMutation(item);
            });

            hook.Add("DeepGunsmithRequestState", args =>
            {
                Item? item = FindArg<Item>(args);
                if (item != null)
                {
                    Barotrauma.Items.Components.GunsmithData? data = item.GetComponent<Barotrauma.Items.Components.GunsmithData>();
                    if (data == null)
                    {
                        CallLuaHook("DeepGunsmithReceiveState", item, string.Empty);
                    }
                    else if (GameMain.Client != null)
                    {
                        data.RequestStateFromServer();
                    }
                    else
                    {
                        CallLuaHook("DeepGunsmithReceiveState", item, data.SavedState);
                    }
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
                    if (GameMain.Client != null)
                    {
                        data.SubmitStateToServer(savedState);
                    }
                    else
                    {
                        data.SavedState = savedState;
                    }
                }
                return null;
            });
        }

        internal static void CallLuaHook(string hookName, params object[] args)
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

        private static float FindFloatArg(IReadOnlyList<object> args, int numberIndex)
        {
            int index = 0;
            foreach (object arg in args)
            {
                float? value = arg switch
                {
                    int intValue => intValue,
                    double doubleValue => (float)doubleValue,
                    float floatValue => floatValue,
                    _ => null
                };

                if (value.HasValue)
                {
                    if (index == numberIndex) { return value.Value; }
                    index++;
                }
            }
            return 0.0f;
        }

        private static bool TryFindFloatArg(IReadOnlyList<object> args, int numberIndex, out float value)
        {
            int index = 0;
            foreach (object arg in args)
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
                    if (index == numberIndex)
                    {
                        value = number.Value;
                        return float.IsFinite(value);
                    }
                    index++;
                }
            }

            value = 0.0f;
            return false;
        }
    }
}
