using System.Collections;
using System.Linq.Expressions;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using System.Xml.Linq;

// Uses deployed assemblies without starting the game; no rendering, physics or network session.
if (args.Length is < 4 or > 5 || args.Length == 5 && args[4] is not ("Client" or "Server"))
{
    Console.Error.WriteLine("Usage: AmmoLoaderSupply.Tests <game directory> <VCE directory> <DDA directory> <LuaCs plugin directory> [Client|Server]");
    return 2;
}
try { Run(args); return 0; }
catch (Exception error) { Console.Error.WriteLine(error); return 1; }

static void Run(string[] args)
{
    string platform = OperatingSystem.IsWindows() ? "Windows" : OperatingSystem.IsMacOS() ? "Mac" : "Linux";
    string target = args.Length == 5 ? args[4] : "Client";
    string dda = Path.GetFullPath(args[2]);
    string[] directories = [Path.GetFullPath(args[0]), Path.Combine(Path.GetFullPath(args[1]), "bin", platform, target),
        Path.Combine(dda, "bin", target, platform == "Mac" ? "OSX" : platform),
        Path.Combine(Path.GetFullPath(args[3]), platform, target)];
    AssemblyLoadContext.Default.Resolving += (context, name) =>
    {
        foreach (string directory in directories)
        {
            string path = Path.Combine(directory, name.Name + ".dll");
            if (File.Exists(path)) return context.LoadFromAssemblyPath(path);
        }
        return null;
    };
    Assembly game = Assembly.Load(target == "Client" ? "Barotrauma" : "DedicatedServer"), core = Assembly.Load("BarotraumaCore");
    Assembly vce = Assembly.Load("VanillaComponentsExpanded" + target);
    Assembly adapter = Assembly.Load("AmmoLoaderSupply");
    Type GameType(string name) => game.GetType("Barotrauma." + name) ?? core.GetType("Barotrauma." + name, true)!;
    Type itemType = GameType("Item"), prefabType = GameType("ItemPrefab"), identifierType = GameType("Identifier");
    Type componentType = GameType("Items.Components.ItemComponent");
    Type loaderType = vce.GetType("VCE.AmmoLoading.AmmoLoader", true)!;
    Type pluginType = adapter.GetType("DdaAmmoSupply.Plugin", true)!;
    PropertyInfo supply = loaderType.GetProperty("SupplyResolver")!;
    object plugin = Activator.CreateInstance(pluginType)!;
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
        object item = Item(id), loader = RuntimeHelpers.GetUninitializedObject(loaderType);
        Field(componentType, "item").SetValue(loader, item);
        ((IList)Field(itemType, "components").GetValue(item)!).Add(loader);
        items.Add(item);
        return loader;
    }
    var existing = Loader("deep_new_ammoloader");
    var unrelated = Loader("other_ammoloader");
    var attach = pluginType.GetMethod("Attach", BindingFlags.Static | BindingFlags.NonPublic)!;
    var onLoaded = loaderType.GetMethod("OnItemLoaded")!;
    Type harmonyType = Assembly.Load("0Harmony").GetType("HarmonyLib.Harmony", true)!;
    bool Patched()
    {
        object? info = harmonyType.GetMethod("GetPatchInfo")!.Invoke(null, [onLoaded]);
        return info != null && ((IEnumerable)info.GetType().GetProperty("Owners")!.GetValue(info)!)
            .Cast<string>().Contains("deepdivingarmory.ammoloadersupply");
    }
    try
    {
        pluginType.GetMethod("OnLoadCompleted")!.Invoke(plugin, null);
        Assert(Patched(), "New-machine lifecycle hook was not installed.");
        Assert(supply.GetValue(existing) != null && supply.GetValue(unrelated) == null, "Existing-machine binding scope is wrong.");
        var created = Loader("deep_new_ammoloader");
        attach.Invoke(null, [created]);
        Assert(supply.GetValue(created) != null, "New DDA machine was not attached.");
        var resolver = (Delegate)supply.GetValue(existing)!;
        var expected = new Dictionary<string, string>
        {
            ["ammobox1"] = "5.56x45round", ["ammobox_7.62"] = "5.56x45round_tit",
            ["ammobox_12.7"] = "5.56x45round_phy", ["ammobox_phy_ful"] = "556x45round_m995",
            ["ammobox_tun_ful"] = "556x45round_ssa_ap", ["ammobox_du"] = "556x45round_depleted_uranium"
        };
        foreach (var entry in expected)
        {
            object definition = resolver.DynamicInvoke(Item(entry.Key))!;
            Assert(definition != null, "Missing source: " + entry.Key);
            Assert((string)definition!.GetType().GetProperty("PoolId")!.GetValue(definition)! == "dda." + entry.Key, "Wrong supply pool.");
            var costs = (IReadOnlyDictionary<string, double>)definition.GetType().GetProperty("Costs")!.GetValue(definition)!;
            Assert(costs.Count == 1 && costs.TryGetValue(entry.Value, out double cost) && Math.Abs(cost * 30 - 1.5625) < 1e-12,
                "Wrong projectile/cost for " + entry.Key);
        }
        Assert(resolver.DynamicInvoke(Item("ammobox_rip")) == null && resolver.DynamicInvoke(Item("unrelated")) == null,
            "Unfinished or unrelated sources must remain unmapped.");
        var parameter = Expression.Parameter(itemType);
        var external = Expression.Lambda(supply.PropertyType, Expression.Default(supply.PropertyType.GetGenericArguments()[1]), parameter).Compile();
        supply.SetValue(created, external);
        attach.Invoke(null, [created]);
        Assert(ReferenceEquals(supply.GetValue(created), external), "Another provider was overwritten.");
        ValidateXml(dda, expected);
        pluginType.GetMethod("Dispose")!.Invoke(plugin, null);
        Assert(!Patched() && supply.GetValue(existing) == null && ReferenceEquals(supply.GetValue(created), external),
            "Unload must remove only this plugin's hook and bindings.");
        Console.WriteLine($"PASS ({target}): actual DDA DLL, VCE API binding, six costs/mappings, existing/new machines, unrelated provider preservation, unload and XML registration.");
    }
    finally
    {
        pluginType.GetMethod("Dispose")!.Invoke(plugin, null);
        items.Clear();
    }
}

