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
        LuaCsSetup.Instance.Networking.Receive(Message, args => Receive((IReadMessage)args[0]));

    private static void Receive(IReadMessage message)
    {
        ushort itemId = message.ReadUInt16();
        int component = message.ReadUInt16();
        ushort shooterId = message.ReadUInt16();
        var shot = new WeaponShot(message.ReadUInt16(), message.ReadUInt32());
        float deltaTime = message.ReadSingle();
        Recoil? recoil = message.ReadBoolean()
            ? new(new Vector2(message.ReadSingle(), message.ReadSingle()), message.ReadSingle()) : null;
        if (GameMain.Client is not { MidRoundSyncing: false } || GameMain.GameSession == null ||
            Entity.FindEntityByID(itemId) is not Item item || component >= item.Components.Count ||
            item.Components[component] is not RangedWeapon weapon || Entity.FindEntityByID(shooterId) is not Character shooter ||
            !For(weapon, shooter).Claim(shot, Timing.TotalTime)) { return; }

        weapon.ApplyStatusEffects(ActionType.OnUse, deltaTime, shooter, user: shooter);
        weapon.PlaySound(ActionType.OnUse, shooter);
        var muzzle = muzzleMethods.GetValue(weapon.GetType(),
            static type => AccessTools.Method(type, "LaunchProjSpecific", Type.EmptyTypes));
        muzzle.Invoke(weapon, null);
        if (recoil is { } kick) { item.body?.ApplyLinearImpulse(kick.Impulse, kick.MaxVelocity); }
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
