# Unstable build references

These files are compile-time references, not files to copy over the game installation.

- `Windows`: installed **Barotrauma 1.15.25.0** assemblies, with type, method and field visibility publicized using Mono.Cecil for compilation.
- `Linux`, `OSX`: game assemblies from `Barotrauma.ReferenceAssemblies.Vanilla.Publicized` **1.15.24** on NuGet (the latest available reference package on 2026-11-04). The upstream `Mac` directory maps to this repository's existing `OSX` directory.
- Farseer, Lidgren, MonoGame and XNATypes: `Barotrauma.ReferenceAssemblies.Libraries` **1.15.24**.
- `LuaCsForBarotraumaPluginClient.dll`, `LuaCsForBarotraumaPluginServer.dll` and MoonSharp: the installed **LuaCsForBarotraumaPlugin** workshop package **3693624471**, snapshot taken on **2026-11-04**, with a separate assembly for each platform and target.
- `System.Collections.Immutable.dll`: version **9.0.0.0**, supplied by the installed **Barotrauma 1.15.25.0**. The new game and LuaCs assemblies require it. DDA plugins, templates and test projects target .NET 8. Build the tests with the .NET 8 SDK: the tooltip test references that SDK's Roslyn assemblies.

When updating these references, update all three platforms and both targets together. Rebuild with `.Tools/build-csharp.sh`, and run the compatibility tests for both `BuildTarget=Client` and `BuildTarget=Server`. Compilation does not validate Harmony transpilers or in-game behavior.
