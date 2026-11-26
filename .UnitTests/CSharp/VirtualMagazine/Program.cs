using System.Collections;
using System.Collections.Immutable;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using MoonSharp.Interpreter;

// Real deployed DLLs; rendering/physics refresh is stubbed, stack operations and Lua conversion are not.
if (args.Length != 3)
{
    Console.Error.WriteLine("Usage: VirtualMagazine.Tests <game directory> <VCE directory> <DDA directory>");
    return 2;
}
try
{
    RunTests(args);
    return 0;
}
catch (Exception error)
{
    Console.Error.WriteLine("FAIL: " + error);
    return 1;
}

static void RunTests(string[] args)
{
    string gameDirectory = Path.GetFullPath(args[0]);
    string platform = OperatingSystem.IsWindows() ? "Windows" : OperatingSystem.IsMacOS() ? "Mac" : "Linux";
    string vceDirectory = Path.Combine(Path.GetFullPath(args[1]), "bin", platform, "Client");
    string ddaDirectory = Path.GetFullPath(args[2]);
    foreach (string path in new[] {
        Path.Combine(gameDirectory, "Barotrauma.dll"),
        Path.Combine(vceDirectory, "VanillaComponentsExpandedClient.dll"),
        Path.Combine(ddaDirectory, "bin", platform, "Client", "Deep-Diving-ArmoryClient.dll") })
        if (!File.Exists(path)) throw new FileNotFoundException("Required runtime DLL is missing", path);
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
    Assembly vce = Assembly.Load("VanillaComponentsExpandedClient");
    Console.WriteLine($"Runtime: {game.GetName().Version}; VCE: {vce.Location}");
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
    object harmony = Activator.CreateInstance(harmonyType, "DDA.VirtualMagazine.Tests")!;
    Assembly loader = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(ddaDirectory,
        "bin", platform, "Client", "Deep-Diving-ArmoryClient.dll"));
    Type module = loader.GetType("DDA.AmmoLoading.Plugin", true)!;
    const BindingFlags moduleMethods = BindingFlags.Static | BindingFlags.NonPublic;
    try
    {
        // The game owns IBarotraumaPlugin services; exercise VCE's real firing patch without faking that host.
        object processor = harmonyType.GetMethod("CreateClassProcessor", new[] { typeof(Type) })!.Invoke(harmony,
            new object[] { vce.GetType("VCE_VirtualizedMagazine.RangedWeaponPatch", true)! })!;
        processor.GetType().GetMethod("Patch", Type.EmptyTypes)!.Invoke(processor, null);
        vce.GetType("VCE_VirtualizedMagazine.ProjectileShootDispatcher", true)!.GetMethod("Init")!.Invoke(null, null);
        var patched = ((IEnumerable)harmonyType.GetMethod("GetPatchedMethods")!.Invoke(harmony, null)!).Cast<MethodBase>().ToArray();
        Assert(patched.Any(m => m.DeclaringType?.FullName == "VCE_SRW.SwitchableRangedWeapon" && m.Name == "Use"),
            "VCE did not install the SRW virtual-projectile dispatcher");
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
        object magazineItem = Empty(itemType);
        Set(magazineItem, "<MaxCondition>k__BackingField", 2f);
        Set(magazine, "item", magazineItem);
        Set(magazine, "<LoadedAmmoIdentifiers>k__BackingField", Activator.CreateInstance(typeof(Stack<>).MakeGenericType(identifierType)));
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

        IList components = (IList)NewList(GameType("Barotrauma.Items.Components.ItemComponent"));
        components.Add(magazine);
        Set(magazineItem, "components", components);
        var componentCache = (IDictionary)Activator.CreateInstance(Field(itemType, "componentsByType").FieldType)!;
        componentCache[containerType] = components;
        Set(magazineItem, "componentsByType", componentCache);
        object weaponContainer = Empty(containerType);
        object weaponInventory = Inventory(magazineItem);
        Set(weaponContainer, "Inventory", weaponInventory);
        Assembly hud = loader;
        MethodInfo countAmmo = hud.GetType("RemainedAmmo.RemainedAmmo", throwOnError: true)!.GetMethod("GetRemainedAmmo")
            ?? throw new MissingMethodException("RemainedAmmo.GetRemainedAmmo");
        Assert((int)countAmmo.Invoke(null, new object[] { 0, Empty(itemType), weaponContainer, 0.99f })! == 1,
            "HUD must use LoadedCount, not condition percentage");
        use.Invoke(magazine, new object?[] { 1f, null });
        use.Invoke(magazine, new object?[] { 1f, null });
        Assert(Count() == 0, "empty magazine underflowed");
        Assert((int)countAmmo.Invoke(null, new object[] { 0, Empty(itemType), weaponContainer, 0.99f })! == 0,
            "empty magazine HUD was nonzero");
        cache[Id("556x45round_tit")] = cache[Id("wrongcaliber")];
        cache[Id("762x51round_tit")] = cache[Id("allowed")];
        cache[Id("57x28round_tit")] = cache[Id("otherallowed")];
        cache[Id("762x39round_lead")] = cache[Id("wrongcaliber")];
        cache[Id("556x45round")] = cache[Id("allowed")];
        cache[Id("45acpround_lead")] = cache[Id("otherallowed")];
        Type propertyType = GameType("Barotrauma.SerializableProperty");
        Set(magazine, "<SerializableProperties>k__BackingField",
            propertyType.GetMethod("GetProperties", [typeof(object)])!.Invoke(null, [magazine]));
        CheckSandboxLoadout(ddaDirectory, magazine, identifierType, containerType, propertyType, Count);
        magazineType.GetMethod("UnLoadAmmoArray")!.Invoke(magazine, new object?[] { null });
        CheckLua(magazine, identifierType);
        Assert(Count() == 1, "Lua ref-list conversion failed to load the real magazine");
        rounds = (IList)NewList(identifierType);
        rounds.Add(Id("otherallowed"));
        magazineType.GetMethod("LoadAmmoArray")!.Invoke(magazine, new object[] { rounds });
        PropertyInfo serialized = magazineType.GetProperty("LoadedAmmoIdentifiersArray")!;
        var saved = (Array)serialized.GetValue(magazine)!;
        Assert(saved.Cast<object>().Select(id => id.ToString()).SequenceEqual(["allowed", "otherallowed"]),
            "serialized rounds must be bottom-first");
        magazineType.GetMethod("UnLoadAmmoArray")!.Invoke(magazine, new object?[] { null });
        Assert(Count() == 0, "unload did not clear the stack");
        serialized.SetValue(magazine, saved);
        Assert(Count() == 2 && magazineType.GetProperty("TopIdentifier")!.GetValue(magazine)!.ToString() == "otherallowed",
            "serialized mixed order did not round-trip into an empty magazine");
        use.Invoke(magazine, new object?[] { 1f, null });
        Set(magazine, "<AllowedAmmoTags>k__BackingField", Tags());
        rounds = (IList)NewList(identifierType);
        rounds.Add(Id("wrongcaliber"));
        magazineType.GetMethod("PushAmmoArray")!.Invoke(magazine, new object[] { rounds });
        Assert(Count() == 2, "empty whitelist must still accept valid ammo in VCE's demo magazine");
        // Exercise the same lookup, cleanup and magazine Use as a DDA weapon, without simulating ballistics.
        var weapon = Empty(itemType);
        var weaponPrefab = Empty(prefabType);
        var file = Empty(GameType("Barotrauma.ItemFile"));
        var package = Empty(GameType("Barotrauma.RegularPackage"));
        Set(package, "<Name>k__BackingField", "Renamed Armory");
        Set(file, "ContentPackage", package);
        Set(weaponPrefab, "ContentFile", file);
        Set(weapon, "Prefab", weaponPrefab);
        Set(weapon, "ownInventory", weaponInventory);
        var srw = Empty(vce.GetType("VCE_SRW.SwitchableRangedWeapon", true)!);
        Set(srw, "item", weapon);
        Set(srw, "switchableSlots", new List<int> { 0 });
        Set(srw, "domagcheck", true);
        var find = srw.GetType().GetMethod("FindProjectile", BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly)!;
        var proxy = Empty(vce.GetType("VCE_VirtualizedMagazine.VirtualizedProjectile", true)!);
        var proxyItem = Empty(itemType);
        Set(proxy, "item", proxyItem);
        Set(proxy, "Launcher", weapon);
        Set(proxyItem, "Prefab", Empty(prefabType));
        Set(proxyItem, "container", magazineItem);
        Set(proxyItem, "condition", 100f);
        var projectileComponents = (IList)NewList(GameType("Barotrauma.Items.Components.ItemComponent"));
        projectileComponents.Add(proxy);
        var proxyCache = (IDictionary)Activator.CreateInstance(componentCache.GetType())!;
        proxyCache[proxy.GetType()] = proxyCache[proxy.GetType().BaseType!] = projectileComponents;
        Set(proxyItem, "componentsByType", proxyCache);
        var magazineInventory = Inventory(proxyItem);
        Set(weaponInventory, "container", weaponContainer);
        Set(magazineInventory, "container", magazine);
        Set(magazineItem, "ownInventory", magazineInventory);
        Set(magazine, "Inventory", magazineInventory);
        var remove = itemType.GetMethod("RemoveContained")!;
        // Neither inventory notifications nor sprite refresh can run without a game scene.
        foreach (var notification in new[] { containerType.GetMethod("OnItemRemoved"), itemType.GetMethod("SetActiveSprite") })
        {
            patchArgs[0] = notification;
            patch.Invoke(harmony, patchArgs);
        }
        Set(magazineItem, "condition", (float)Count());
        Assert(find.Invoke(srw, [true]) == proxy, "initial round missing");
        remove.Invoke(weapon, [proxyItem]);
        Assert(find.Invoke(srw, [true]) == null, "unpatched shot cleanup should reproduce the missing second round");
        Set(proxyItem, "container", magazineItem);
        module.GetMethod("Init", moduleMethods)!.Invoke(null, [harmony, package]);
        module.GetMethod("PatchWeapons", moduleMethods)!.Invoke(null, [harmony]);
        var cleanup = module.GetMethod("RemoveFiredProjectile", BindingFlags.Static | BindingFlags.NonPublic)!;
        var getInstructions = harmonyType.Assembly.GetType("HarmonyLib.PatchProcessor")!.GetMethods()
            .Single(m => m.Name == "GetCurrentInstructions" && m.GetParameters()[1].ParameterType == typeof(int));
        foreach (var weaponType in new[] { srw.GetType(), srw.GetType().BaseType! })
        {
            var fire = weaponType.GetMethod("Use", BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly)!;
            var il = (IEnumerable)getInstructions.Invoke(null, [fire, int.MaxValue, null])!;
            var calls = il.Cast<object>().Select(i => i.GetType().GetField("operand")!.GetValue(i)).OfType<MethodInfo>().ToArray();
            Assert(calls.Contains(cleanup) && !calls.Contains(remove) && calls.Any(m => m.Name == "DispatchShoot"),
                $"{weaponType.Name}.Use must keep VCE shooting and use DDA cleanup even when RemoveContained would be inlined");
        }
        for (int remaining = 2; remaining > 0; remaining--)
        {
            Set(magazineItem, "condition", (float)Count()); // UpdateAmmoData is stubbed in this harness.
            Assert(Count() == remaining && find.Invoke(srw, [true]) == proxy, "SRW lost the loaded projectile");
            Assert(magazineType.GetProperty("TopIdentifier")!.GetValue(magazine)!.ToString() ==
                (remaining == 2 ? "wrongcaliber" : "allowed"), "mixed magazine fired out of order");
            cleanup.Invoke(null, [weapon, proxyItem]);
            use.Invoke(magazine, [1f, null]);
        }
        Set(magazineItem, "condition", (float)Count());
        Assert(Count() == 0 && find.Invoke(srw, [true]) == null, "SRW should stop on the empty magazine");
        var otherPackage = Empty(package.GetType());
        Set(otherPackage, "<Name>k__BackingField", "Renamed Armory");
        Set(file, "ContentPackage", otherPackage);
        cleanup.Invoke(null, [weapon, proxyItem]);
        Assert(itemType.GetProperty("Container")!.GetValue(proxyItem) == null, "another package with the same name must retain its own behavior");
        Set(file, "ContentPackage", package);
        Set(proxyItem, "container", magazineItem);
        proxyCache.Remove(proxy.GetType());
        projectileComponents[0] = Empty(proxy.GetType().BaseType!);
        cleanup.Invoke(null, [weapon, proxyItem]);
        Assert(itemType.GetProperty("Container")!.GetValue(proxyItem) == null, "ordinary projectiles must still be removed");
        Console.WriteLine("PASS: deployed SRW consecutive shots and empty stop, cleanup scope, VCE consumption, HUD and mixed-stack round-trip.");
        var fixes = loader;
        CheckNetworkImpacts(game, fixes, proxy);
        CheckWeaponUseFeedback(fixes);
    }
    finally
    {
        module.GetMethod("Dispose", moduleMethods)!.Invoke(null, null);
        harmonyType.GetMethod("UnpatchSelf")!.Invoke(harmony, null);
    }
}

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

