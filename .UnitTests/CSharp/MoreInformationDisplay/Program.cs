using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using Barotrauma;
using Barotrauma.Items.Components;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using MoreInformationDisplay;

// Offline fixtures against the local LuaCs reference assemblies, without game/UI startup.
if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: MoreInformationDisplay.Tests <Unstable game directory>");
    Environment.ExitCode = 2;
    return;
}
string gameDirectory = Path.GetFullPath(args[0]);
AssemblyLoadContext.Default.Resolving += (context, name) =>
{
    string path = Path.Combine(gameDirectory, name.Name + ".dll");
    return File.Exists(path) ? context.LoadFromAssemblyPath(path) : null;
};
var magazine = (VCE_VirtualizedMagazine.VirtualizedMagazine)RuntimeHelpers.GetUninitializedObject(typeof(VCE_VirtualizedMagazine.VirtualizedMagazine));
var item = (Item)RuntimeHelpers.GetUninitializedObject(typeof(Item));
Set(item, "tags", new HashSet<Identifier> { new("556mag") });
var components = new List<ItemComponent> { magazine };
Set(item, "components", components);
var cache = (IDictionary)Activator.CreateInstance(Field(typeof(Item), "componentsByType").FieldType);
cache[typeof(ItemContainer)] = components;
Set(item, "componentsByType", cache);
Set(magazine, "item", item);
var scriptState = CompileScriptState();

magazine.Load("test_standard", "test_ap", "test_standard");
int before = scriptState(item);
string text = VirtualMagazineTooltip.Describe(item);
Assert(text.Contains("3/30") && text.Contains("test_standard × 2") && text.Contains("test_ap × 1"), "wrong count or composition");
Assert(text.Split('\n')[1].EndsWith("test_standard"), "wrong next round");
Assert(magazine.LoadedCount == 3 && before == scriptState(item), "tooltip mutated ammo");
magazine.Load("test_ap", "test_standard", "test_standard");
Assert(before != scriptState(item), "same-count/same-top reorder did not invalidate tooltip");

magazine.Load();
text = VirtualMagazineTooltip.Describe(item);
Assert(text.Contains("0/30") && !text.Contains("×"), "empty magazine retained old contents");
Assert(scriptState(null) == 0 && VirtualMagazineTooltip.Describe(null) == "", "null item handling");
Set(item, "tags", new HashSet<Identifier>());
// No prefab is needed when the native HasTag lookup is short-circuited by the positive tag above.
// For the out-of-scope case use a real prefab fixture so the fallback tag lookup is valid.
var prefab = (ItemPrefab)RuntimeHelpers.GetUninitializedObject(typeof(ItemPrefab));
Set(prefab, "tags", System.Collections.Immutable.ImmutableHashSet<Identifier>.Empty);
Set(item, "Prefab", prefab);
Assert(VirtualMagazineTooltip.Describe(item) == "", "non-5.56 item was changed");
Console.WriteLine("ok: LuaCs-style script compilation and execution; contents, next round, empty state and same-count refresh pass");

static Func<Item, int> CompileScriptState()
{
    // LuaCs AssemblyLoader exposes private overloads to Roslyn, but CLR access checks still apply.
    var options = new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary,
        optimizationLevel: OptimizationLevel.Release, metadataImportOptions: MetadataImportOptions.All);
    typeof(CSharpCompilationOptions).GetProperty("TopLevelBinderFlags", BindingFlags.Instance | BindingFlags.NonPublic)
        .SetValue(options, 37748738u);
    var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")).Split(Path.PathSeparator)
        .Select(path => MetadataReference.CreateFromFile(path));
    var source = "global using System; global using System.Collections.Generic; global using System.Linq; "
        + "global using Barotrauma.LuaCs; global using Barotrauma.Extensions;\n"
        + File.ReadAllText("CSharp/MoreInformationDisplay.cs");
    var compilation = CSharpCompilation.Create("TooltipScriptRegression",
        new[] { CSharpSyntaxTree.ParseText(source) }, references, options);
    using var stream = new MemoryStream();
    var result = compilation.Emit(stream);
    Assert(result.Success, string.Join("\n", result.Diagnostics));
    stream.Position = 0;
    return AssemblyLoadContext.Default.LoadFromStream(stream).GetType("MoreInformationDisplay.VirtualMagazineTooltip")
        .GetMethod("State", BindingFlags.Static | BindingFlags.NonPublic).CreateDelegate<Func<Item, int>>();
}

static FieldInfo Field(Type type, string name)
{
    for (; type != null; type = type.BaseType)
    {
        var field = type.GetField(name, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
        if (field != null) return field;
    }
    throw new MissingFieldException(name);
}
static void Set(object target, string name, object value) => Field(target.GetType(), name).SetValue(target, value);
static void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }

namespace VCE_VirtualizedMagazine
{
    public class VirtualizedMagazine : ItemContainer
    {
        public Stack<Identifier> LoadedAmmoIdentifiers { get; set; }
        public int LoadedCount => LoadedAmmoIdentifiers.Count;
        public int MaxSize => 30;
        public Identifier TopIdentifier => LoadedAmmoIdentifiers.TryPeek(out var id) ? id : default;
        public VirtualizedMagazine(Item item, ContentXElement element) : base(item, element) { }
        public void Load(params string[] ammo) => LoadedAmmoIdentifiers = new(ammo.Select(id => new Identifier(id)));
    }
}
