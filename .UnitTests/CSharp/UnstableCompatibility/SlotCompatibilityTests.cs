using Xunit;
using System.Reflection;
using System.Text.RegularExpressions;

public class SlotCompatibilityTests
{
    [Fact]
    public void CustomSlotsDoNotOverlapVanillaEquipmentOrProsthetics()
    {
        foreach (var slot in Enum.GetValues<InvSlotType>())
        {
            Assert.False(DeepSlotExpanded.SlotRegistry.IsValidBit((int)slot));
        }
        Assert.True(DeepSlotExpanded.SlotRegistry.IsValidBit(16384));
        Assert.True(DeepSlotExpanded.SlotRegistry.IsValidBit(1 << 24));
        Assert.True(DeepSlotExpanded.SlotRegistry.IsValidBit(1 << 25));
        Assert.True(DeepSlotExpanded.SlotRegistry.IsValidBit(1 << 26));
        Assert.False(DeepSlotExpanded.SlotRegistry.IsValidBit(16384 | 32768));
    }

    [Fact]
    public void MigratedLuaHooksResolveAgainstTheGameAssembly()
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root != null && !File.Exists(Path.Combine(root.FullName, "ModConfig.xml")))
        {
            root = root.Parent;
        }
        Assert.NotNull(root);
        var init = File.ReadAllText(Path.Combine(root.FullName, "Lua/Autorun/init.lua"));
        var methods = new HashSet<string> { "Equip", "Drop", "RespondToAttack", "AddItemToRemoveQueue" };
        var checkedMethods = new HashSet<string>();
        var gameAssembly = typeof(Item).Assembly;
        var systemAssembly = typeof(object).Assembly;
        Type Resolve(string name) => Type.GetType(name,
            assembly => Assembly.Load(assembly),
            (assembly, type, ignoreCase) => assembly?.GetType(type, false, ignoreCase)
                ?? gameAssembly.GetType(type, false, ignoreCase)
                ?? systemAssembly.GetType(type, false, ignoreCase));

        foreach (Match file in Regex.Matches(init, "(?m)^\\s*dofile\\(Deep_Lua\\.Path\\s*\\.\\.\\s*\"([^\"]+)\""))
        {
            var path = Path.Combine(root.FullName, file.Groups[1].Value.TrimStart('/'));
            var source = File.ReadAllText(path);
            foreach (Match hook in Regex.Matches(source,
                "(?m)^[ \\t]*Hook\\.Patch\\([^()]{0,200}?\"(Barotrauma[^\"]+)\"\\s*,\\s*\"([^\"]+)\"\\s*,\\s*(?:\\{([^}]*)\\})?"))
            {
                var method = hook.Groups[2].Value;
                if (!methods.Contains(method)) { continue; }
                var type = Resolve(hook.Groups[1].Value);
                Assert.NotNull(type);
                var parameters = Regex.Matches(hook.Groups[3].Value, "\"([^\"]+)\"")
                    .Select(parameter => Resolve(parameter.Groups[1].Value)).ToArray();
                Assert.All(parameters, Assert.NotNull);
                const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance;
                var target = hook.Groups[3].Success
                    ? type.GetMethod(method, flags, null, parameters, null)
                    : type.GetMethod(method, flags);
                Assert.True(target != null,
                    $"Outdated Lua hook: {path}: {type.FullName}.{method}");
                checkedMethods.Add(method);
            }
        }
        Assert.True(methods.SetEquals(checkedMethods), "Not all migrated hook signatures were checked");
    }
}
