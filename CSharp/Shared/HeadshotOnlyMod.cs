using Barotrauma;
using Microsoft.Xna.Framework;
using HarmonyLib;
using System;
using System.Collections.Generic;
using System.Linq;

namespace HeadshotOnlyMod
{
    public class ModMain : IAssemblyPlugin
    {
        public void Initialize()
        {
            // 应用补丁
            HarmonyPatches.ApplyPatches();
            Console.WriteLine("[HeadshotOnlyMod] 加载成功！deep_headshot_deadly和deep_headshot_deadly_irresistible Affliction现在只在Human的Head肢体上生效，其他生物所有肢体都不生效。");
        }

        public void OnLoadCompleted()
        {
        }

        public void PreInitPatching()
        {
        }

        public void Dispose()
        {
        }
    }

    // 补丁类，用于修改Character.DamageLimb方法
    public static class HarmonyPatches
    {
        public static void ApplyPatches()
        {
            var harmony = new Harmony("HeadshotOnlyMod");
            
            // 补丁Character.DamageLimb方法
            var method = AccessTools.Method(typeof(Character), "DamageLimb", new[] {
                typeof(Vector2), typeof(Limb), typeof(IEnumerable<Affliction>), typeof(float), 
                typeof(bool), typeof(Vector2), typeof(Character), typeof(float), typeof(bool), 
                typeof(float), typeof(bool), typeof(bool), typeof(bool)
            });
            var prefix = AccessTools.Method(typeof(HarmonyPatches), "DamageLimbPrefix");
            
            harmony.Patch(method, new HarmonyMethod(prefix));
        }

        // 前缀补丁，在方法执行前修改参数
        public static void DamageLimbPrefix(ref Character __instance, ref Vector2 worldPosition, ref Limb hitLimb, ref IEnumerable<Affliction> afflictions, ref float stun, ref bool playSound, ref Vector2 attackImpulse, ref Character attacker, ref float damageMultiplier, ref bool allowStacking, ref float penetration, ref bool shouldImplode, ref bool ignoreDamageOverlay, ref bool recalculateVitality)
        {
            // 检查目标角色是否是Human，且是否是Head肢体
            bool isHuman = __instance != null && __instance.IsHuman;
            bool isHeadLimb = hitLimb != null && hitLimb.type == LimbType.Head;
            
            // 只有Human的Head肢体才生效deep_headshot_deadly和deep_headshot_deadly_irresistible
            // 其他情况（非Human，或Human的非Head肢体）都过滤掉这两个Affliction
            if (isHuman && isHeadLimb)
            {
                // 是Human的Head肢体，不做任何修改（让deep_headshot_deadly和deep_headshot_deadly_irresistible生效）
                return;
            }
            
            // 其他情况，过滤掉deep_headshot_deadly和deep_headshot_deadly_irresistible Affliction
            if (afflictions != null)
            {
                afflictions = afflictions.Where(a => 
                    a.Prefab.Identifier != "deep_headshot_deadly" && 
                    a.Prefab.Identifier != "deep_headshot_deadly_irresistible"
                ).ToList();
            }
        }
    }
}