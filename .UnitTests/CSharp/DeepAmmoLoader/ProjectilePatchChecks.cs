using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;

internal static class ProjectilePatchChecks
{
    internal static MethodBase[] Run(Assembly game, Assembly vce, Assembly dda, Type harmony)
    {
        var checkedMethods = new HashSet<MethodBase>();
        const BindingFlags declared = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
        MethodInfo Method(Type type, string name, params string[] signature) =>
            type.GetMethods(declared).Single(m => m.Name == name && (signature.Length == 0 ||
                m.GetParameters().Select(p => p.ParameterType.Name).SequenceEqual(signature)));

        int Check(MethodBase method, string phase, string name)
        {
            var info = harmony.GetMethod("GetPatchInfo")!.Invoke(null, [method])
                ?? throw new Exception($"Missing Harmony patches on {method.DeclaringType}.{method.Name}");
            var patches = (IEnumerable)info.GetType().GetField(phase)!.GetValue(info)!;
            var entry = patches.Cast<object>().Single(patch =>
                patch.GetType().GetProperty("PatchMethod")!.GetValue(patch) is MethodInfo m && m.Module.Assembly == dda && m.Name == name);
            checkedMethods.Add(method);
            return (int)entry.GetType().GetField("priority")!.GetValue(entry)!;
        }

        var vanilla = game.GetType("Barotrauma.Items.Components.Projectile", true)!;
        var proxy = vce.GetType("VCE_VirtualizedMagazine.VirtualizedProjectile", true)!;
        Check(Method(vanilla, "OnProjectileCollision", "Fixture", "Fixture", "Contact"), "Prefixes", "OnCollision");
        foreach (var projectile in new[] { vanilla, proxy })
        {
            var collision = Method(projectile, "HandleProjectileCollision", "Fixture", "Vector2", projectile == proxy ? "FiredRound" : "Vector2");
            Check(collision, "Prefixes", projectile == proxy ? "HandleVirtual" : "HandleVanilla");
            Check(collision, "Prefixes", "EnterHit");
            Check(collision, "Finalizers", "ExitHit");
            Check(Method(projectile, "Shoot", "Character", "Vector2", "Vector2", "Single", "List`1", "Boolean", "Single", "Single"),
                "Prefixes", "Shoot");
            Check(Method(projectile, "ShouldIgnoreCharacterCollision", "Character"), "Prefixes", "IgnoreFriendly");
        }

        var attack = game.GetType("Barotrauma.Attack", true)!;
        foreach (string name in new[] { "DoDamage", "DoDamageToLimb" })
        {
            var damage = Method(attack, name);
            Check(damage, "Prefixes", "EnterHit");
            Check(damage, "Finalizers", "ExitHit");
        }
        var apply = Method(game.GetType("Barotrauma.Character", true)!, "ApplyAttack");
        if (Check(apply, "Prefixes", "CapturePenetration") <= 400 || Check(apply, "Prefixes", "ApplyAttack") >= 400)
        {
            throw new Exception("The two contract prefixes must bracket the normal-priority chip patch.");
        }
        Check(Method(game.GetType("Barotrauma.StatusEffect", true)!, "HasRequiredItems", "Entity"), "Prefixes", "HasRequiredItems");
        // A missing fixture throws inside the real VCE method, after our hit prefix has pushed its frame.
        var proxyCollision = Method(proxy, "HandleProjectileCollision", "Fixture", "Vector2", "FiredRound");
        try
        {
            proxyCollision.Invoke(RuntimeHelpers.GetUninitializedObject(proxy), [null, null, null]);
            throw new Exception("Expected the missing fixture to abort the collision.");
        }
        catch (TargetInvocationException ex) when (ex.InnerException is NullReferenceException) { }
        var frames = (IList?)dda.GetType("DeepDivingArmory.ContractNoHighPenetration", true)!
            .GetField("hits", BindingFlags.NonPublic | BindingFlags.Static)!.GetValue(null);
        if (frames?.Count != 0) { throw new Exception("Aborted VCE hit left an unbalanced contract stack."); }
        return checkedMethods.ToArray();
    }
}
