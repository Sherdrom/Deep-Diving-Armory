using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using VCE_SRW;

namespace DeepDivingArmory;

internal static partial class NoProjectileConsume
{
    internal static void Install(Harmony harmony)
    {
        HarmonyMethod Patch(string name) => new(typeof(NoProjectileConsume), name);
        var itemOperation = Patch(nameof(AllowItemOperation));
        var removal = Patch(nameof(AllowRemoval));
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Item), nameof(Item.Drop),
            [typeof(Character), typeof(bool), typeof(bool), typeof(bool)]), prefix: Patch(nameof(AllowDrop)));
        foreach (var type in new[] { typeof(Entity), typeof(Item) })
        {
            harmony.Patch(AccessTools.DeclaredMethod(type, nameof(Entity.Remove), Type.EmptyTypes), prefix: removal);
        }
        harmony.Patch(AccessTools.DeclaredMethod(typeof(EntitySpawner), nameof(EntitySpawner.AddItemToRemoveQueue),
            [typeof(Item), typeof(Action<Entity>)]), prefix: itemOperation);
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Item), nameof(Item.RemoveContained), [typeof(Item)]), prefix: itemOperation);
        foreach (var type in new[] { typeof(Inventory), typeof(CharacterInventory) })
        {
            harmony.Patch(AccessTools.DeclaredMethod(type, "PutItem",
                [typeof(Item), typeof(int), typeof(Character), typeof(bool), typeof(bool), typeof(bool)]), prefix: itemOperation);
        }

        harmony.Patch(AccessTools.DeclaredMethod(typeof(SwitchableRangedWeapon), "FindProjectile", [typeof(bool)]),
            postfix: Patch(nameof(FindRound)));
        harmony.Patch(AccessTools.DeclaredMethod(typeof(SwitchableRangedWeapon), nameof(SwitchableRangedWeapon.Use),
            [typeof(float), typeof(Character)]), prefix: Patch(nameof(BeginHandheld)), postfix: Patch(nameof(RestoreHandheld)),
            finalizer: Patch(nameof(EndHandheld)));
        HarmonyMethod? finishTracer = null;
#if CLIENT
        finishTracer = Patch(nameof(RestoreTracer));
#endif
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Projectile), nameof(Projectile.Use), [typeof(Character), typeof(float)]),
            prefix: Patch(nameof(BeginProjectile)), postfix: Patch(nameof(RestoreRound)), finalizer: finishTracer);
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Turret), "Launch",
            [typeof(Item), typeof(Character), typeof(float?), typeof(float)]), prefix: Patch(nameof(CaptureBolt)));
        var begin = Patch(nameof(BeginTurret));
        var end = Patch(nameof(EndTurret));
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Turret), "TryLaunch", [typeof(float), typeof(Character), typeof(bool)]),
            prefix: begin, finalizer: end);
#if CLIENT
        // Network replay calls Launch directly, outside TryLaunch.
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Turret), nameof(Turret.ClientEventRead), [typeof(IReadMessage), typeof(float)]),
            prefix: begin, finalizer: end);
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Projectile), nameof(Projectile.ClientEventRead), [typeof(IReadMessage), typeof(float)]),
            postfix: Patch(nameof(RestoreRound)));
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Projectile), "HandleProjectileCollision",
            [typeof(Fixture), typeof(Vector2), typeof(Vector2)]), postfix: Patch(nameof(FixTracer)));
        harmony.Patch(AccessTools.DeclaredMethod(typeof(Projectile), "LaunchProjSpecific", [typeof(Vector2), typeof(Vector2)]),
            postfix: Patch(nameof(RestoreTracer)));
#endif
    }
}
