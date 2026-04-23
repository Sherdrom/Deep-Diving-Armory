namespace GunsmithPatch
{
    [HarmonyPatch]
    public static class GunsmithSpritePatch
    {
        [HarmonyPatch(typeof(Item), nameof(Item.Update))]
        [HarmonyPostfix]
        private static void KeepSpritesApplied(Item __instance)
        {
            if (GunsmithApi.TryGetState(__instance, out GunsmithSpriteState? state))
            {
                GunsmithApi.ApplyState(__instance, state);
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.SetActiveSprite))]
        [HarmonyPostfix]
        private static void UseGunsmithWorldSprite(Item __instance)
        {
            if (GunsmithApi.TryGetState(__instance, out GunsmithSpriteState? state))
            {
                GunsmithApi.ApplyState(__instance, state);
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.Sprite), MethodType.Getter)]
        [HarmonyPostfix]
        private static void OverrideSpriteGetter(Item __instance, ref Sprite __result)
        {
            if (GunsmithApi.TryGetState(__instance, out GunsmithSpriteState? state))
            {
                __result = state.WorldSprite;
            }
        }

        [HarmonyPatch(typeof(Item), nameof(Item.Remove))]
        [HarmonyPrefix]
        private static void RemoveSpriteState(Item __instance)
        {
            GunsmithApi.RemoveState(__instance);
        }

        [HarmonyPatch(typeof(GUI), nameof(GUI.Update))]
        [HarmonyPostfix]
        private static void KeepWindowVisible()
        {
            GunsmithApi.RefreshWindow();
        }
    }
}
