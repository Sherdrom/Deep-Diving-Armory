# Base Barotrauma Plugin

This repository provides a base template used by most Barotrauma plugins.

Documentation available at https://regalis11.github.io/BaroModDoc/Plugins/GettingStarted.html

This copy comes from [FakeFishGames/BaseBaroPlugin](https://github.com/FakeFishGames/BaseBaroPlugin/tree/19105acb68fdbe623dfaa5ff5daa3c66d476e17b).

## Build

Use the .NET 8 SDK and open [Deep-Diving-Armory.sln](Deep-Diving-Armory.sln) for all three platforms. Each platform folder shows its client and server projects and a view of the shared source.

To build just one platform, use the [Windows](Solutions/WindowsSolution.slnf), [Linux](Solutions/LinuxSolution.slnf), or [macOS](Solutions/OSXSolution.slnf) solution filter. For example, run `dotnet build .AssemblyCSharpSource/DDACsSource/Solutions/WindowsSolution.slnf -c Release` from the repository root.

When this checkout is in the game's `LocalMods/Deep-Diving-Armory` directory, [UserBuildData.props](UserBuildData.props) deploys each plugin assembly and its `.deps.json` file to `bin/<platform>/<target>` inside the mod. For a checkout elsewhere, pass `-p:ModDeployDir=<mod package directory>` to choose a destination. The mod content and its `filelist.xml` are maintained in the repository root.

The shared `IBarotraumaPlugin` entry point is in `SharedProject/SharedSource/Plugin.cs`. Edit platform-side code in `ClientProject/ClientSource` and `ServerProject/ServerSource`.
