# DDA DeepAmmoLoader

从 VCE `22eb67c` 的 AmmoLoader 移植库存、装卸、弹药包回收、供给结算、预设、UI 与客户端/服务端同步。
实现位于 `DDA.AmmoLoading`，XML 组件为 `<DeepAmmoLoader>`，DLL 为 `DeepAmmoLoader.dll`。
VCE 的虚拟弹匣、弹药存储和弹匣预设仍是运行依赖；DDA 不再调用 VCE 的 AmmoLoader 或反射绑定 SupplyResolver。
LuaCs 从已加载程序集发现 ItemComponent，项目继续由 ModConfig.xml 注册。

`SharedProject/DdaSupply.cs` 保留六种 5.56 弹药箱映射，每 30 发消耗 1.5625 点 Condition，未完成的 RIP 不映射。
投料、取包、目标弹匣容器顺序为 0/1/2。卸弹和投入弹药包优先回填箱子，剩余存入机器库存；
装填和取包优先消耗现存子弹。原有弹药箱、旧式弹药及配方不变。

`Plugin.cs` 仅对 `deep_new_ammoloader` 的旧存档组件名作迁移，保留其 Stock 和属性；其他装弹机不改名。
本地预设改存 `DDA/DeepAmmoLoaderPresets.json`，首次保存前可读取原 `VCE/AmmoLoaderPresets.json`。
通用 UI 文本也已复制到 DDA 的 `dda.ammoloader.*`，DDA 原有文案优先。

## 构建

```powershell
dotnet build .AssemblyCSharpSource/DeepAmmoLoader/DeepAmmoLoader.sln -c Release -m:1
```

游戏引用固定为与 VCE 相同的 `Barotrauma.ReferenceAssemblies.Vanilla.Publicized 1.15.24`；其余库沿用 `.Tools/Refs`。
六个平台/目标输出至 `bin/{Client|Server}/{Windows|Linux|OSX}`；`.Tools/build-csharp.sh` 自动包含此解决方案。
`.Tools/Refs/{平台}/VanillaComponentsExpanded{目标}.dll` 为 VCE `22eb67c` 的编译引用快照，Private=false，不随 DDA 输出复制。
更新 VCE 虚拟弹匣 API 时同步这些引用，并重新构建与测试。运行时启用 VCE 和 LuaCs。

## 离线回归

```powershell
dotnet run --project .UnitTests/CSharp/DeepAmmoLoaderRegression -c Release
dotnet run --project .UnitTests/CSharp/DeepAmmoLoaderUI -c Release
dotnet run --project .UnitTests/CSharp/DeepAmmoLoader -c Release -- "<游戏目录>" "<VCE目录>" "<DDA目录>" "<LuaCs插件目录>" Client
dotnet run --project .UnitTests/CSharp/DeepAmmoLoader -c Release -- "<游戏目录>" "<VCE目录>" "<DDA目录>" "<LuaCs插件目录>" Server
```

后端回归编译生产代码并使用游戏边界桩，也验证预设迁移与损坏文件保护；UI 与集成回归加载实际 DLL，不启动游戏。
游戏内拖放、旧潜艇存档重载和双端联机仍需实测。
