using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using Barotrauma;
using Barotrauma.Items.Components;
using MoreInformationDisplay;

// Offline fixtures against the local LuaCs reference assemblies, without game/UI startup.
var magazine = (VCE_VirtualizedMagazine.VirtualizedMagazine)RuntimeHelpers.GetUninitializedObject(typeof(VCE_VirtualizedMagazine.VirtualizedMagazine));
var item = (Item)RuntimeHelpers.GetUninitializedObject(typeof(Item));
Set(item, "tags", new HashSet<Identifier> { new("556mag") });
var components = new List<ItemComponent> { magazine };
Set(item, "components", components);
var cache = (IDictionary)Activator.CreateInstance(Field(typeof(Item), "componentsByType").FieldType);
cache[typeof(ItemContainer)] = components;
Set(item, "componentsByType", cache);
Set(magazine, "item", item);

magazine.Load("test_standard", "test_ap", "test_standard");
int before = VirtualMagazineTooltip.State(item);
string text = VirtualMagazineTooltip.Describe(item);
Assert(text.Contains("3/30") && text.Contains("test_standard × 2") && text.Contains("test_ap × 1"), "wrong count or composition");
Assert(text.Split('\n')[1].EndsWith("test_standard"), "wrong next round");
Assert(magazine.LoadedCount == 3 && before == VirtualMagazineTooltip.State(item), "tooltip mutated ammo");
magazine.Load("test_ap", "test_standard", "test_standard");
Assert(before != VirtualMagazineTooltip.State(item), "same-count/same-top reorder did not invalidate tooltip");

magazine.Load();
text = VirtualMagazineTooltip.Describe(item);
Assert(text.Contains("0/30") && !text.Contains("×"), "empty magazine retained old contents");
Assert(VirtualMagazineTooltip.State(null) == 0 && VirtualMagazineTooltip.Describe(null) == "", "null item handling");
Set(item, "tags", new HashSet<Identifier>());
// No prefab is needed when the native HasTag lookup is short-circuited by the positive tag above.
// For the out-of-scope case use a real prefab fixture so the fallback tag lookup is valid.
var prefab = (ItemPrefab)RuntimeHelpers.GetUninitializedObject(typeof(ItemPrefab));
Set(prefab, "tags", System.Collections.Immutable.ImmutableHashSet<Identifier>.Empty);
Set(item, "Prefab", prefab);
Assert(VirtualMagazineTooltip.Describe(item) == "", "non-5.56 item was changed");
Console.WriteLine("ok: actual tooltip source compiles; contents, next round, empty state and same-count refresh pass (offline references)");

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
