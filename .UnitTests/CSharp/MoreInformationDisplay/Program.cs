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
Assert(text.StartsWith("余弹: 3/30\n下一发: ") && text.Contains("\n弹种组成: "), "tooltip labels require removed localization keys");
Assert(magazine.LoadedCount == 3 && before == scriptState(item), "tooltip mutated ammo");
magazine.Load("test_ap", "test_standard", "test_standard");
Assert(before != scriptState(item), "same-count/same-top reorder did not invalidate tooltip");

magazine.Load();
text = VirtualMagazineTooltip.Describe(item);
Assert(text.Contains("0/30") && !text.Contains("×"), "empty magazine retained old contents");
Assert(text.EndsWith("下一发: 空匣"), "empty magazine requires a removed localization key");
Assert(scriptState(null) == 0 && VirtualMagazineTooltip.Describe(null) == "", "null item handling");
Set(item, "tags", new HashSet<Identifier>());
// No prefab is needed when the native HasTag lookup is short-circuited by the positive tag above.
// For the out-of-scope case use a real prefab fixture so the fallback tag lookup is valid.
var prefab = (ItemPrefab)RuntimeHelpers.GetUninitializedObject(typeof(ItemPrefab));
Set(prefab, "tags", System.Collections.Immutable.ImmutableHashSet<Identifier>.Empty);
Set(item, "Prefab", prefab);
Assert(VirtualMagazineTooltip.Describe(item) == "", "non-5.56 item was changed");
Console.WriteLine("ok: LuaCs-style script compilation and execution; contents, next round, empty state and same-count refresh pass");

// Prefab-backed virtual ammunition uses the same Shift detail patch without spawning an Item.
Set(prefab, "name", (LocalizedString)"Test cartridge");
Set(prefab, "wearableDamageModifiers", Array.Empty<DamageModifier>());
Set(prefab, "wearableSkillModifiers", new Dictionary<Identifier, float>());
typeof(ItemPrefab).GetProperty(nameof(ItemPrefab.Description)).SetValue(prefab, (LocalizedString)"Base description");
typeof(ItemPrefab).GetProperty(nameof(ItemPrefab.ConfigElement)).SetValue(prefab, new ContentXElement(null,
    System.Xml.Linq.XElement.Parse("<Item><Projectile hitscancount='4' MaxTargetsToHit='3' friendlyfire='false'><Attack penetration='0.6' structuredamage='12' itemdamage='8' /></Projectile></Item>")));
const BindingFlags staticFields = BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public;
var headlessGame = (GameMain)RuntimeHelpers.GetUninitializedObject(typeof(GameMain));
var platformType = typeof(Microsoft.Xna.Framework.Game).Assembly.GetType("Microsoft.Xna.Framework.SdlGamePlatform");
var platform = RuntimeHelpers.GetUninitializedObject(platformType);
GC.SuppressFinalize(headlessGame);
GC.SuppressFinalize(platform);
Set(platform, "_isActive", true);
Set(headlessGame, "Platform", platform);
typeof(GameMain).GetProperty(nameof(GameMain.Instance)).SetValue(null, headlessGame);
typeof(PlayerInput).GetField("allowInput", staticFields).SetValue(null, true);
var keyboard = typeof(PlayerInput).GetField("keyboardState", staticFields);
var prefabPostfix = scriptState.Method.DeclaringType.Assembly.GetType("MoreInformationDisplay.Patch_PrefabAmmoTooltip")
    .GetMethod("Postfix", staticFields);
string PrefabTooltip()
{
    object[] arguments = { prefab, prefab.GetTooltip(null) };
    prefabPostfix.Invoke(null, arguments);
    return ((LocalizedString)arguments[1]).Value;
}
try
{
    foreach (var key in new Microsoft.Xna.Framework.Input.Keys?[]
        { null, Microsoft.Xna.Framework.Input.Keys.LeftShift, null, Microsoft.Xna.Framework.Input.Keys.RightShift, null })
    {
        keyboard.SetValue(null, key.HasValue ? new Microsoft.Xna.Framework.Input.KeyboardState(key.Value) : new Microsoft.Xna.Framework.Input.KeyboardState());
        string tip = PrefabTooltip();
        Assert(tip.Contains("Base description"), "prefab details lost the original description");
        Assert(tip.Contains("穿甲:") == key.HasValue && tip.Contains("射弹数:4") == key.HasValue &&
            tip.Contains("可穿透友军") == key.HasValue, "prefab ammo details did not follow both Shift keys and release");
    }
    keyboard.SetValue(null, new Microsoft.Xna.Framework.Input.KeyboardState(Microsoft.Xna.Framework.Input.Keys.LeftShift));
    typeof(ItemPrefab).GetProperty(nameof(ItemPrefab.ConfigElement)).SetValue(prefab, new ContentXElement(null, new System.Xml.Linq.XElement("Item")));
    Assert(!PrefabTooltip().Contains("穿甲:"), "non-projectile prefab received ammo details");
}
finally
{
    keyboard.SetValue(null, new Microsoft.Xna.Framework.Input.KeyboardState());
    typeof(PlayerInput).GetField("allowInput", staticFields).SetValue(null, false);
    typeof(GameMain).GetProperty(nameof(GameMain.Instance)).SetValue(null, null);
}
Console.WriteLine("ok: LuaCs-compiled prefab tooltip postfix preserves base text, expands on either Shift key, collapses on release, and ignores non-projectiles");

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
