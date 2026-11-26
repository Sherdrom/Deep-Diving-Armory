using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;

// Run in a separate process against the real game libraries, not publicized reference DLLs.
// dotnet run -c Release --project .UnitTests/CSharp/RemainedAmmo -- <game directory> <Deep-Diving-ArmoryClient.dll>
if (args.Length != 2)
{
    throw new ArgumentException("Expected the game directory and DDA client DLL path.");
}

string gameDirectory = Path.GetFullPath(args[0]);
AssemblyLoadContext.Default.Resolving += (context, name) =>
{
    string path = Path.Combine(gameDirectory, name.Name + ".dll");
    return File.Exists(path) ? context.LoadFromAssemblyPath(path) : null;
};

Assembly assembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.GetFullPath(args[1]));
Type pluginType = assembly.GetType("RemainedAmmo.RemainedAmmo", throwOnError: true)!;
Type harmonyType = Assembly.Load("0Harmony").GetType("HarmonyLib.Harmony", throwOnError: true)!;
object harmony = Activator.CreateInstance(harmonyType, "RemainedAmmo.PatchScopeTest")!;
var patchType = pluginType.GetNestedType("RangedWeapon_DrawHUD_Patch", BindingFlags.NonPublic)!;
var processor = harmonyType.GetMethod("CreateClassProcessor", [typeof(Type)])!.Invoke(harmony, [patchType])!;

try
{
    processor.GetType().GetMethod("Patch", Type.EmptyTypes)!.Invoke(processor, null);
    MethodBase[] patched = ((IEnumerable)harmonyType.GetMethod("GetPatchedMethods")!
        .Invoke(harmony, null)!).Cast<MethodBase>().ToArray();
    if (patched.Length != 1 || patched[0].Name != "DrawHUD" ||
        patched[0].DeclaringType?.FullName != "Barotrauma.Items.Components.RangedWeapon")
    {
        Console.Error.WriteLine("FAIL: expected only RangedWeapon.DrawHUD; patched: " +
            string.Join(", ", patched.Select(method => $"{method.DeclaringType?.FullName}.{method.Name}")));
        Environment.ExitCode = 1;
        return;
    }
    Console.WriteLine("PASS: HUD class processor patches only RangedWeapon.DrawHUD.");
}
finally
{
    harmonyType.GetMethod("UnpatchSelf")!.Invoke(harmony, null);
}
