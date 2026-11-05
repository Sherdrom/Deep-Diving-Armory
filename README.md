# 推荐的开发工具
* [VSCode](https://code.visualstudio.com)  
* [git](https://git-scm.com/)
# git使用教程
## 简单上手
视频：[给傻子的Git教程](https://www.bilibili.com/video/BV1Hkr7YYEh8)
## 进阶
博文：[如何作为Collaborator在Github更新仓库（上传代码）](https://blog.csdn.net/m0_48319758/article/details/122832675)

## 新弹匣系统（Dev_Unstable）

2026-11-05：`Dev_Mag` 已合入 `Dev_Unstable`，后续新弹匣系统在 `Dev_Unstable` 上继续开发。当前 Windows 游戏 `1.15.26.0`、VCE `Dev`（`5067ce6`）已通过下述核心单机场景验收；完整存读档及其他边界仍待验证。

此前 macOS 试验使用的本地 VCE `Dev` 基线为 `3226456`，另含弹药修正 `f585b28` 和护盾修正 `2e18034`；该历史环境与当前 Unstable 验收环境不同。

- 试点武器为 `deep_hk416`。9 种通用 5.56 弹匣／弹鼓使用 `VirtualizedMagazine`，容量为 30／60 发；VHS 专用弹匣仍走旧系统。
- 弹匣保留原物品 ID、配方和价格，因此其他共用这些弹匣的枪械也会使用新弹匣；本轮验收围绕 HK416。
- 5.56 虚拟弹匣／弹鼓由压弹机内的弹药箱决定新增弹种：铅制／钛制／刚素制／雷刚／钨刚／贫铀复装弹药箱分别补入普通／钛／刚素／M995／SSA AP／贫铀弹。空匣也遵循此规则，旧式弹匣仍匹配原有弹药箱。
- 压弹机通过数字输入框选择上排弹药箱格位、下排弹匣格位（各排从左到右 1–6）和装入发数（0 为补满），点击开始后只装填选中的弹匣。保留原有装填时间、满匣资源消耗，按实际装入的整发数结算；点击停止、取走任一物品、材料不足或弹匣装满时结束。已有混装子弹及其相对顺序保留，新增子弹优先发射。旧式弹匣仍自动补弹。
- 接入 `Press R to Reload` 的 `pressrtoreload.reload` 钩子：优先选择身上可访问、兼容且余弹最多的备匣，交换整只弹匣并由原生库存交换收纳旧匣；失败也不回落到自动合并。不从另一把武器取匣，不接管下挂和旧式弹匣。
- 9 种通用 5.56 弹匣／弹鼓的空匣和满匣均不堆叠。悬停提示显示余弹／容量、下一发和各弹种数量，无需按 Shift；同总数下更换弹种或顺序也会刷新。
- shortcut: VCE 已提供弹序序列化，但完整存读档、旧存档迁移和多人同步尚未验收；DDA 的新装填和换匣入口仍限单机，待上游同步能力验证后再接入联机。

游戏内验收：新生成 HK416 和普通／扩容弹匣，分别射击至空匣，检查 30／60 发计数；用压弹机依次装入指定数量的不同弹种，检查指定来源／目标、发数上限、停止／移出取消、资源扣除及新增弹先发射；检查悬停提示、不堆叠、R 换匣与旧匣收纳（含背包满／无备匣／双持／下挂槽），以及换弹动画、点射／连发、友军识别芯片。联网和旧存档迁移不在本轮验收范围，VCE 的手动合并与卸弹问题留给上游处理。

自动检查（仓库根目录执行；提示测试需传入本机 Unstable 游戏目录以加载运行依赖，CI 仅编译该测试）：

```sh
lua .UnitTests/Lua/VirtualMagazineRefill.test.lua
lua .UnitTests/Lua/VirtualMagazineReload.test.lua
lua .UnitTests/Lua/VirtualProjectileHooks.test.lua
dotnet run --project .UnitTests/CSharp/MoreInformationDisplay -c Release -- "<游戏目录>"
dotnet build .UnitTests/CSharp/VirtualMagazine -c Release
```

DLL 回归测试使用 .NET 9，按本机平台加载 VCE `bin/<Windows|Linux|Mac>/Client/VanillaComponentsExpandedClient.dll`、DDA 的 RemainedAmmo 和实际安装的 LuaCs 插件：

```sh
dotnet run --project .UnitTests/CSharp/VirtualMagazine -c Release -- "<游戏目录>" "<VCE目录>" "<DDA目录>" "<LuaCs插件目录>"
```

LuaCs 插件目录是包含 `PluginInfo.xml` 的包根目录。测试检查实际发射补丁、装填限制、扣弹、HUD、Lua 调用及空弹匣的弹序字符串回读；不初始化游戏插件宿主，跳过依赖场景的弹体刷新，不替代游戏内加载、射击或完整存读档验收。参数缺失或测试失败会输出错误并返回非零退出码。

### 2026-11-05 Windows Unstable 单机验收

使用 Computer Use 操作游戏，在原版 Dugong 的可丢弃编辑器测试场景中验证，结束后返回编辑器，未保存测试场景。本轮仅更新测试与说明，未修改 DDA 运行逻辑或 VCE。

- 真实 DLL 集成测试通过：新版合并 DLL、发射补丁、白名单／容量、扣弹、HUD、MoonSharp 调用和空栈弹序字符串回读；缺少参数正常返回非零退出码。
- 游戏内脚本断言通过：30／60 发初始化、选择目标装填、28＋60 发钛弹的资源消耗 `4.583336`、新增钛弹优先出栈且原有 M995／普通弹顺序保留。
- 真实 `Item.Use` 入口分别射空 30／60 发，逐发扣一发，HUD 读数归零，空匣不再提供弹体。脚本暂时关闭测试枪械的瞄准要求，结束后恢复；这不等于鼠标射击操作验收。
- 实际界面输入并点击开始，正好装入 5 发钛弹，资源扣除正确；悬停可见 `5/30`、下一发钛弹和钛弹数量，无需 Shift。
- 实际按 R 完成整匣交换并收纳旧匣；无有弹备匣时保持不变。可用背包格位全满时仍成功交换 10 发混装弹鼓与 5 发弹匣，两只弹匣的数量和弹序不变。
- 修正了测试夹具的分号信号格式、控制台暂停时的射击冷却等待、生成物品所属潜艇，以及不可用隐藏库存格位的判定。

本轮未覆盖：完整保存退出再读取／旧存档迁移、多人、逐弹种伤害及特效、点射／连发切换、友军芯片、双持和下挂、原生交换被拒绝后的回滚；停止／移出取消与不堆叠仍以现有离线检查为主。游戏仍有 `deep_apscore` 缺少名称的警告。

交互复测接在下方两个运行脚本完成之后，仍只使用可丢弃场景：

1. 控制台执行 `cl_lua local t=DDA_RUNTIME_TEST; assert(t.items.press.OwnInventory.TryPutItem(t.items.mag,6,false,false,nil,false)); t.uiBoxBefore=t.items.box.Condition; Character.Controlled.SelectedItem=t.items.press`，关闭控制台；界面选择来源 1、目标 1、发数 5，点击开始并检查提示。
2. 控制台执行 `cl_lua local t=DDA_RUNTIME_TEST; local c=Character.Controlled; assert(t.magazine.LoadedCount==5 and math.abs(t.uiBoxBefore-t.items.box.Condition-5*1.5625/30)<0.001); c.SelectedItem=nil; assert(c.Inventory.TryPutItem(t.items.mag,c,{InvSlotType.Any},false)); local hands={}; for s in t.items.gun.AllowedSlots do if s~=InvSlotType.Any then hands[#hands+1]=s end end; assert(c.Inventory.TryPutItem(t.items.gun,c,hands,false))`，关闭控制台，按 R 两次（第二次无有弹备匣）。
3. 执行 `cl_lua load(File.Read('LocalMods/Deep-Diving-Armory/.UnitTests/Lua/VirtualMagazineRuntimeReload.test.lua'))()`；关闭控制台，等待背包填满，再按 R 一次。最后执行 `cl_lua DDA_RUNTIME_TEST.checkFullInventoryReload()`，核对日志中的通过记录。

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
