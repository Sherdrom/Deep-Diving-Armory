using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using VCE_VirtualizedMagazine;

namespace DeepDivingArmory;

internal static class ProjectilePatches
{
    internal static void Install(Harmony harmony)
    {
        HarmonyMethod collision(string name) => new(typeof(ProjectileCollisions), name);
        HarmonyMethod friendly(string name) => new(typeof(FriendlyFireProjectile), name);
        HarmonyMethod contract(string name) => new(typeof(ContractNoHighPenetration), name);
        var enter = contract(nameof(ContractNoHighPenetration.EnterHit));
        enter.priority = Priority.First;
        var exit = contract(nameof(ContractNoHighPenetration.ExitHit));

        harmony.Patch(AccessTools.DeclaredMethod(typeof(Projectile), "OnProjectileCollision",
            [typeof(Fixture), typeof(Fixture), typeof(Contact)]), prefix: collision(nameof(ProjectileCollisions.OnCollision)));

        foreach (Type type in new[] { typeof(Projectile), typeof(VirtualizedProjectile) })
        {
            // FiredRound is supplied by the installed VCE and absent from older compile-time references.
            var handle = AccessTools.DeclaredMethod(type, "HandleProjectileCollision");
            harmony.Patch(handle, prefix: enter, finalizer: exit);
            harmony.Patch(handle, prefix: collision(type == typeof(Projectile)
                ? nameof(ProjectileCollisions.HandleVanilla) : nameof(ProjectileCollisions.HandleVirtual)));

            harmony.Patch(AccessTools.DeclaredMethod(type, "Shoot", [typeof(Character), typeof(Vector2), typeof(Vector2),
                typeof(float), typeof(List<Body>), typeof(bool), typeof(float), typeof(float)]),
                prefix: friendly(nameof(FriendlyFireProjectile.Shoot)));
            harmony.Patch(AccessTools.DeclaredMethod(type, "ShouldIgnoreCharacterCollision", [typeof(Character)]),
                prefix: friendly(nameof(FriendlyFireProjectile.IgnoreFriendly)));
        }

        foreach (string name in new[] { nameof(Attack.DoDamage), nameof(Attack.DoDamageToLimb) })
        {
            harmony.Patch(AccessTools.DeclaredMethod(typeof(Attack), name), prefix: enter, finalizer: exit);
        }

        var apply = AccessTools.DeclaredMethod(typeof(Character), nameof(Character.ApplyAttack));
        var capture = contract(nameof(ContractNoHighPenetration.CapturePenetration));
        var filter = contract(nameof(ContractNoHighPenetration.ApplyAttack));
        capture.priority = Priority.First;
        filter.priority = Priority.Low;
        harmony.Patch(apply, prefix: capture);
        harmony.Patch(apply, prefix: filter);
        harmony.Patch(AccessTools.DeclaredMethod(typeof(StatusEffect), nameof(StatusEffect.HasRequiredItems)),
            prefix: contract(nameof(ContractNoHighPenetration.HasRequiredItems)));
    }
}
