using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using Barotrauma;
using Barotrauma.Items.Components;
using Barotrauma.Networking;
using DDA.AmmoLoading;
using VCE_VirtualizedMagazine;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

// Run from the mod root with a .NET runtime matching the game binary architecture.
string platform = OperatingSystem.IsMacOS() ? "Mac" : OperatingSystem.IsWindows() ? "Windows" : "Linux";
AssemblyLoadContext.Default.Resolving += (_, name) =>
{
    string folder = name.Name switch
    {
        "Deep-Diving-ArmoryClient" => Path.Combine("bin", platform, "Client"),
        "VanillaComponentsExpandedClient" => Path.Combine("../Vanilla-Components-Expanded/bin", platform, "Client"),
        _ => "../.."
    };
    string path = Path.GetFullPath(Path.Combine(folder, name.Name + ".dll"));
    return File.Exists(path) ? AssemblyLoadContext.Default.LoadFromAssemblyPath(path) : null;
};
Run();

[MethodImpl(MethodImplOptions.NoInlining)]
static void Run()
{
    const BindingFlags fields = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
    static T Blank<T>() => (T)RuntimeHelpers.GetUninitializedObject(typeof(T));
    static void Check(bool value, string message) { if (!value) { throw new Exception(message); } }

    var user = Blank<Character>();
    var inventory = Blank<CharacterInventory>();
    user.Inventory = inventory;
    InvSlotType[] types = [InvSlotType.LeftHand, InvSlotType.Any, InvSlotType.Any];
    typeof(CharacterInventory).GetField("<SlotTypes>k__BackingField", fields)!.SetValue(inventory, types);
    typeof(Inventory).GetField("capacity", fields)!.SetValue(inventory, types.Length);
    typeof(Inventory).GetField("Owner", fields)!.SetValue(inventory, user);
    typeof(Inventory).GetField("slots", fields)!.SetValue(inventory, types.Select(_ => new Inventory.ItemSlot(inventory)).ToArray());
    var prefab = Blank<ItemPrefab>();
    prefab.maxStackSizeCharacterInventory = 4;
    var item = Blank<Item>();
    var peer = Blank<Item>();
    typeof(MapEntity).GetField("Prefab", fields)!.SetValue(item, prefab);
    typeof(MapEntity).GetField("Prefab", fields)!.SetValue(peer, prefab);
    inventory.ForceToSlot(item, 1);
    inventory.ForceToSlot(peer, 1);
    inventory.ForceToSlot(item, 0);
    var loading = Blank<ManualMagazineLoading>();
    typeof(ItemComponent).GetField("item", fields)!.SetValue(loading, item);
    var type = loading.GetType();
    void Set(string name, object value) => type.GetField(name, fields)!.SetValue(loading, value);
    Set("magazine", Blank<VirtualizedMagazine>());
    Check((bool)type.GetMethod("MoveMagazine", fields)!.Invoke(loading, [user, inventory, 2, false])! &&
        inventory.FindIndices(item).SequenceEqual([0, 2]) && inventory.GetItemsAt(1).Single() == peer &&
        user.HasEquippedItem(item, InvSlotType.LeftHand), "Native split lost the original hand or moved another magazine.");

    // Deliver the replicated slot change and session acknowledgement in both orders on the actual client component.
    Character.controlled = user;
    GameMain.Client = Blank<GameClient>();
    void State(float seconds)
    {
        var msg = new ReadWriteMessage();
        msg.WriteUInt16(user.ID);
        msg.WriteUInt32(7);
        msg.WriteInt32(2);
        msg.WriteSingle(seconds);
        msg.BitPosition = 0;
        loading.ClientEventRead(msg, 0);
    }
    foreach (bool ackFirst in new[] { false, true })
    {
        inventory.ForceToSlot(item, 1);
        inventory.ForceRemoveFromSlot(item, 2);
        Set("remoteSession", true);
        Set("owner", user);
        Set("local", loading);
        Set("targetSlot", ((Inventory)inventory, 1));
        Set("session", 7u);
        Set("duration", 0f);
        loading.IsActive = true;
        if (ackFirst) { State(1); loading.Update(.1f, null!); }
        inventory.ForceToSlot(item, 2);
        inventory.ForceRemoveFromSlot(item, 1);
        loading.Update(.1f, null!);
        if (!ackFirst) { State(1); }
        Check(loading.IsActive && user.HasEquippedItem(item, InvSlotType.LeftHand), "Client canceled a replicated split.");
        inventory.ForceRemoveFromSlot(item, 0);
        State(0);
        Check(!loading.IsActive && type.GetField("local", fields)!.GetValue(null) == null,
            "Server cancellation after stowing left the client active.");
        inventory.ForceToSlot(item, 0);
    }
    // Losing the transport must not turn a predicted client session into a single-player debit or restack.
    Set("remoteSession", true);
    Set("owner", user);
    Set("local", loading);
    loading.IsActive = true;
    GameMain.Client = null;
    loading.Update(2, null!);
    Check(!loading.IsActive && inventory.FindIndices(item).SequenceEqual([0, 2]), "Disconnect moved the client's target.");

    var requestType = type.GetNestedType("Request", fields)!;
    foreach (ushort[] ids in new ushort[][] { [], [123], [123, 456] })
    {
        var request = (ItemComponent.IEventData)Activator.CreateInstance(requestType, 9u, ids, ((ushort)34, 2, 6))!;
        var msg = new ReadWriteMessage();
        loading.ClientEventWrite(msg, new Item.ComponentStateEventData(loading, request));
        int bits = msg.BitPosition;
        msg.BitPosition = 0;
        Check(msg.ReadUInt32() == 9 && msg.ReadUInt16() == (ids.Length > 1 ? ushort.MaxValue : ids.FirstOrDefault()), "Wrong request header.");
        if (ids.Length > 0)
        { Check(msg.ReadUInt16() == 34 && msg.ReadInt32() == 2 && msg.ReadInt32() == 6, "Lost original inventory, container or slot."); }
        if (ids.Length > 1)
        { Check(msg.ReadByte() == ids.Length && ids.All(id => id == msg.ReadUInt16()), "Multi-drag changed package order."); }
        Check(msg.BitPosition == bits, "Unconsumed request data.");
    }
    Console.WriteLine("PASS: client disconnect and single, multi-package and cancel packets.");
    Console.WriteLine("PASS: native CharacterInventory retains the left hand and the client accepts both inventory/ack orders and server cancellation.");
}