static void CheckWeaponUseFeedback(Assembly fixes)
{
    var type = fixes.GetType("WeaponSyncFix.WeaponShots", true)!;
    var shots = Activator.CreateInstance(type)!;
    var take = type.GetMethod("Take", BindingFlags.NonPublic | BindingFlags.Instance)!;
    var claim = type.GetMethod("Claim", BindingFlags.NonPublic | BindingFlags.Instance)!;
    object Local(ushort input) => take.Invoke(shots, [input, 1d])!;
    object Echo(ushort input, uint ordinal = 0) =>
        Activator.CreateInstance(take.ReturnType, input, ordinal)!;
    bool Play(object key, double now = 1d) => (bool)claim.Invoke(shots, [key, now])!;

    Assert(Play(Local(21)) && Play(Local(23)), "predicted shots play immediately");
    Assert(!Play(Echo(23)) && Play(Echo(22)) && !Play(Echo(21)) && !Play(Echo(22)),
        "only the missing middle shot plays, including reordered or repeated echoes");
    Assert(Play(Echo(24)) && !Play(Local(24)), "an early confirmation plays once");
    Assert(Play(Local(24)) && !Play(Echo(24, 1)), "two uses within one input remain distinct");
    Assert(Play(Echo(23), 1200d), "a wrapped input can play again");
    Console.WriteLine("PASS: per-shot weapon use feedback.");
}

