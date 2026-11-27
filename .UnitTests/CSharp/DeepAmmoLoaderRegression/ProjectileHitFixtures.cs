global using System.Runtime.CompilerServices;

namespace Barotrauma
{
    public record ContentPackage(string Name);
    public enum StatTypes { None }
    public enum LimbType { LeftArm, RightArm, LeftForearm, RightForearm, LeftHand, RightHand, Head, Torso }
    public sealed record Limb(Character character, LimbType type);
    public record struct AttackResult(float Damage);
    public sealed class Attack
    {
        public Item? SourceItem;
        public float Penetration;
        public List<StatusEffect> StatusEffects = [];
    }
    public sealed class StatusEffect
    {
        public List<object> Afflictions = [], Explosions = [];
    }
    public sealed class CharacterInfo
    {
        public readonly Dictionary<(StatTypes, Identifier), float> Stats = [];
        public float GetSavedStatValue(StatTypes type, Identifier id) => Stats.GetValueOrDefault((type, id));
    }
    public sealed class CharacterHealth
    {
        public readonly Dictionary<Identifier, float> Afflictions = [];
        public float GetAfflictionStrengthByIdentifier(Identifier id) => Afflictions.GetValueOrDefault(id);
    }
    public sealed partial class Character
    {
        public bool IsHuman = true, Removed;
        public int Team;
        public CharacterInfo? Info;
        public CharacterHealth? CharacterHealth;
        public bool IsFriendly(Character other) => Team == other.Team;
    }
}

namespace Barotrauma.Items.Components
{
    public sealed partial class Projectile
    {
        public Attack? Attack;
        public Item? Launcher;
        public Character? User;
        public bool Hitscan, FriendlyFire = true;
        public int MaxTargetsToHit;
    }
}

namespace FarseerPhysics.Dynamics
{
    public sealed record Body(object? UserData);
    public sealed record Fixture(Body Body);
}
