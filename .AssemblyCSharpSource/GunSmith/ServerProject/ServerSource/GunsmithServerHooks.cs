using static GunSmith.GunsmithHookArgs;

namespace GunSmith
{
    public static class GunsmithServerHooks
    {
        public static void RegisterLuaHooks(Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
        {
            hook.Add("DeepGunsmithRegisterQuickSlotCapacity", args =>
            {
                string? itemIdentifier = FindStringArg(args, 0);
                int maxSlot = FindIntArg(args, 0, defaultValue: -1);
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

    }
}
