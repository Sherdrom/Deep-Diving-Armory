using HarmonyLib;
using Barotrauma;
using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using Microsoft.Xna.Framework;
using System;

namespace Barotrauma
{
    public static class IgnoreArmLimbsPatch
    {
        public const float IgnoreChance = 0.6f;// 60%概率忽略双臂击中躯干
        
        public static void ApplyPatch()
        {
            var harmony = new Harmony("IgnoreArmLimbsMod");
            harmony.PatchAll();
        }
    }
    
    [HarmonyPatch(typeof(Projectile), "OnProjectileCollision")]
    [HarmonyPatch(new Type[] { typeof(Fixture), typeof(Fixture), typeof(Contact) })]
    static class Projectile_OnProjectileCollision_Patch
    {
        static bool Prefix(Fixture f1, Fixture target, Contact contact)
        {
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
            {
                if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand || 
                    limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm || 
                    limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                {
                    if (IgnoreArmLimbsPatch.IgnoreChance > 0f)
                    {
                        float randomValue = Rand.Range(0.0f, 1.0f);
                        if (randomValue < IgnoreArmLimbsPatch.IgnoreChance)
                        {
                            return false;
                        }
                    }
                }
            }
            return true;
        }
    }
    
    [HarmonyPatch(typeof(Projectile), "HandleProjectileCollision")]
    [HarmonyPatch(new Type[] { typeof(Fixture), typeof(Vector2), typeof(Vector2) })]
    static class Projectile_HandleProjectileCollision_Patch
    {
        static bool Prefix(Fixture target, Vector2 collisionNormal, Vector2 velocity)
        {
            if (target.Body.UserData is Limb limb && limb.character != null && limb.character.IsHuman)
            {
                if (limb.type == LimbType.RightHand || limb.type == LimbType.LeftHand || 
                    limb.type == LimbType.LeftForearm || limb.type == LimbType.RightForearm || 
                    limb.type == LimbType.LeftArm || limb.type == LimbType.RightArm)
                {
                    if (IgnoreArmLimbsPatch.IgnoreChance > 0f)
                    {
                        float randomValue = Rand.Range(0.0f, 1.0f);
                        if (randomValue < IgnoreArmLimbsPatch.IgnoreChance)
                        {
                            return false;
                        }
                    }
                }
            }
            return true;
        }
    }
    
    public class IgnoreArmLimbsMod : ACsMod
    {
        public override void Initialize()
        {
            IgnoreArmLimbsPatch.ApplyPatch();
        }
        
        public override void Stop()
        {
        }
    }
}