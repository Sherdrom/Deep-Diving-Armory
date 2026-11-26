using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using System.Xml.Linq;

// Uses deployed assemblies without starting the game; no rendering, physics or network session.
if (args.Length is < 3 or > 4 || args.Length == 4 && args[3] is not ("Client" or "Server"))
{
    Console.Error.WriteLine("Usage: DeepAmmoLoader.Tests <game directory> <VCE directory> <DDA directory> [Client|Server]");
    return 2;
}
try { Run(args); return 0; }
catch (Exception error) { Console.Error.WriteLine(error); return 1; }

static void Run(string[] args)
{
    string target = args.Length == 4 ? args[3] : "Client";
    string dda = Path.GetFullPath(args[2]);
    string gameDirectory = Path.GetFullPath(args[0]);
    AssemblyLoadContext.Default.Resolving += (context, name) =>
    {
        string path = Path.Combine(gameDirectory, name.Name + ".dll");
        return File.Exists(path) ? context.LoadFromAssemblyPath(path) : null;
    };
    Assembly game = Assembly.Load(target == "Client" ? "Barotrauma" : "DedicatedServer"), core = Assembly.Load("BarotraumaCore");
    const BindingFlags staticMethods = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;
    var nativeLoader = game.GetType("Barotrauma.Plugins.PluginLoader", true)!;
    var packages = new Stack<object>();
    var loaded = (IEnumerable)nativeLoader.GetProperty("LoadedPlugins", staticMethods)!.GetValue(null)!;
    (Assembly Assembly, object Data) Load(string root)
    {
        string path = Path.Combine(Path.GetFullPath(root), "filelist.xml");
        var manifest = XDocument.Load(path);
        // Exercise the real loader and dependency rules without loading game assets or starting a session.
        manifest.Root!.Elements().Where(x => x.Name.LocalName is not ("PluginInfo" or "Dependency")).Remove();
        var package = Activator.CreateInstance(game.GetType("Barotrauma.RegularPackage", true)!, manifest, path)!;
        var file = ((IEnumerable)package.GetType().GetProperty("Files")!.GetValue(package)!).Cast<object>().Single();
        var result = nativeLoader.GetMethod("TryLoadPlugin", staticMethods)!.Invoke(null, [file]);
        Assert(result?.ToString() == "Success", $"Native loader rejected {path}: {result}");
        packages.Push(file);
        if (target == "Server") { nativeLoader.GetMethod("FinalizePluginLoad", staticMethods)!.Invoke(null, [file]); }
        var entry = loaded.Cast<object>().Last();
        return ((Assembly)entry.GetType().GetProperty("Assembly")!.GetValue(entry)!, entry.GetType().GetProperty("Data")!.GetValue(entry)!);
    }
    void Unload() => nativeLoader.GetMethod("UnloadPlugin", staticMethods)!.Invoke(null, [packages.Pop()]);
    var (vce, _) = Load(args[1]);
    var (adapter, data) = Load(dda);
    var registeredComponents = ((IEnumerable)Field(data.GetType(), "ItemComponents").GetValue(data)!).Cast<Type>();
    Assert(registeredComponents.Select(t => t.Name).ToHashSet().SetEquals(["DeepAmmoLoader", "ManualMagazineLoading"]),
        "Both XML components must be registered by Init.");
    Type GameType(string name) => game.GetType("Barotrauma." + name) ?? core.GetType("Barotrauma." + name, true)!;
    Type itemType = GameType("Item"), prefabType = GameType("ItemPrefab"), identifierType = GameType("Identifier");
    Type componentType = GameType("Items.Components.ItemComponent");
    Type loaderType = adapter.GetType("DDA.AmmoLoading.DeepAmmoLoader", true)!;
    Type pluginType = adapter.GetType("DDA.AmmoLoading.Plugin", true)!;
    PropertyInfo supply = loaderType.GetProperty("SupplyResolver")!;
    IList items = (IList)itemType.GetField("ItemList")!.GetValue(null)!;
    object Item(string id)
    {
        object prefab = RuntimeHelpers.GetUninitializedObject(prefabType);
        Field(prefabType, "Identifier").SetValue(prefab, Activator.CreateInstance(identifierType, id));
        object item = RuntimeHelpers.GetUninitializedObject(itemType);
        Field(itemType, "Prefab").SetValue(item, prefab);
        Field(itemType, "components").SetValue(item, Activator.CreateInstance(typeof(List<>).MakeGenericType(componentType)));
        return item;
    }
    object Loader(string id)
    {
        object element = Activator.CreateInstance(GameType("ContentXElement"), null, XElement.Parse("<DeepAmmoLoader />"))!;
        return Activator.CreateInstance(loaderType, Item(id), element)!;
    }
    void CheckPacket(string typeName, params object[] values)
    {
        var type = adapter.GetType(typeName, true)!;
        var packet = Activator.CreateInstance(type, values);
        var message = Activator.CreateInstance(GameType("Networking.ReadWriteMessage"))!;
        var serializer = GameType("INetSerializableStruct");
        serializer.GetMethod("Write")!.Invoke(packet, [message]);
        message.GetType().GetProperty("BitPosition")!.SetValue(message, 0);
        var decoded = serializer.GetMethod("Read")!.MakeGenericMethod(type).Invoke(null, [message]);
        Assert(Equals(packet, decoded), "Native packet round trip failed for " + typeName);
    }

    var onLoaded = itemType.GetMethods().Single(m => m.Name == "Load" && m.IsStatic);
    Type harmonyType = Assembly.Load("0Harmony").GetType("HarmonyLib.Harmony", true)!;
    string owner = adapter.FullName!;
    object harmony = Activator.CreateInstance(harmonyType, owner)!;
    bool Patched(MethodBase? method = null)
    {
        object? info = harmonyType.GetMethod("GetPatchInfo")!.Invoke(null, [method ?? onLoaded]);
        return info != null && ((IEnumerable)info.GetType().GetProperty("Owners")!.GetValue(info)!)
            .Cast<string>().Contains(owner);
    }
    try
    {
        if (target == "Client")
        {
            // OnContentLoaded also creates GPU textures. Exercise its assembly-wide Harmony registration headlessly.
            harmonyType.GetMethod("PatchAll", [typeof(Assembly)])!.Invoke(harmony, [adapter]);
            var actions = ((IEnumerable)Field(data.GetType(), "StatusEffectActions").GetValue(data)!).Cast<object>();
            Assert(actions.Select(x => (string)x.GetType().GetProperty("ElementName")!.GetValue(x)!).ToHashSet().SetEquals(
                ["DDA_NightVision_On", "DDA_NightVision_Off", "DDA_ALTYN_Open", "DDA_ALTYN_Origin", "DDA_MASKA_Open", "DDA_MASKA_Origin"]),
                "Incorrect native helmet action registrations.");
        }
        else
        {
            var spawner = GameType("EntitySpawner");
            var loop = spawner.GetMethod("ProcessAll", [typeof(bool)]) ?? spawner.GetMethod("Update", [typeof(bool)])!;
            Assert(Patched(loop), "Server queue budget patch was not installed.");
            var ilReader = harmonyType.Assembly.GetType("HarmonyLib.PatchProcessor")!.GetMethods()
                .Single(m => m.Name == "GetCurrentInstructions" && m.GetParameters()[1].ParameterType == typeof(int));
            var instructions = ((IEnumerable)ilReader.Invoke(null, [loop, int.MaxValue, null])!).Cast<object>();
            Assert(instructions.Any(i => i.GetType().GetField("operand")!.GetValue(i) is MethodInfo m &&
                m.DeclaringType?.Assembly == adapter && m.Name == "FilterQueueCount"), "Server queue lacks its budget gate.");
        }
        CheckPacket("ThermalVisablePatch.ThermalVisablePatch+ThermalState", (ushort)417, true);
        var impulseType = adapter.GetType("WeaponSyncFix.WeaponUseFeedback+Feedback", true)!.GetProperty("Impulse")!.PropertyType;
        CheckPacket("WeaponSyncFix.WeaponUseFeedback+Feedback", (ushort)517, (ushort)1, (ushort)42, ushort.MaxValue,
            3u, 0.017f, true, Activator.CreateInstance(impulseType, 1.5f, -0.125f)!, 5f);
        Assert(Patched(), "Saved-component migration was not installed.");
        MethodInfo[] inputMethods = target == "Client" ? [GameType("Inventory").GetMethod("UpdateDragging")!,
            GameType("Inventory").GetMethod("DrawFront")!, GameType("Inventory").GetMethod("DrawSlot")!,
            GameType("PlayerInput").GetMethod("Update")!] : [];
        Assert(inputMethods.All(method => Patched(method)), "Personal magazine input/drawing hooks were not installed.");
        if (target == "Client")
        {
            const BindingFlags hiddenStatic = BindingFlags.Static | BindingFlags.NonPublic;
            var settingsType = adapter.GetType("DeepDivingArmory.PluginSettings", true)!;
            var registeredSettings = (System.Collections.IDictionary)settingsType.GetField("registered", hiddenStatic)!.GetValue(null)!;
            Assert(registeredSettings.Contains("KillNotification") && registeredSettings.Contains("NVGColorMode") && registeredSettings.Contains("StopManualLoading"),
                "Config/PluginSettings.xml must register KillNotification, NVGColorMode, and StopManualLoading.");
            var colorSetting = registeredSettings["NVGColorMode"]!;
            Assert(colorSetting.GetType().GetProperty("Value")!.GetValue(colorSetting)!.ToString() == "Green",
                "Expected default Green NVGColorMode.");
            colorSetting.GetType().GetMethod("Load")!.Invoke(colorSetting, [XElement.Parse("<Setting value='Blue' />")]);
            Assert(colorSetting.GetType().GetProperty("Value")!.GetValue(colorSetting)!.ToString() == "Blue",
                "Saved NVGColorMode must be respected.");
            colorSetting.GetType().GetMethod("ResetToDefault")!.Invoke(colorSetting, null);
            Assert(colorSetting.GetType().GetProperty("Value")!.GetValue(colorSetting)!.ToString() == "Green",
                "Reset must restore Green NVGColorMode.");

            var manualType = adapter.GetType("DDA.AmmoLoading.ManualMagazineLoading", true)!;
            var binding = manualType.GetProperty("StopKey", hiddenStatic)!;
            var setting = registeredSettings["StopManualLoading"]!;
            Assert(setting.GetType().Assembly == adapter, "StopManualLoading must be owned by DDA, not VCE.");
            Assert(binding.GetValue(null)!.ToString() == "Escape", "Expected default Escape binding.");
            setting.GetType().GetMethod("Load")!.Invoke(setting, [XElement.Parse("<Setting value='K' />")]);
            Assert(binding.GetValue(null)!.ToString() == "K", "Saved key binding must be respected.");
            var saved = new XElement("Setting");
            setting.GetType().GetMethod("Save")!.Invoke(setting, [saved]);
            Assert(saved.Attribute("value")?.Value == "K", "Saved XML attribute must use value='K'.");
            setting.GetType().GetMethod("ResetToDefault")!.Invoke(setting, null);
            Assert(binding.GetValue(null)!.ToString() == "Escape", "Reset must restore Escape.");
        }
        var existing = Loader("deep_new_ammoloader");
        Assert(loaderType.GetProperty("Target")!.PropertyType == vce.GetType("VCE_VirtualizedMagazine.VirtualizedMagazine", true),
            "DeepAmmoLoader must use the already-loaded native VCE type.");
        Assert(!AssemblyLoadContext.GetLoadContext(adapter)!.Assemblies.Any(a => a.GetName().Name!.StartsWith("VanillaComponentsExpanded")),
            "The DDA context must not load a second copy of VCE.");
        Assert(supply.GetValue(existing) != null, "DDA supply must be available when the component is constructed.");
        Assert(loaderType.Assembly == adapter && loaderType.BaseType == componentType,
            "DeepAmmoLoader must own its implementation, not inherit VCE's loader.");
        Assert(loaderType.GetMethod(target == "Client" ? "ClientEventRead" : "ServerEventRead") != null,
            "Missing target-specific network handler.");
        var resolver = (Delegate)supply.GetValue(existing)!;
        var expected = new Dictionary<string, string>
        {
            ["deep_ammobox_lead"] = "556x45round", ["deep_ammobox_titanium"] = "556x45round_tit",
            ["deep_ammobox_physicorium"] = "556x45round_phy", ["deep_ammobox_fulgurium_physicorium"] = "556x45round_m995",
            ["deep_ammobox_tungsten_physicorium"] = "556x45round_ssa_ap", ["deep_ammobox_depleted_uranium"] = "556x45round_depleted_uranium"
        };
        foreach (var entry in expected)
        {
            object definition = resolver.DynamicInvoke(Item(entry.Key))!;
            Assert(definition != null, "Missing source: " + entry.Key);
            Assert((string)definition!.GetType().GetProperty("PoolId")!.GetValue(definition)! == "dda." + entry.Key, "Wrong supply pool.");
            var costs = (IReadOnlyDictionary<string, double>)definition.GetType().GetProperty("Costs")!.GetValue(definition)!;
            Assert(costs.TryGetValue(entry.Value, out double cost) && Math.Abs(cost * 30 - 1.5625) < 1e-12,
                "Wrong projectile/cost for " + entry.Key);
        }
        Assert(resolver.DynamicInvoke(Item("deep_ammobox_copper")) == null, "Copper has no active RIP projectile.");
        Assert(resolver.DynamicInvoke(Item("unrelated")) == null, "Unrelated sources must remain unmapped.");
        var migrate = pluginType.GetMethod("MigrateSavedComponent", BindingFlags.Static | BindingFlags.NonPublic)!;
        foreach (string id in new[] { "deep_new_ammoloader", "other_ammoloader" })
        {
            var saved = XElement.Parse($"<Item identifier='{id}'><AmmoLoader><Stock><Ammo id='unknown_mod_round' count='17' /></Stock></AmmoLoader><ItemContainer /></Item>");
            string stock = saved.Element("AmmoLoader")!.Element("Stock")!.ToString();
            object element = Activator.CreateInstance(GameType("ContentXElement"), null, saved)!;
            migrate.Invoke(null, [element]);
            string name = id == "deep_new_ammoloader" ? "DeepAmmoLoader" : "AmmoLoader";
            Assert(saved.Element(name)?.Element("Stock")?.ToString() == stock && saved.Element("ItemContainer") != null,
                "Component rename must preserve stock and leave other machines untouched.");
            migrate.Invoke(null, [element]);
            Assert(saved.Elements(name).Count() == 1, "Migration must be idempotent.");
        }
        object savedComponent = Activator.CreateInstance(GameType("ContentXElement"), null,
            XElement.Parse("<DeepAmmoLoader><Stock><Ammo id='unknown_mod_round' count='17' /></Stock></DeepAmmoLoader>"))!;
        loaderType.GetMethod("Load", [GameType("ContentXElement"), typeof(bool), GameType("IdRemap"), typeof(bool)])!
            .Invoke(existing, [savedComponent, false, null, false]);
        object restoredStock = loaderType.GetProperty("Stock")!.GetValue(existing)!;
        Assert((int)restoredStock.GetType().GetProperty("Item")!.GetValue(restoredStock, ["unknown_mod_round"])! == 17,
            "Migrated stock must load into DDA's component without losing unknown ammunition.");
        var roundTrip = (XElement)loaderType.GetMethod("Save")!.Invoke(existing, [new XElement("Item")])!;
        Assert(roundTrip.Name == "DeepAmmoLoader" && roundTrip.Element("Stock")!.Element("Ammo")!.Attribute("count")!.Value == "17",
            "Saving must keep migrated stock under the new component name.");
        ValidateXml(dda, expected);
        var prefabRegistry = prefabType.GetField("Prefabs")!.GetValue(null)!;
        var addPrefab = prefabRegistry.GetType().GetMethod("Add", [prefabType, typeof(bool)])!;
        var removePrefab = prefabRegistry.GetType().GetMethod("Remove", [prefabType])!;
        var registered = new List<object>();
        object Register(XElement xml)
        {
            object prefab = RuntimeHelpers.GetUninitializedObject(prefabType);
            Field(prefabType, "Identifier").SetValue(prefab, Activator.CreateInstance(identifierType, (string)xml.Attribute("identifier")!));
            prefabType.GetProperty("ConfigElement")!.SetValue(prefab, Activator.CreateInstance(GameType("ContentXElement"), null, xml));
            prefabType.GetProperty("Health")!.SetValue(prefab, (float?)xml.Attribute("health") ?? 100f);
            addPrefab.Invoke(prefabRegistry, [prefab, false]);
            registered.Add(prefab);
            return prefab;
        }
        try
        {
            var projectiles = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoRound/5.56x45.xml")).Root!.Elements("Item")
                .ToDictionary(x => (string)x.Attribute("identifier")!, StringComparer.OrdinalIgnoreCase);
            foreach (var package in XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml")).Root!.Elements("Item"))
            {
                string ammo = (string)package.Element("VirtualizedAmmoStorage")!.Attribute("ProjectileIdentifier")!;
                Register(projectiles[ammo]);
                object prefab = Register(package);
                Assert(ReferenceEquals(loaderType.GetMethod("FindWithdrawalPackage")!.Invoke(null, [ammo]), prefab),
                    "Native component lookup failed for XML-defined package: " + package.Attribute("identifier")!.Value);
            }
        }
        finally { foreach (object prefab in registered) { removePrefab.Invoke(prefabRegistry, [prefab]); } }
        Unload();
        Assert(!Patched(), "Unload must remove the migration hook.");
        Assert(inputMethods.All(method => !Patched(method)), "Unload must remove the personal magazine input/drawing hooks.");
        Console.WriteLine($"PASS ({target}): isolated native VCE resolution, DDA-owned loader, network handler, six supply sources, six native package lookups, saved-stock rename, unload and XML registration.");
    }
    finally
    {
        while (packages.Count > 0) { Unload(); }
        items.Clear();
    }
}

static void ValidateXml(string dda, Dictionary<string, string> expected)
{
    var machine = XDocument.Load(Path.Combine(dda, "machine/machine.xml")).Descendants("Item")
        .Single(item => (string?)item.Attribute("identifier") == "deep_new_ammoloader");
    var component = machine.Descendants("DeepAmmoLoader").Single();
    var magazines = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewMag/NewMag.xml")).Root!.Elements("Item").ToArray();
    Assert(magazines.Length > 0 && magazines.All(m => m.Element("VirtualizedMagazine") != null &&
        m.Elements("ManualMagazineLoading").Count() == 1 && m.Elements().Last().Name == "ManualMagazineLoading"),
        "All virtual magazines must append manual loading without shifting saved component indices.");
    var pressClips = XDocument.Load(Path.Combine(dda, "music/music.xml")).Root!.Elements("dda_manual_press")
        .Select(e => ((string)e.Attribute("file")!).Replace("%ModDir%/", "")).ToArray();
    Assert(pressClips.Length == 4 && pressClips.Distinct().Count() == 4 &&
        pressClips.All(path => File.Exists(Path.Combine(dda, path))),
        "Manual loading must register four distinct press clips that ship with the mod.");
    Assert((string?)component.Attribute("usesupplystorage") == "true" &&
        (string?)component.Attribute("textprefix") == "dda.ammoloader." &&
        (string?)component.Attribute("targetcontainerindex") == "2" && (string?)component.Attribute("outputcontainerindex") == "1",
        "DDA must enable refillable supplies and its own text prefix with a separate pickup container.");
    var containers = machine.Descendants("ItemContainer").ToArray();
    Assert(containers.Length == 3 && (string?)containers[0].Attribute("capacity") == "6" &&
        (string?)containers[0].Attribute("slotsperrow") == "6" && (string?)containers[1].Attribute("capacity") == "6" && (string?)containers[2].Attribute("capacity") == "1",
        "DDA intake spacing or pickup capacity changed unexpectedly.");
    Assert(machine.Descendants("ItemContainer").First().Element("Containable")!.Attribute("items")!.Value.Split(',').Contains("deep_ammobox"),
        "Intake must accept ammo boxes.");
    var projectiles = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoRound/5.56x45.xml")).Root!.Elements("Item")
        .ToDictionary(x => x.Attribute("identifier")!.Value, StringComparer.OrdinalIgnoreCase);
    var boxes = XDocument.Load(Path.Combine(dda, "weapon/ammo/ammobox.xml")).Root!.Elements("Item")
        .ToDictionary(x => x.Attribute("identifier")!.Value, StringComparer.OrdinalIgnoreCase);
    var packages = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml")).Root!.Elements("Item").ToArray();
    Assert(packages.Length == expected.Count, "Expected one package per implemented projectile.");
    foreach (var entry in expected)
    {
        Assert(projectiles[entry.Value].Element("Projectile") != null && projectiles[entry.Value].Attribute("tags")!.Value.Split(',').Contains("deep_556x45_round"), "Incompatible projectile.");
        Assert(boxes[entry.Key].Attributes().Single(a => a.Name.LocalName.Equals("tags", StringComparison.OrdinalIgnoreCase))
            .Value.Split(',').Contains("deep_ammobox"), "Source rejected by intake.");
        var package = packages.Single(p => string.Equals((string?)p.Element("VirtualizedAmmoStorage")?.Attribute("ProjectileIdentifier"),
            entry.Value, StringComparison.OrdinalIgnoreCase));
        Assert((int?)package.Attribute("health") == 180, $"The {entry.Value} package must hold 180 rounds.");
        Assert(!package.Descendants("Fabricate").Any() && !projectiles[entry.Value].Descendants("Fabricate").Any(),
            $"Neither {entry.Value} nor its package should have a crafting recipe.");
        var packageIcon = package.Element("InventoryIcon") ?? package.Element("Sprite")!;
        var roundIcon = projectiles[entry.Value].Element("InventoryIcon") ?? projectiles[entry.Value].Element("Sprite")!;
        Assert((string?)packageIcon.Attribute("texture") == (string?)roundIcon.Attribute("texture") &&
            packageIcon.Attribute("sourcerect")!.Value.Split(',').Take(3)
                .SequenceEqual(roundIcon.Attribute("sourcerect")!.Value.Split(',').Take(3)),
            "Package and round icons must show the same variant in the atlas.");
    }
    Assert(XDocument.Load(Path.Combine(dda, "filelist.xml")).Descendants("Item")
        .Count(x => (string?)x.Attribute("file") == "%ModDir%/weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml") == 1, "Package file is not registered exactly once.");
    foreach (string language in new[] { "chinese", "English" })
    {
        var texts = XDocument.Load(Path.Combine(dda, "text", language + ".xml")).Root!.Elements().ToArray();
        Assert(texts.Count(t => t.Name.LocalName == "dda.ammoloader.intake") == 1 &&
            texts.Single(t => t.Name.LocalName == "dda.ammoloader.intake").Value == (language == "chinese" ? "放置弹药箱/弹药包" : "Insert ammo boxes or packages"),
            "The DDA intake label must live in DDA's localization.");
        foreach (var package in packages)
        { Assert(texts.Count(t => t.Name.LocalName == "entityname." + package.Attribute("identifier")!.Value) == 1, "Missing package name."); }
    }
    var registrations = XDocument.Load(Path.Combine(dda, "PluginInfo.xml")).Descendants("MainAssemblyInfo").ToArray();
    Assert(registrations.Length == 6, "Expected six binary registrations.");
    foreach (var target in new[] { "Client", "Server" })
    foreach (var platform in new[] { "Windows", "Linux", "Mac" })
    {
        string relative = $"bin/{platform}/{target}/Deep-Diving-Armory{target}.dll";
        Assert(registrations.Count(x => x.Attribute("assemblypath")!.Value == "%ModDir%/" + relative &&
            x.Attribute("targets")?.Value == target && x.Attribute("platforms")?.Value == platform && x.Attribute("IsScript") == null) == 1,
            "Incorrect binary registration: " + relative);
        Assert(File.Exists(Path.Combine(dda, relative)) && File.Exists(Path.Combine(dda, Path.ChangeExtension(relative, ".deps.json"))), "Missing deployed output.");
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