static void CheckNetworkImpacts(Assembly game, Assembly fixes, object virtualProjectile)
{
    const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;
    var client = game.GetType("Barotrauma.GameMain", true)!.GetField("Client", flags)!;
    var itemEvent = fixes.GetType("WeaponSyncFix.NetworkEventContext", true)!.GetField("IsItemEvent", flags)!;
    var prefix = fixes.GetType("DamageRollbackFix.ApplyStatusEffectsDedupPatch", true)!.GetMethod("Prefix", flags)!;
    var mark = fixes.GetType("DamageRollbackFix.ImpactTimeTracker", true)!.GetMethod("RecordImpact", flags)!;
    var onImpact = Enum.Parse(game.GetType("Barotrauma.ActionType", true)!, "OnImpact");
    bool ShouldApply(object projectile) =>
        (bool)prefix.Invoke(null, [projectile, onImpact, 1f, null, null, null, null, null, 1f])!;

    var previousClient = client.GetValue(null);
    var previousEvent = itemEvent.GetValue(null);
    try
    {
        client.SetValue(null, RuntimeHelpers.GetUninitializedObject(client.FieldType));
        itemEvent.SetValue(null, true);
        var projectileType = game.GetType("Barotrauma.Items.Components.Projectile", true)!;
        projectileType.GetProperty("Hitscan")!.SetValue(virtualProjectile, true);
        Assert(ShouldApply(virtualProjectile), "a virtual ray impact must bypass the vanilla launch queue");
        mark.Invoke(null, [virtualProjectile]);
        Assert(ShouldApply(virtualProjectile) && ShouldApply(virtualProjectile),
            "successive network impacts on a reused virtual projectile must both pass");
        var ordinary = RuntimeHelpers.GetUninitializedObject(projectileType);
        mark.Invoke(null, [ordinary]);
        Assert(!ShouldApply(ordinary), "a predicted vanilla impact must still be suppressed");
        Console.WriteLine("PASS: immediate VCE ray impacts, consecutive hits, and vanilla prediction deduplication.");
    }
    finally
    {
        itemEvent.SetValue(null, previousEvent);
        client.SetValue(null, previousClient);
    }
}

