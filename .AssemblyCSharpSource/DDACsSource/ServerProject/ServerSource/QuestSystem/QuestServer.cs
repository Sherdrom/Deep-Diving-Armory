namespace DeepDivingArmory.Quests;

public static partial class QuestRuntime
{
    static partial void RegisterSide(ISimpleHookService hooks)
    {
        Plugin.Network.RegisterHandler<NetworkHeader, QuestRequest>(NetworkHeader.QuestRequest, Receive);
        hooks.RegisterHook<PluginClientJoinedRoundDelegate>(Sync);
    }

    private static QuestSnapshot Snapshot(bool declined = false) => new(Round, Revision, State.Write(snapshot: true), declined);

    private static void Sync(Client client)
    {
        if (GameMain.GameSession?.Campaign is { } mode && EnsureCampaign(mode))
        { Plugin.Network.SendToClient(client, NetworkHeader.QuestState, Snapshot()); }
    }

    private static void Receive(QuestRequest request, Client client)
    {
        if (!client.InGame) { return; }
        if (request.Action == (byte)QuestAction.Sync) { Sync(client); }
        else if (!Handle(request, client.Character) && readable)
        { Plugin.Network.SendToClient(client, NetworkHeader.QuestState, Snapshot(declined: true)); }
    }

    static partial void Publish() => Plugin.Network.Broadcast(NetworkHeader.QuestState, Snapshot());
}