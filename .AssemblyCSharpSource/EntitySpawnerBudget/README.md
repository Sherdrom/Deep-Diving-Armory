# EntitySpawnerBudget

本项目沿用 `../LuaCsModTemplate` 的 `Build.props`、Shared Project、Server Project 和解决方案结构，构建并部署 Linux、OSX、Windows Dedicated Server 版本。

构建：

```sh
dotnet build ServerProject/LinuxServer.csproj -c Release
dotnet build ServerProject/OSXServer.csproj -c Release
dotnet build ServerProject/WindowsServer.csproj -c Release
```

单元测试位于仓库的 `.UnitTests/CSharp/EntitySpawnerBudget`：

```sh
dotnet test ../../.UnitTests/CSharp/EntitySpawnerBudget/EntitySpawnerBudget.Tests.csproj -c Release
```

默认每帧实体生成预算为 2 ms。可在启动服务端前通过 `DDA_ENTITYSPAWNER_BUDGET_MS` 调整，允许范围为 0.25–10 ms。
