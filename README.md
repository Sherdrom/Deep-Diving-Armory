# 推荐的开发工具
* [VSCode](https://code.visualstudio.com)  
* [git](https://git-scm.com/)
# git使用教程
## 简单上手
视频：[给傻子的Git教程](https://www.bilibili.com/video/BV1Hkr7YYEh8)
## 进阶
博文：[如何作为Collaborator在Github更新仓库（上传代码）](https://blog.csdn.net/m0_48319758/article/details/122832675)

## Dev_Mag 单机试验

本轮使用本地 VCE `Dev`：基线 `3226456`，弹药修正 `f585b28`（虚拟弹匣白名单判定、Harmony 显式指定插件程序集），护盾修正 `2e18034`。这两项 VCE 修正尚未推送，复现本分支需要配套使用，不能只更新 DDA。VCE 的六个目标 DLL 和 DDA 的三个 RemainedAmmo 客户端 DLL 已随源码重编。

- 试点武器为 `deep_hk416`。9 种通用 5.56 弹匣／弹鼓使用 `VirtualizedMagazine`，容量为 30／60 发；VHS 专用弹匣仍走旧系统。
- 弹匣保留原物品 ID、配方和价格，因此其他共用这些弹匣的枪械也会使用新弹匣；本轮验收围绕 HK416。
- 5.56 虚拟弹匣／弹鼓由压弹机内的弹药箱决定新增弹种：铅制／钛制／刚素制／雷刚／钨刚／贫铀复装弹药箱分别补入普通／钛／刚素／M995／SSA AP／贫铀弹。空匣也遵循此规则，旧式弹匣仍匹配原有弹药箱。
- 压弹机通过数字输入框选择上排弹药箱格位、下排弹匣格位（各排从左到右 1–6）和装入发数（0 为补满），点击开始后只装填选中的弹匣。保留原有装填时间、满匣资源消耗，按实际装入的整发数结算；点击停止、取走任一物品、材料不足或弹匣装满时结束。已有混装子弹及其相对顺序保留，新增子弹优先发射。旧式弹匣仍自动补弹。
- 接入 `Press R to Reload` 的 `pressrtoreload.reload` 钩子：优先选择身上可访问、兼容且余弹最多的备匣，交换整只弹匣并由原生库存交换收纳旧匣；失败也不回落到自动合并。不从另一把武器取匣，不接管下挂和旧式弹匣。
- 9 种通用 5.56 弹匣／弹鼓的空匣和满匣均不堆叠。悬停提示显示余弹／容量、下一发和各弹种数量，无需按 Shift；同总数下更换弹种或顺序也会刷新。
- shortcut: VCE 弹种栈的存档和多人同步尚未完成，待上游提供持久化/同步后再做旧存档迁移；当前请用单机新生成物品试验，不保证存读档后的弹数和弹序。

游戏内验收：新生成 HK416 和普通／扩容弹匣，分别射击至空匣，检查 30／60 发计数；用压弹机依次装入指定数量的不同弹种，检查指定来源／目标、发数上限、停止／移出取消、资源扣除及新增弹先发射；检查悬停提示、不堆叠、R 换匣与旧匣收纳（含背包满／无备匣／双持／下挂槽），以及换弹动画、点射／连发、友军识别芯片。联网和旧存档迁移不在本轮验收范围，VCE 的手动合并与卸弹问题留给上游处理。

自动检查（仓库根目录执行）：

```sh
lua .UnitTests/Lua/VirtualMagazineRefill.test.lua
lua .UnitTests/Lua/VirtualMagazineReload.test.lua
lua .UnitTests/Lua/VirtualProjectileHooks.test.lua
dotnet run --project .UnitTests/CSharp/MoreInformationDisplay -c Release
dotnet build .UnitTests/CSharp/VirtualMagazine -c Release
```

DLL 回归测试当前针对 macOS 的 `bin/Client/OSX`，使用与游戏相同架构的 .NET 运行时：`dotnet .UnitTests/CSharp/VirtualMagazine/bin/Release/net8.0/VirtualMagazine.Tests.dll <游戏目录> <VCE目录> <DDA目录>`。它加载实际 DLL，检查发射补丁、装填限制、扣弹、HUD 和 Lua 调用；只跳过依赖场景的弹体刷新，不替代游戏内验收。

### 2026-10-30 DDA 交互适配（离线验证）

R 换匣、压弹机选弹／定量装填、不堆叠和混装提示已实现。XML、Lua 换匣／装填／旧弹体回归以及实际提示源码编译与内容检查通过；Lua 测试模拟库存和 VCE，提示测试使用本地 LuaCs 引用及虚拟弹匣夹具，尚未验证新界面的实际布局、原生交换回滚和游戏按键操作。复测脚本已改为依次启动两个目标弹匣的装填，不代表新脚本已在游戏内运行。

本轮未修改 VCE。DDA 的新换匣和可控混装入口暂限单机；存读档、迁移、多人同步、手动合并弹序和卸弹刷新仍依赖 VCE 后续维护。提示中的各弹种数量暂时只读 VCE 的内部弹种栈，待上游提供公开只读接口后替换。


### 2026-10-29 macOS 运行验证

Steam Build `26144264` / 游戏 `1.13.5.0`，LuaCs revision `c6e8829`，C# 已启用。游戏实际加载本地 VCE、GunsmithFramework 和 DDA。在原版 Dugong 的单机编辑器测试场景中验证：

- 新生成弹匣／弹鼓为 30／60 发，虚拟弹体正常生成。
- 压弹机补入 28＋60 发钛弹，弹药箱消耗 `4.583336` 点；原有 M995、普通弹的顺序保持不变，新增钛弹先出栈。
- 通过真实 `Item.Use` 射击入口分别射空 30／60 发，每次只扣一发，HUD 计数随之归零，空匣不再提供弹体。换弹保留原有 1.6 秒锁定。
- 测试脚本临时关闭所生成枪械的瞄准按键要求，结束时恢复；未覆盖鼠标操作、动画观感、点射／连发模式切换、友军芯片和下挂武器。未测试多人或存读档。
- 初次启动发现的 `VoidShield.Plugin.OnLoadCompleted` Harmony IL 编译异常已在本地 VCE 修复：命中补丁不再硬编码平台局部变量编号，三平台客户端／服务端构建及 IL 检查通过，macOS 重新进入场景后确认四个护盾补丁已注册且无该异常。未覆盖护盾实弹拦截和多人。装备属性脚本缺少 `deep_ten_star_general_assist_upgrading` 的提示仍存在。

复测只在可丢弃的单机编辑器测试场景执行：先在控制台运行 `cl_lua load(File.Read('LocalMods/Deep-Diving-Armory/.UnitTests/Lua/VirtualMagazineRuntime.test.lua'))()`，关闭控制台并等到输出 `ready for firing`；再运行 `cl_lua load(File.Read('LocalMods/Deep-Diving-Armory/.UnitTests/Lua/VirtualMagazineRuntimeFire.test.lua'))()`，关闭控制台并等待约 30 秒。结果写入 `.UnitTests/runtime-magazine.log`。每次复测使用新场景，退出时不保存。
