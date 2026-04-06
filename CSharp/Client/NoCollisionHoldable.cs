using HarmonyLib;
using Barotrauma;
using Barotrauma.Items.Components;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;

namespace Barotrauma
{
    public static class NoCollisionHoldablePatch
    {
        public static void ApplyPatch()
        {
            var harmony = new Harmony("NoCollisionHoldableMod");
            
            // 获取OnPusherCollision方法
            var method = AccessTools.Method(typeof(Holdable), "OnPusherCollision", new[] {
                typeof(Fixture), typeof(Fixture), typeof(Contact)
            });
            
            // 获取前缀方法
            var prefix = AccessTools.Method(typeof(NoCollisionHoldablePatch), "OnPusherCollisionPrefix");
            
            // 应用补丁
            harmony.Patch(method, new HarmonyMethod(prefix));
        }
        
        // 前缀方法 - 覆盖原方法的行为
        public static bool OnPusherCollisionPrefix(Fixture sender, Fixture other, Contact contact, ref bool __result)
        {
            if (other.Body.UserData is Character character)
            {
                // 所有角色都不会被阻挡
                __result = false;
                return false; // 跳过原方法
            }
            else
            {
                // 非角色对象仍然会被阻挡
                __result = true;
                return false; // 跳过原方法
            }
        }
    }
    
    // 模组主类
    public class NoCollisionHoldableMod : ACsMod
    {
        public override void Initialize()
        {
            NoCollisionHoldablePatch.ApplyPatch();
        }
        
        public override void Stop()
        {
            // 在这里添加清理代码（如果需要）
        }
    }
}