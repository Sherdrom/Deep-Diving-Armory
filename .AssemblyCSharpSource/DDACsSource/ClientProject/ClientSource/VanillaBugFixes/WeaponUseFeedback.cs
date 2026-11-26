using Barotrauma.Items.Components;
using Barotrauma.Networking;
using HarmonyLib;

namespace WeaponSyncFix;

internal static partial class WeaponUseFeedback
{
    private static readonly ConditionalWeakTable<Type, MethodInfo> muzzleMethods = new();

    // ControlLocalPlayer's current key state is serialized by the next UpdateNetInput.
    private static ushort LocalInput(Character character) => unchecked((ushort)(character.LastNetworkUpdateID + 1));

    private static bool ShouldDefer(RangedWeapon weapon, Character? shooter)
    {
        if (GameMain.Client == null || shooter == null || weapon is Sprayer) { return false; }
        if (shooter != Character.Controlled) { return true; }
        var history = For(weapon, shooter);
        return history.WasPlayed(history.Peek(LocalInput(shooter), Timing.TotalTime), Timing.TotalTime);
    }

    internal static void Register() =>
        DeepDivingArmory.Plugin.Network.RegisterHandler<NetworkHeader, Feedback>(NetworkHeader.WeaponUse, Receive);

    private static void Receive(Feedback message)
    {
        var shot = new WeaponShot(message.Input, message.Ordinal);
        if (GameMain.Client is not { MidRoundSyncing: false } || GameMain.GameSession == null ||
            Entity.FindEntityByID(message.ItemId) is not Item item || message.Component >= item.Components.Count ||
            item.Components[message.Component] is not RangedWeapon weapon || Entity.FindEntityByID(message.ShooterId) is not Character shooter ||
            !For(weapon, shooter).Claim(shot, Timing.TotalTime)) { return; }

        weapon.ApplyStatusEffects(ActionType.OnUse, message.DeltaTime, shooter, user: shooter);
        weapon.PlaySound(ActionType.OnUse, shooter);
        var muzzle = muzzleMethods.GetValue(weapon.GetType(),
            static type => AccessTools.Method(type, "LaunchProjSpecific", Type.EmptyTypes));
        muzzle.Invoke(weapon, null);
        if (message.HasRecoil) { item.body?.ApplyLinearImpulse(message.Impulse, message.MaxVelocity); }
    }

    // Item plays sound and applies OnUse after the component's Use method has returned.
    [HarmonyPatch(typeof(Item), nameof(Item.UseItemComponent))]
    private static class ItemUseScope
    {
        [HarmonyPrefix]
        private static void Prefix(ItemComponent ic, Character? user, out UseState __state)
        {
            __state = current;
            current = current with { Deferred = ic is RangedWeapon w && ShouldDefer(w, user) ? w : null };
        }

        [HarmonyFinalizer]
        private static void Finalizer(UseState __state) => current = __state;
    }

    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.PlaySound), typeof(ActionType), typeof(Character))]
    private static class Sound
    {
        private static bool Prefix(ItemComponent __instance, ActionType type) =>
            type != ActionType.OnUse || current.Deferred != __instance;
    }

    [HarmonyPatch(typeof(ItemComponent), nameof(ItemComponent.ApplyStatusEffects))]
    private static class Effects
    {
        private static bool Prefix(ItemComponent __instance, ActionType type) =>
            type != ActionType.OnUse || current.Deferred != __instance;
    }

    [HarmonyPatch]
    private static class Muzzle
    {
        private static IEnumerable<MethodBase> TargetMethods() =>
            AccessTools.AllTypes().Where(typeof(RangedWeapon).IsAssignableFrom)
                .Select(t => AccessTools.DeclaredMethod(t, "LaunchProjSpecific", Type.EmptyTypes)).OfType<MethodInfo>();
        private static bool Prefix(RangedWeapon __instance) => current.Deferred != __instance;
    }
}
