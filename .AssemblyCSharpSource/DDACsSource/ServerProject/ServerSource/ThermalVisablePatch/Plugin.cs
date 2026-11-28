namespace ThermalVisablePatch;

public partial class ThermalVisablePatch
{
    internal static void SyncClient(Client client)
    {
        foreach (var character in Character.CharacterList)
        {
            if (character.Params.HideInThermalGoggles)
                DeepDivingArmory.Plugin.Network.SendToClient(client, NetworkHeader.Thermal, new ThermalState(character.ID, true));
        }
    }
}
