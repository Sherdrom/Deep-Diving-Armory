using Barotrauma.Networking;
using System.Runtime.CompilerServices;

namespace DDA.AmmoLoading;

public sealed partial class ManualMagazineLoading
{
    private static readonly ConditionalWeakTable<Client, StrongBox<uint>> lastStart = new();
    private Client? requester;
    // Positive duration starts the next round, zero cancels, negative means the last round committed.
    private sealed record State(ushort User, uint Session, int Loaded, float Duration) : IEventData;
    public override IEventData ServerGetEventData() => new State(owner?.ID ?? 0, session, loaded, owner == null ? 0 : duration);
    public override bool ValidateEventData(NetEntityEvent.IData data) => TryExtractEventData<State>(data, out _);

    partial void PublishProgress() => Item.CreateServerEvent(this, ServerGetEventData());

    partial void NotifyEnd(bool finished)
    {
        if (!Item.Removed && !Item.IsInRemoveQueue)
        { Item.CreateServerEvent(this, new State(owner!.ID, session, loaded, finished ? -1 : 0)); }
        requester = null;
    }

    public void ServerEventRead(IReadMessage msg, Client client)
    {
        uint token = msg.ReadUInt32();
        ushort sourceId = msg.ReadUInt16();
        if (client.Character is not { } user) { return; }
        if (sourceId == 0)
        {
            if (requester == client && session == token) { End(false); }
            return;
        }
        var previous = lastStart.GetOrCreateValue(client);
        if (unchecked((int)(token - previous.Value)) <= 0) { return; }
        previous.Value = token;
        var origin = (msg.ReadUInt16(), msg.ReadInt32(), msg.ReadInt32());
        if (client.InGame && TargetAddress(Item) == origin && Begin(user, ReadSources(msg, sourceId), token))
        {
            requester = client;
            PublishProgress();
        }
        else if (Item.IsOwnedBy(user))
        { Item.CreateServerEvent(this, new State(user.ID, token, 0, 0)); }
    }

    private static Item[] ReadSources(IReadMessage msg, ushort sourceId)
    {
        if (sourceId != ushort.MaxValue) { return Entity.FindEntityByID(sourceId) is Item source ? [source] : []; }
        int count = msg.ReadByte();
        if (count is < 2 or > Inventory.MaxPossibleStackSize) { return []; }
        var sources = new Item[count];
        for (int i = 0; i < count; i++)
        {
            if (Entity.FindEntityByID(msg.ReadUInt16()) is not Item item) { return []; }
            sources[i] = item;
        }
        return sources;
    }

    public void ServerEventWrite(IWriteMessage msg, Client client, NetEntityEvent.IData extraData = null!)
    {
        var state = ExtractEventData<State>(extraData);
        msg.WriteUInt16(state.User);
        msg.WriteUInt32(state.Session);
        msg.WriteInt32(state.Loaded);
        msg.WriteSingle(state.Duration);
    }
}
