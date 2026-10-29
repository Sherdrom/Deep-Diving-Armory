using System.Collections;
using System.Collections.Immutable;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using MoonSharp.Interpreter;

// Real deployed DLLs; rendering/physics refresh is stubbed, stack operations and Lua conversion are not.
if (args.Length != 3) throw new ArgumentException("Expected game directory, VCE directory and DDA directory.");
string gameDirectory = Path.GetFullPath(args[0]);
string vceDirectory = Path.Combine(Path.GetFullPath(args[1]), "bin/Client/OSX");
string ddaDirectory = Path.GetFullPath(args[2]);
AssemblyLoadContext.Default.Resolving += (context, name) =>
{
    foreach (string directory in new[] { gameDirectory, vceDirectory })
    {
        string path = Path.Combine(directory, name.Name + ".dll");
        if (File.Exists(path)) return context.LoadFromAssemblyPath(path);
    }
    return null;
};
Assembly game = Assembly.Load("Barotrauma");
Assembly core = Assembly.Load("BarotraumaCore");
Assembly vce = Assembly.Load("VirtualizedMagazine");
Assembly.Load("SwitchableRangedWeapon");
Type GameType(string name) => game.GetType(name) ?? core.GetType(name, throwOnError: true)!;
Type magazineType = vce.GetType("VCE_VirtualizedMagazine.VirtualizedMagazine", true)!;
Type identifierType = GameType("Barotrauma.Identifier");
Type itemType = GameType("Barotrauma.Item");
Type prefabType = GameType("Barotrauma.ItemPrefab");
Type containerType = GameType("Barotrauma.Items.Components.ItemContainer");
Type inventoryType = GameType("Barotrauma.ItemInventory");
object Id(string value) => Activator.CreateInstance(identifierType, value)!;
object NewList(Type elementType) => Activator.CreateInstance(typeof(List<>).MakeGenericType(elementType))!;
object Empty(Type type) => RuntimeHelpers.GetUninitializedObject(type);
void Set(object instance, string name, object? value) => Field(instance.GetType(), name).SetValue(instance, value);
object Tags(params string[] tags)
{
    Array values = Array.CreateInstance(identifierType, tags.Length);
    for (int i = 0; i < tags.Length; i++) values.SetValue(Id(tags[i]), i);
    return typeof(ImmutableHashSet).GetMethods().Single(m => m.Name == "CreateRange" && m.GetParameters().Length == 1)
        .MakeGenericMethod(identifierType).Invoke(null, new object[] { values })!;
}
object Inventory(params object[] items)
{
    object inventory = Empty(inventoryType);
    Type slotType = Field(inventoryType, "slots").FieldType.GetElementType()!;
    Array slots = Array.CreateInstance(slotType, items.Length);
    for (int i = 0; i < items.Length; i++)
    {
        object slot = Activator.CreateInstance(slotType, inventory)!;
        ((IList)Field(slotType, "items").GetValue(slot)!).Add(items[i]);
        slots.SetValue(slot, i);
    }
    Set(inventory, "slots", slots);
    Set(inventory, "capacity", items.Length);
    return inventory;
}

Type harmonyType = Assembly.Load("0Harmony").GetType("HarmonyLib.Harmony", true)!;
Type harmonyMethodType = Assembly.Load("0Harmony").GetType("HarmonyLib.HarmonyMethod", true)!;
object plugin = Activator.CreateInstance(vce.GetType("VCE_VirtualizedMagazine.Plugin", true)!)!;
plugin.GetType().GetMethod("Initialize")!.Invoke(plugin, null);
try
{
    InvokePlugin(plugin.GetType().GetMethod("OnLoadCompleted")!.CreateDelegate<Action>(plugin));
    object pluginHarmony = Field(plugin.GetType(), "harmony").GetValue(plugin)!;
    var patched = ((IEnumerable)harmonyType.GetMethod("GetPatchedMethods")!.Invoke(pluginHarmony, null)!).Cast<MethodBase>().ToArray();
    Assert(patched.Any(m => m.DeclaringType?.FullName == "SRW.SwitchableRangedWeapon" && m.Name == "Use"),
        "VCE did not install the SRW virtual-projectile dispatcher");
}
finally { plugin.GetType().GetMethod("Dispose")!.Invoke(plugin, null); }

