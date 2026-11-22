using Barotrauma.Networking;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace DDA.AmmoLoading;

public sealed partial class DeepAmmoLoader
{
    private double nextRefresh;
    private readonly ConditionalWeakTable<Client, StrongBox<uint>> clientRevisions = new();
    private sealed record BatchReply(Client Recipient, BatchResult Result) : IEventData;

    public override IEventData ServerGetEventData() => CapturePages()[0];
    public override bool ValidateEventData(NetEntityEvent.IData data) =>
        TryExtractEventData<SnapshotPage>(data, out _) || TryExtractEventData<BatchReply>(data, out _);

    partial void PublishState()
    {
        if (GameMain.Server == null) { return; }
        foreach (var page in CapturePages()) { Item.CreateServerEvent(this, page); }
    }

    public void ServerEventWrite(IWriteMessage msg, Client client, NetEntityEvent.IData extraData = null!)
    {
        var page = TryExtractEventData<BatchReply>(extraData, out var reply)
            ? new SnapshotPage(revision, -1, 0, reply.Recipient == client ? JsonSerializer.Serialize(reply.Result) : "")
            : ExtractEventData<SnapshotPage>(extraData);
        msg.WriteUInt32(page.Revision);
        msg.WriteInt32(page.Index);
        msg.WriteInt32(page.Count);
        msg.WriteString(page.Data);
    }

    public void ServerEventRead(IReadMessage msg, Client client)
    {
        var command = (Command)msg.ReadByte();
        uint expectedRevision = msg.ReadUInt32();
        ushort targetId = msg.ReadUInt16();
        int count = msg.ReadByte();
        var plan = new List<AmmoRun>();
        bool valid = count <= AmmoPlan.MaxGroups;
        for (int i = 0; i < count; i++)
        {
            uint prefabId = msg.ReadUInt32();
            int amount = msg.ReadUInt16();
            if (ItemPrefab.Prefabs.Find(p => p.UintIdentifier == prefabId) is { } prefab) { plan.Add(new(prefab.Identifier.Value, amount)); }
            else { valid = false; }
        }
        if (!Item.CanClientAccess(client)) { return; }
        if (command == Command.Refresh)
        {
            if (Timing.TotalTime >= nextRefresh)
            {
                nextRefresh = Timing.TotalTime + 0.5;
                PublishState();
            }
            return;
        }
        // Other players may change stock; only this client's completed commands invalidate its next request.
        if (!valid || expectedRevision > revision ||
            (command == Command.Withdraw && expectedRevision != revision) ||
            (clientRevisions.TryGetValue(client, out var previous) && expectedRevision < previous.Value))
        {
            if (Timing.TotalTime >= nextRefresh)
            {
                nextRefresh = Timing.TotalTime + 0.5;
                PublishState();
            }
            return;
        }
        var magazine = GetOwnedMagazine(Entity.FindEntityByID(targetId) as Item, client.Character);
        if (command == Command.LoadBatch)
        {
            var result = LoadBatch(client.Character, magazine, plan);
            if (result.Loaded > 0) { clientRevisions.GetOrCreateValue(client).Value = revision; }
            Item.CreateServerEvent(this, new BatchReply(client, result));
            return;
        }
        bool success = command switch
        {
            Command.Load => TryLoad(plan, magazine),
            Command.Unload => TryUnload(magazine),
            Command.Withdraw => plan.Count == 1 && plan[0].Count == 1 && TryWithdraw(plan[0].Id),
            _ => false
        };
        if (success) { clientRevisions.GetOrCreateValue(client).Value = revision; }
        else { PublishState(); }
    }
}
