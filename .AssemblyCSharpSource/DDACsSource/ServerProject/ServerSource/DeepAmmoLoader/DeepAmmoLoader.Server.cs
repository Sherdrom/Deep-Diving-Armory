using Barotrauma.Networking;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace DDA.AmmoLoading;

public sealed partial class DeepAmmoLoader
{
    private double nextRefresh;
    private readonly ConditionalWeakTable<Client, StrongBox<uint>> clientRevisions = new();
    private string[] pages = [];
    private uint capturedRevision, capturedStockVersion;
    private sealed record SnapshotPage(int Index) : IEventData;
    private sealed record BatchReply(Client Recipient, string Data) : IEventData;

    public override IEventData ServerGetEventData() => new SnapshotPage(0);
    public override bool ValidateEventData(NetEntityEvent.IData data) =>
        TryExtractEventData<SnapshotPage>(data, out _) || TryExtractEventData<BatchReply>(data, out _);

    partial void PublishState()
    {
        if (GameMain.Server == null) { return; }
        int count = CapturePages().Length;
        for (int i = 0; i < count; i++) { Item.CreateServerEvent(this, new SnapshotPage(i)); }
    }

    private string[] CapturePages()
    {
        if (pages.Length > 0 && capturedRevision == revision && capturedStockVersion == Stock.Version) { return pages; }
        string data = EncodeSnapshot();
        int count = (data.Length + SnapshotPageSize - 1) / SnapshotPageSize;
        pages = new string[count];
        for (int i = 0; i < count; i++)
        {
            int start = i * SnapshotPageSize;
            pages[i] = data.Substring(start, Math.Min(SnapshotPageSize, data.Length - start));
        }
        capturedRevision = revision;
        capturedStockVersion = Stock.Version;
        return pages;
    }

    private void ResendState()
    {
        if (Timing.TotalTime < nextRefresh) { return; }
        nextRefresh = Timing.TotalTime + 0.5;
        PublishState();
    }

    public void ServerEventWrite(IWriteMessage msg, Client client, NetEntityEvent.IData extraData = null!)
    {
        msg.WriteUInt32(revision);
        if (TryExtractEventData<BatchReply>(extraData, out var reply))
        {
            msg.WriteInt32(-1);
            msg.WriteInt32(0);
            msg.WriteString(reply.Recipient == client ? reply.Data : "");
            return;
        }
        // Stable page indices let the game's mid-round sync retain one event per page, not every revision.
        int index = ExtractEventData<SnapshotPage>(extraData).Index;
        var current = CapturePages();
        msg.WriteInt32(index);
        msg.WriteInt32(current.Length);
        msg.WriteString(index < current.Length ? current[index] : "");
    }

    public void ServerEventRead(IReadMessage msg, Client client)
    {
        var command = (Command)msg.ReadByte();
        uint expectedRevision = msg.ReadUInt32();
        ushort targetId = msg.ReadUInt16();
        int count = msg.ReadByte();
        if (!Item.CanClientAccess(client)) { return; }
        if (command == Command.Refresh)
        {
            ResendState();
            return;
        }
        // Other players may change stock; only this client's completed commands invalidate its next request.
        if (count > AmmoPlan.MaxGroups || expectedRevision > revision ||
            (command == Command.Withdraw && expectedRevision != revision) ||
            (clientRevisions.TryGetValue(client, out var previous) && expectedRevision < previous.Value))
        {
            ResendState();
            return;
        }
        var plan = ReadPlan(msg, count);
        if (plan == null) { ResendState(); return; }

        uint before = revision;
        BatchResult? batchResult = null;
        try
        {
            var magazine = GetOwnedMagazine(Entity.FindEntityByID(targetId) as Item, client.Character);
            if (command == Command.LoadBatch)
            {
                batchResult = LoadBatch(client.Character, magazine, plan);
                if (batchResult.Loaded > 0) { clientRevisions.GetOrCreateValue(client).Value = revision; }
            }
            else
            {
                bool success = command switch
                {
                    Command.Load => TryLoad(plan, magazine),
                    Command.Unload => TryUnload(magazine),
                    Command.Withdraw => plan.Length == 1 && plan[0].Count == 1 && TryWithdraw(plan[0].Id),
                    _ => false
                };
                if (success) { clientRevisions.GetOrCreateValue(client).Value = revision; }
                else if (revision == before) { ResendState(); }
            }
        }
        finally { if (revision != before) { PublishState(); } }
        if (batchResult != null) { Item.CreateServerEvent(this, new BatchReply(client, JsonSerializer.Serialize(batchResult, LoaderJson.Default.BatchResult))); }
    }

    private static AmmoRun[]? ReadPlan(IReadMessage msg, int count)
    {
        if (count == 0) { return []; }
        if (count == 1)
        {
            uint id = msg.ReadUInt32();
            int amount = msg.ReadUInt16();
            return ItemPrefab.Prefabs.Find(p => p.UintIdentifier == id) is { } matched
                ? [new(matched.Identifier.Value, amount)] : null;
        }
        var groups = new (uint Id, int Amount)[count];
        var unresolved = new HashSet<uint>();
        for (int i = 0; i < count; i++)
        {
            groups[i] = (msg.ReadUInt32(), msg.ReadUInt16());
            unresolved.Add(groups[i].Id);
        }
        var identifiers = new Dictionary<uint, string>(unresolved.Count);
        foreach (var prefab in ItemPrefab.Prefabs)
        {
            if (!unresolved.Remove(prefab.UintIdentifier)) { continue; }
            identifiers.Add(prefab.UintIdentifier, prefab.Identifier.Value);
            if (unresolved.Count == 0) { break; }
        }
        if (unresolved.Count != 0) { return null; }
        var plan = new AmmoRun[count];
        for (int i = 0; i < count; i++) { plan[i] = new(identifiers[groups[i].Id], groups[i].Amount); }
        return plan;
    }
}
