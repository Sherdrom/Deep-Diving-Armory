# 推荐的开发工具
* [VSCode](https://code.visualstudio.com)  
* [git](https://git-scm.com/)
# git使用教程
## 简单上手
视频：[给傻子的Git教程](https://www.bilibili.com/video/BV1Hkr7YYEh8)
## 进阶
博文：[如何作为Collaborator在Github更新仓库（上传代码）](https://blog.csdn.net/m0_48319758/article/details/122832675)

## AmmoBox identifier 命名

复装弹药箱统一使用 `deep_ammobox_<material>`：全小写英文和下划线，材质写全称，不使用口径、容量或历史序号。分类标签继续使用 `smallitem,deep_ammobox`，子分类为 `deep_ammobox`。

| 弹药箱 | 旧 identifier | 新 identifier |
| --- | --- | --- |
| 铅制 | `ammobox1` | `deep_ammobox_lead` |
| 钛制 | `ammobox_7.62` | `deep_ammobox_titanium` |
| 刚素 | `ammobox_12.7` | `deep_ammobox_physicorium` |
| 雷刚 | `ammobox_phy_ful` | `deep_ammobox_fulgurium_physicorium` |
| 钨刚 | `ammobox_tun_ful` | `deep_ammobox_tungsten_physicorium` |
| 贫铀 | `ammobox_du` | `deep_ammobox_depleted_uranium` |
| 铜制空尖弹（RIP） | `ammobox_rip` | `deep_ammobox_copper` |

XML、Lua、C# 和本地化统一引用新 ID；不保留旧 ID 别名或旧存档迁移。价格、配方、容量和供弹消耗不变。

## 新弹匣系统（Dev_Unstable）

2026-11-06：新弹匣系统统一在 `weapon/ammo/NewMag/NewMag.xml` 中定义，沿用独立物品 ID `deep_556x45_virtual_30` 继续开发。原有 9 种通用 5.56 弹匣／弹鼓恢复改造前的耐久计弹、堆叠和自动复装定义，保留原 ID、贴图、配方和价格。

2026-11-07：深潜武装通用压弹机（`ammoreload_machine`）及共享耐久转移脚本恢复到 `525a859c` 加入混装弹药前的版本，包括原来的集合遍历方式；移除混装／定量装填界面及钩子。新压弹机单独开发，以下历史混装压弹验收记录不代表当前旧版压弹机的能力。

下述 2026-11-05 Windows 游戏 `1.15.26.0`、VCE `Dev`（`5067ce6`）验收记录对应拆分前的原型；新物品尚未在游戏内复测。之前已保存的虚拟版旧 ID 弹匣不做弹序迁移，测试时请重新生成物品。

此前 macOS 试验使用的本地 VCE `Dev` 基线为 `3226456`，另含弹药修正 `f585b28` 和护盾修正 `2e18034`；该历史环境与当前 Unstable 验收环境不同。

- 试点武器为 `deep_hk416`。新系统专用物品为 `deep_556x45_virtual_30`（5.56x45通用30发弹匣），定义在 `weapon/ammo/NewMag/NewMag.xml`；使用 `VirtualizedMagazine`，容量 30 发，初始为空匣，不预装子弹。
- 图标与地面贴图均取自 `weapon/ammo/NewMag/Mag1.png` 左上角弹匣，裁切区域 `11,11,54,120`。新弹匣沿用普通 30 发弹匣的价格和制造配方，保留 `deep_5.56x45`／`556mag` 兼容标签，可装入原有兼容枪械。
- 旧版通用压弹机按原有配方自动为普通弹匣补充耐久，保留原速率和弹药箱消耗，不再提供混装选弹或定量装填。新系统弹匣的装填由新压弹机承担。
- 接入 `Press R to Reload` 的 `pressrtoreload.reload` 钩子：优先选择身上可访问、兼容且余弹最多的备匣，交换整只弹匣并由原生库存交换收纳旧匣；失败也不回落到自动合并。不从另一把武器取匣，不接管下挂和旧式弹匣；空枪没有可用新备匣时交回原有换弹流程。
- 新弹匣的空匣和满匣均不堆叠，旧弹匣恢复原有堆叠。悬停提示显示余弹／容量、下一发和各弹种数量，无需按 Shift；同总数下更换弹种或顺序也会刷新。
- shortcut: VCE 已提供弹序序列化，但完整存读档、旧存档迁移和多人同步尚未验收；DDA 的新换匣入口仍限单机，待上游同步能力验证后再接入联机。

游戏内验收：新生成 HK416 和两只 `deep_556x45_virtual_30`，由测试脚本直接填入弹序后分别射击至空匣，检查各 30 发计数；另用旧 5.56 弹匣检查耐久扣弹、堆叠、旧压弹机自动复装和空枪 R 装填；检查悬停提示、不堆叠、R 换匣与旧匣收纳（含背包满／无备匣／双持／下挂槽），以及换弹动画、点射／连发、友军识别芯片。此脚本不验证新压弹机。联网和旧存档迁移不在本轮验收范围，VCE 的手动合并与卸弹问题留给上游处理。

自动检查（仓库根目录执行；提示测试需传入本机 Unstable 游戏目录以加载运行依赖，CI 仅编译该测试）：

```sh
lua .UnitTests/Lua/ContainerConditionTransfer.test.lua
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

当前复测脚本已改为生成两只新系统专用 30 发弹匣（`mag`／`spare`），以下操作接在下方两个运行脚本完成之后，仍只使用可丢弃场景；上述历史验收不代表这些改动已复测：

1. 控制台执行 `cl_lua local t=DDA_RUNTIME_TEST; assert(t.magazine.LoadedCount==0); local Id=LuaUserData.CreateStatic('Barotrauma.Identifier'); local rounds={}; for i=1,5 do rounds[i]=Id('5.56x45round_tit') end; t.magazine.PushAmmoArray(rounds)`，直接准备 5 发换匣夹具。
2. 控制台执行 `cl_lua local t=DDA_RUNTIME_TEST; local c=Character.Controlled; assert(t.magazine.LoadedCount==5); c.SelectedItem=nil; assert(c.Inventory.TryPutItem(t.items.mag,c,{InvSlotType.Any},false)); local hands={}; for s in t.items.gun.AllowedSlots do if s~=InvSlotType.Any then hands[#hands+1]=s end end; assert(c.Inventory.TryPutItem(t.items.gun,c,hands,false))`，关闭控制台，按 R 两次（第二次无有弹备匣）。
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