static void ValidateXml(string dda, Dictionary<string, string> expected)
{
    var machine = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoLoader/NewAmmoLoader.xml"));
    var component = machine.Descendants("AmmoLoader").Single();
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
    var projectiles = XDocument.Load(Path.Combine(dda, "weapon/rifle/rifle_round.xml")).Root!.Elements("Item")
        .ToDictionary(x => x.Attribute("identifier")!.Value, StringComparer.OrdinalIgnoreCase);
    var boxes = XDocument.Load(Path.Combine(dda, "weapon/ammo/ammobox.xml")).Root!.Elements("Item")
        .ToDictionary(x => x.Attribute("identifier")!.Value, StringComparer.OrdinalIgnoreCase);
    var packages = XDocument.Load(Path.Combine(dda, "weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml")).Root!.Elements("Item").ToArray();
    Assert(packages.Length == expected.Count, "Expected one package per implemented projectile.");
    foreach (var entry in expected)
    {
        Assert(projectiles[entry.Value].Element("Projectile") != null && projectiles[entry.Value].Attribute("tags")!.Value.Split(',').Contains("deep_556_round"), "Incompatible projectile.");
        Assert(boxes[entry.Key].Attributes().Single(a => a.Name.LocalName.Equals("tags", StringComparison.OrdinalIgnoreCase))
            .Value.Split(',').Contains("deep_ammobox"), "Source rejected by intake.");
        var package = packages.Single(p => string.Equals((string?)p.Element("VirtualizedAmmoStorage")?.Attribute("ProjectileIdentifier"),
            entry.Value, StringComparison.OrdinalIgnoreCase));
        Assert((string?)package.Attribute("health") == "30" && package.Attribute("tags")!.Value.Split(',').Contains("vceammopackage") &&
            !package.Descendants("Fabricate").Any() && !projectiles[entry.Value].Descendants("Fabricate").Any(),
            "New ammunition and its 30-round package must not have crafting recipes.");
        foreach (string attribute in new[] { "texture", "sourcerect" })
        {
            Assert((string?)package.Element("InventoryIcon")!.Attribute(attribute) == (string?)projectiles[entry.Value].Element("InventoryIcon")!.Attribute(attribute),
                "Packages must reuse their projectile's existing icon.");
        }
    }
    Assert(XDocument.Load(Path.Combine(dda, "filelist.xml")).Descendants("Item")
        .Count(x => (string?)x.Attribute("file") == "%ModDir%/weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml") == 1, "Package file is not registered exactly once.");
    foreach (string language in new[] { "chinese", "English" })
    {
        var texts = XDocument.Load(Path.Combine(dda, "text", language + ".xml")).Root!.Elements().ToArray();
        Assert(texts.Count(t => t.Name.LocalName == "dda.ammoloader.intake") == 1 &&
            texts.Single(t => t.Name.LocalName == "dda.ammoloader.intake").Value == (language == "chinese" ? "放置弹药箱/弹药包" : "Place ammo boxes/packages"),
            "The DDA intake label must live in DDA's localization.");
        foreach (var package in packages)
        { Assert(texts.Count(t => t.Name.LocalName == "entityname." + package.Attribute("identifier")!.Value) == 1, "Missing package name."); }
    }
    var registrations = XDocument.Load(Path.Combine(dda, "ModConfig.xml")).Descendants("Assembly")
        .Where(x => x.Attribute("File")!.Value.Contains("AmmoLoaderSupply")).ToArray();
    Assert(registrations.Length == 6, "Expected six binary registrations.");
    foreach (var target in new[] { "Client", "Server" })
    foreach (var platform in new[] { "Windows", "Linux", "OSX" })
    {
        string relative = $"bin/{target}/{platform}/AmmoLoaderSupply.dll";
        Assert(registrations.Count(x => x.Attribute("File")!.Value == "%ModDir%/" + relative &&
            x.Attribute("Target")?.Value == target && x.Attribute("Platform")?.Value == platform && x.Attribute("IsScript") == null) == 1,
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
