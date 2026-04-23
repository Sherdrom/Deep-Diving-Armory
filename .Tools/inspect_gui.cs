using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;

var dir = Path.GetFullPath(@".Tools\\Refs\\Windows");
AssemblyLoadContext.Default.Resolving += (ctx, name) => {
    var path = Path.Combine(dir, name.Name + ".dll");
    return File.Exists(path) ? ctx.LoadFromAssemblyPath(path) : null;
};
var asm = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(dir, "Barotrauma.dll"));
foreach (var typeName in new[]{"Barotrauma.GUIMessageBox","Barotrauma.GUI","Barotrauma.GUIFrame","Barotrauma.GUIListBox"})
{
    var t = asm.GetType(typeName);
    Console.WriteLine("TYPE=" + typeName + " => " + (t==null?"null":t.FullName));
    if (t == null) continue;
    foreach (var ctor in t.GetConstructors(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance))
    {
        Console.WriteLine("  CTOR " + ctor);
    }
    foreach (var prop in t.GetProperties(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Static|BindingFlags.Instance).Where(p => p.Name.Contains("Content") || p.Name.Contains("Canvas") || p.Name.Contains("Buttons") || p.Name.Contains("Visible") || p.Name.Contains("Parent") || p.Name.Contains("RectTransform") || p.Name.Contains("MessageBox") || p.Name.Contains("InnerFrame")))
    {
        Console.WriteLine("  PROP " + prop.PropertyType.Name + " " + prop.Name);
    }
    foreach (var meth in t.GetMethods(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Static|BindingFlags.Instance).Where(m => m.Name.Contains("AddToUpdateList") || m.Name.Contains("Close") || m.Name.Contains("AddButton") || m.Name.Contains("GetType")))
    {
        Console.WriteLine("  METH " + meth);
    }
}
