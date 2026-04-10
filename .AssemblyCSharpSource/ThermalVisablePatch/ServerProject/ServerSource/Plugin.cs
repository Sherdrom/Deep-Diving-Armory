namespace ThermalVisablePatch
{
    public partial class ThermalVisablePatch : IAssemblyPlugin
    {
        // Server-specific code
        
        // 服务端新客户端加入时补发所有需要同步的角色状态
        [HarmonyPatch(typeof(GameServer), nameof(GameServer.OnInitializationComplete))]
        [HarmonyPostfix]
        static void ClientOnConnectedPostfix(GameServer __instance)
        {
            foreach (var character in Character.CharacterList)
            {
                Client? owner = __instance.connectedClients.Find(c => (c.Character == null || c.Character == character) && character.IsClientOwner(c));
                if (owner != null && owner.NeedsMidRoundSync)
                {
                    if (character.Params.HideInThermalGoggles)
                    {
                        var syncMsg = LuaCsSetup.Instance.Networking.Start("SyncHideInThermalGoggles");
                        syncMsg.WriteUInt16(character.ID);
                        syncMsg.WriteBoolean(true);
                        LuaCsSetup.Instance.Networking.Send(syncMsg, owner.Connection);
                    }
                }
            }
        }
    }
}