object harmony = Activator.CreateInstance(harmonyType, "DDA.VirtualMagazine.Tests")!;
try
{
    var prefix = Activator.CreateInstance(harmonyMethodType, typeof(TestHooks).GetMethod(nameof(TestHooks.SkipRefresh)))!;
    MethodInfo patch = harmonyType.GetMethods().Where(m => m.Name == "Patch" && m.GetParameters()[0].ParameterType == typeof(MethodBase))
        .OrderByDescending(m => m.GetParameters().Length).First();
    object?[] patchArgs = new object?[patch.GetParameters().Length];
    patchArgs[0] = magazineType.GetMethod("UpdateAmmoData");
    patchArgs[1] = prefix;
    patch.Invoke(harmony, patchArgs);

    var cache = (IDictionary)vce.GetType("VCE_VirtualizedMagazine.ElementHelper")!.GetField("ChachedPrefabs")!.GetValue(null)!;
    foreach (var (id, tag) in new[] { ("allowed", "556"), ("otherallowed", "556"), ("wrongcaliber", "762") })
    {
        object prefab = Empty(prefabType);
        Set(prefab, "tags", Tags(tag));
        cache[Id(id)] = prefab;
    }
    cache[Id("missing")] = null;
    object magazine = Empty(magazineType);
    Set(magazine, "loadedammoidentifiers", Activator.CreateInstance(typeof(Stack<>).MakeGenericType(identifierType)));
    Set(magazine, "<MaxSize>k__BackingField", 2);
    Set(magazine, "<AllowedAmmoTags>k__BackingField", Tags("556"));
    Set(magazine, "Inventory", Inventory());
    int Count() => (int)magazineType.GetProperty("LoadedCount")!.GetValue(magazine)!;
    IList rounds = (IList)NewList(identifierType);
    foreach (string id in new[] { "allowed", "wrongcaliber", "missing", "allowed", "allowed" }) rounds.Add(Id(id));
    object?[] input = { rounds };
    magazineType.GetMethod("PushAmmoArray")!.Invoke(magazine, input);
    Assert(Count() == 2 && ((IList)input[0]!).Count == 3, "whitelist, invalid ID or capacity handling failed");
    MethodInfo use = magazineType.GetMethod("Use")!;
    use.Invoke(magazine, new object?[] { 1f, null });
    Assert(Count() == 1, "one Use must consume exactly one round");

    object magazineItem = Empty(itemType);
    IList components = (IList)NewList(GameType("Barotrauma.Items.Components.ItemComponent"));
    components.Add(magazine);
    Set(magazineItem, "components", components);
    var componentCache = (IDictionary)Activator.CreateInstance(Field(itemType, "componentsByType").FieldType)!;
    componentCache[containerType] = components;
    Set(magazineItem, "componentsByType", componentCache);
    object weaponContainer = Empty(containerType);
    Set(weaponContainer, "Inventory", Inventory(magazineItem));
    Assembly hud = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(ddaDirectory, "bin/Client/OSX/RemainedAmmo.dll"));
    MethodInfo countAmmo = hud.GetType("RemainedAmmo.RemainedAmmo")!.GetMethod("GetRemainedAmmo")!;
    Assert((int)countAmmo.Invoke(null, new object[] { 0, Empty(itemType), weaponContainer, 0.99f })! == 1,
        "HUD must use LoadedCount, not condition percentage");
    use.Invoke(magazine, new object?[] { 1f, null });
    use.Invoke(magazine, new object?[] { 1f, null });
    Assert(Count() == 0, "empty magazine underflowed");
    Assert((int)countAmmo.Invoke(null, new object[] { 0, Empty(itemType), weaponContainer, 0.99f })! == 0,
        "empty magazine HUD was nonzero");
    CheckLua(magazine, identifierType);
    Assert(Count() == 1, "Lua ref-list conversion failed to load the real magazine");
    Set(magazine, "<AllowedAmmoTags>k__BackingField", Tags());
    rounds = (IList)NewList(identifierType);
    rounds.Add(Id("wrongcaliber"));
    magazineType.GetMethod("PushAmmoArray")!.Invoke(magazine, new object[] { rounds });
    Assert(Count() == 2, "empty whitelist must still accept valid ammo in VCE's demo magazine");
    Console.WriteLine("PASS: deployed VCE dispatcher, whitelist, capacity, consumption, HUD and MoonSharp mixed-ammo stack.");
}
finally { harmonyType.GetMethod("UnpatchSelf")!.Invoke(harmony, null); }

static FieldInfo Field(Type type, string name)
{
    for (Type? t = type; t != null; t = t.BaseType)
    {
        var field = t.GetField(name, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
        if (field != null) return field;
    }
    throw new MissingFieldException(type.FullName, name);
}
static void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }
[MethodImpl(MethodImplOptions.NoInlining)]
static void InvokePlugin(Action callback) => callback();
[MethodImpl(MethodImplOptions.NoInlining)]
static void CheckLua(object magazine, Type identifierType)
{
    UserData.RegisterType(magazine.GetType());
    UserData.RegisterType(identifierType);
    var script = new Script();
    script.Globals["magazine"] = magazine;
    script.Globals["Identifier"] = UserData.CreateStatic(identifierType);
    script.DoString("""
        magazine.PushAmmoArray({Identifier('allowed')})
        magazine.PushAmmoArray({Identifier('otherallowed')})
        assert(magazine.LoadedCount == 2 and tostring(magazine.TopIdentifier) == 'otherallowed')
        magazine.Use(1, nil)
        assert(magazine.LoadedCount == 1 and tostring(magazine.TopIdentifier) == 'allowed')
        """);
}
public static class TestHooks { public static bool SkipRefresh() => false; }