[MethodImpl(MethodImplOptions.NoInlining)]
static void CheckSandboxLoadout(string ddaDirectory, object magazine, Type identifierType, Type containerType,
    Type propertyType, Func<int> count)
{
    // LuaCs exposes the base game types in the sandbox.
    Assert(!UserData.IsTypeRegistered(magazine.GetType()), "sandbox test requires an unregistered VCE type");
    UserData.RegisterType(containerType);
    UserData.RegisterType(propertyType);
    UserData.RegisterType(identifierType);
    var script = new Script(CoreModules.Preset_SoftSandbox);
    script.Globals["Identifier"] = UserData.CreateStatic(identifierType);
    script.Globals["magazine"] = magazine;
    script.Globals["roundCount"] = count;
    script.DoString("""
        CSActive = false
        hooks = {}
        Hook = {
            HookMethodType = { After = 1 },
            Patch = function(id, _, _, _, callback) hooks[id] = callback end,
            Add = function(event, _, callback) hooks[event] = callback end
        }
        CharacterTeamType = { Team1 = 1 }
        Timer = { GetTime = function() return 0 end }
        local item = { Prefab = { Identifier = "testmag" }, MaxCondition = 2.75,
            HasTag = function(tag) return tag == "deep_virtualmagazine" end,
            OwnInventory = { Container = magazine, AllItemsMod = function() end } }
        setmetatable(item, { __index = function(_, key) if key == "Condition" then return roundCount() end end })
        function spawn()
            return { Name = "test", IsHuman = true, IsBot = true, TeamID = 2,
                Inventory = { AllItemsMod = function(_, previous) if not previous then return item end end } }
        end
        """);
    script.DoString(File.ReadAllText(Path.Combine(ddaDirectory, "Lua/Scripts/PeachTechnology/AmmoFill/NpcMagazineLoadout.lua")));
    script.DoString("""
        hooks["NpcMagazineLoadout.QueueOnInitializeItem"](nil,
            { character = spawn(), humanPrefab = { Identifier = "deep_co_soldier" } })
        Timer.GetTime = function() return 1 end
        hooks.think()
        """);
    var type = magazine.GetType();
    string[] Rounds() => ((Array)type.GetProperty("LoadedAmmoIdentifiersArray")!.GetValue(magazine)!)
        .Cast<object>().Select(id => id.ToString()!).ToArray();
    Assert(Rounds().SequenceEqual(["762x51round_tit", "762x51round_tit"]), "sandboxed NPC ammo priority or capacity failed");
    type.GetMethod("Use")!.Invoke(magazine, [1f, null]);
    script.DoString("""
        hooks["NpcMagazineLoadout.QueueOnGiveJobItems"]({ Prefab = { Identifier = "securityofficer" } }, { character = spawn() })
        Timer.GetTime = function() return 2 end
        hooks.think()
        """);
    Assert(Rounds().SequenceEqual(["762x51round_tit", "556x45round"]), "sandboxed crew failed to top up with job ammo");
    Console.WriteLine("PASS: sandboxed NPC and crew loadouts with the deployed VCE magazine.");
}

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
