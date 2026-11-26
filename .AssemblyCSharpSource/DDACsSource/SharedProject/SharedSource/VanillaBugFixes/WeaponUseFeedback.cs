using Barotrauma.Items.Components;
using Barotrauma.Networking;
using HarmonyLib;

namespace WeaponSyncFix;

internal readonly record struct WeaponShot(ushort Input, uint Ordinal);

internal sealed class WeaponShots
{
    // A full ushort input cycle takes over 18 minutes at 60 Hz.
    private const int Lifetime = 120;
    private ushort lastInput;
    private uint nextOrdinal;
    private double lastUse = double.NegativeInfinity;

    internal WeaponShot Peek(ushort input, double now) =>
        new(input, input == lastInput && now - lastUse < Lifetime ? nextOrdinal : 0);

    internal WeaponShot Take(ushort input, double now)
    {
        var shot = Peek(input, now);
        lastInput = input;
        nextOrdinal = shot.Ordinal + 1;
        lastUse = now;
        return shot;
    }

#if CLIENT
    private readonly HashSet<WeaponShot> played = new();
    private readonly Queue<(WeaponShot Shot, double Expiry)> expiry = new();

    internal bool WasPlayed(WeaponShot shot, double now)
    {
        while (expiry.TryPeek(out var entry) && entry.Expiry <= now) { played.Remove(expiry.Dequeue().Shot); }
        return played.Contains(shot);
    }

    internal bool Claim(WeaponShot shot, double now)
    {
        if (WasPlayed(shot, now)) { return false; }
        played.Add(shot);
        expiry.Enqueue((shot, now + Lifetime));
        return true;
    }
#endif
}

[HarmonyPatch]
internal static partial class WeaponUseFeedback
{
    [NetworkSerialize]
    internal readonly record struct Feedback(ushort ItemId, ushort Component, ushort ShooterId, ushort Input,
        uint Ordinal, float DeltaTime, bool HasRecoil, Vector2 Impulse, float MaxVelocity) : INetSerializableStruct;
    private static readonly ConditionalWeakTable<RangedWeapon, ConditionalWeakTable<Character, WeaponShots>> shots = new();
    private static WeaponShots For(RangedWeapon weapon, Character shooter) =>
        shots.GetOrCreateValue(weapon).GetOrCreateValue(shooter);

    // A subclass can call base.Use. Only the outermost call for this weapon confirms a shot.
    internal readonly record struct Recoil(Vector2 Impulse, float MaxVelocity);
    internal readonly record struct UseState(RangedWeapon? Weapon, Recoil? Kick, RangedWeapon? Deferred);
    [ThreadStatic] private static UseState current;

    [HarmonyTargetMethods]
    private static IEnumerable<MethodBase> TargetMethods() =>
        AccessTools.AllTypes().Where(typeof(RangedWeapon).IsAssignableFrom)
            .Select(t => AccessTools.DeclaredMethod(t, nameof(RangedWeapon.Use), [typeof(float), typeof(Character)]))
            .OfType<MethodInfo>().Where(m => !m.IsAbstract);

    [HarmonyPrefix]
    private static void Prefix(RangedWeapon __instance, [HarmonyArgument(1)] Character? character, out UseState __state)
    {
        __state = current;
        if (current.Weapon == __instance) { return; }
#if CLIENT
        current = new(__instance, null, ShouldDefer(__instance, character) ? __instance : null);
#else
        current = new(__instance, null, null);
#endif
    }

    [HarmonyPostfix]
    private static void Postfix(RangedWeapon __instance, bool __result, [HarmonyArgument(0)] float deltaTime,
        [HarmonyArgument(1)] Character? character, UseState __state)
    {
        // Sprayer.Use succeeds every held frame and has its own continuous spray feedback.
        if (!__result || character == null || __instance is Sprayer || __state.Weapon == __instance) { return; }
#if SERVER
        if (GameMain.Server == null) { return; }
        var shot = For(__instance, character).Take(character.LastProcessedID, Timing.TotalTime);
        Send(__instance, character, shot, deltaTime, current.Kick);
#else
        if (GameMain.Client == null || character != Character.Controlled) { return; }
        var history = For(__instance, character);
        history.Claim(history.Take(LocalInput(character), Timing.TotalTime), Timing.TotalTime);
#endif
    }

    [HarmonyFinalizer]
    private static void Finalizer(RangedWeapon __instance, UseState __state)
    {
        if (__state.Weapon != __instance) { current = __state; }
    }

    [HarmonyTranspiler]
    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> code) =>
        code.MethodReplacer(AccessTools.Method(typeof(PhysicsBody), nameof(PhysicsBody.ApplyLinearImpulse), [typeof(Vector2), typeof(float)]),
                            AccessTools.Method(typeof(WeaponUseFeedback), nameof(WeaponImpulse)));

    private static void WeaponImpulse(PhysicsBody body, Vector2 impulse, float maxVelocity)
    {
        if (current.Weapon?.Item.body == body)
        {
#if SERVER
            current = current with { Kick = new Recoil(impulse, maxVelocity) };
#else
            if (current.Deferred != null) { return; }
#endif
        }
        body.ApplyLinearImpulse(impulse, maxVelocity);
    }

#if SERVER
    private static void Send(RangedWeapon weapon, Character shooter, WeaponShot shot, float deltaTime, Recoil? recoil)
    {
        var feedback = new Feedback(weapon.Item.ID, (ushort)weapon.Item.GetComponentIndex(weapon), shooter.ID,
            shot.Input, shot.Ordinal, deltaTime, recoil.HasValue, recoil?.Impulse ?? Vector2.Zero, recoil?.MaxVelocity ?? 0);
        foreach (var client in GameMain.Server.ConnectedClients)
        {
            if (client.InGame && !client.NeedsMidRoundSync)
                DeepDivingArmory.Plugin.Network.SendToClient(client, NetworkHeader.WeaponUse, feedback);
        }
    }
#endif
}
