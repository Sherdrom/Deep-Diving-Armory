# DDA AmmoLoaderSupply

为 `deep_new_ammoloader` 绑定 VCE `SupplyResolver`，弹药箱种类、弹种和每发成本均在
`SharedProject/AmmoLoaderSupply.cs` 的 `SupplyCosts` 中定义。VCE 负责计划校验、实际扣耗与同步。

目前仅配置新虚拟弹匣使用的六种 5.56 弹药，每 30 发消耗对应弹药箱 1.5625 点 Condition。
未制作的虚拟口径不提供映射，RIP 留空。只有单人游戏或服务端绑定供给；其他装弹机不受影响。
VCE 未安装或缺少供弹 API 时记录提示并跳过接入。插件卸载时移除自己的补丁与回调。

装弹机 XML 启用 VCE `UseSupplyStorage`：卸弹和投入弹药包优先回填对应弹药箱，
缺箱或满箱的剩余弹药存入机器库存。装填和取包优先消耗现存弹药，再扣箱内储量。
机器内耗尽的箱子保留用于回填。投料、取包、目标弹匣依次对应第一个、第二个、第三个容器。

六种 30 发包装定义于 `weapon/ammo/NewAmmoPackages/Pack_5.56x45.xml`，复用对应子弹的
`AmmoIcon.png` 图块，不提供合成配方。原有弹药箱、旧式弹药和空弹匣配方保留。
`TextPrefix="dda.ammoloader."` 从 DDA 中英文文本获取标签与说明；缺少的通用文本回退到 VCE。
修改投料标题不会改变投料槽的尺寸或间距。开发阶段需重新放置机器，不提供旧存档迁移。

从 DDA 根目录构建三平台客户端与服务端，并输出至本项目 `bin`：

```powershell
dotnet build .AssemblyCSharpSource/AmmoLoaderSupply/AmmoLoaderSupply.sln -c Release -m:1
```

`.Tools/build-csharp.sh` 会自动包含本解决方案。`ModConfig.xml` 注册预编译 DLL，
不使用 `IsScript`。运行时仍需当前带 `SupplyResolver` API 的 VCE。

离线集成检查（使用实际 DLL，不启动游戏；分别传入 Client 和 Server）：

```powershell
dotnet run --project .UnitTests/CSharp/AmmoLoaderSupply -c Release -- "<游戏目录>" "<VCE目录>" "<DDA目录>" "<LuaCs插件目录>" Client
dotnet run --project .UnitTests/CSharp/AmmoLoaderSupply -c Release -- "<游戏目录>" "<VCE目录>" "<DDA目录>" "<LuaCs插件目录>" Server
```

检查供弹映射、XML 注册与容器配置、包装容量与贴图、无配方、本地化、现存及新建机器绑定、其他回调保护和卸载清理。
投料拖放、实际装填扣耗、存档和多人同步仍需在游戏中验证。
