# 支持包内容迁出计划：Deep-Diving-Armory → 深潜拓展/SupporterPack

## 一、目标

将主模组 `Deep-Diving-Armory` 中的支持包内容（24 件专属武器、13 组专属弹匣及配套弹药、22 张设计图、支持者衣物、1 个任务、2 个 NPC 组、对应翻译与音乐）迁出到独立内容包：

```
E:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\深潜拓展\SupporterPack\
```

**已确认的决策**：
1. **主模组旧文件保留**（不删除文件本体），仅从 `filelist.xml` 移除注册。
2. **任务音乐随任务迁移**（music.xml 中 pigcat 条目 + 14 个 ogg）。
3. **Lua 脚本全部留在主模组**，对支持包 identifier 的引用做存在性守卫（nil 安全）。

**核心机制**：
- SupporterPack 声明依赖 `Deep-Diving-Armory`。identifier 级引用（弹匣 tag、affliction、LocationType、job、材料等）跨包自动解析，无需复制。
- **资源文件路径引用（texture/soundfile）必须落在新包内**：复制资源到 SupporterPack 的**相同相对路径**，则武器 xml 中的 `%ModDir%/...` 引用**无需修改**（%ModDir% 自动解析为所在包目录）。
- **identifier 冲突铁律**：Barotrauma 禁止同一 identifier 在两个已加载包中重复定义。因此：
  - 整文件迁出的：主模组只从 filelist 移除注册（文件保留但不再加载）。
  - 从大文件中"剪切 item 块"迁出的：**必须从主模组源文件删除对应块**（如 NewMag.xml、part.xml、Missions.xml、text/*.xml、music.xml）。

## 二、现状分析（探索结论）

### 武器名 → 文件/identifier 映射

| 中文名 | 文件（weapon/ 下） | identifier |
|---|---|---|
| 6p41 | machinegun/machinegun_tun/6p41_darkdog.xml | deep_6p41_darkdog |
| aek973 | rifle/rifle_tun/aek973.xml | deep_aek973 |
| MYGO | rifle/rifle_tun/ak74m_mygo.xml | deep_AK74M_mygo |
| 午后茶歇 | rifle/rifle_tun/g36c_roger.xml | deep_g36c_roger |
| LYXN | rifle/rifle_tun/lyxn.xml | deep_LYXN |
| mk22 | sniperrifle/sniper_tun/mk22.xml | deep_mk22_binary |
| ots-14 | rifle/rifle_tun/ots14.xml | deep_ots14 |
| rm338 | machinegun/machinegun_tun/rm338.xml | deep_rm338_taizong |
| B-10m | rifle/rifle_tun/ak74m_103.xml | deep_74m_103 |
| light of hope | rifle/rifle_tun/sa58_sheep.xml | deep_sa58_sheep |
| 云霄 | machinegun/machinegun_tun/rpd_thesun.xml | deep_rpd_thesun |
| 法律和军械 | rifle/rifle_tun/vhs_d3_baka.xml | deep_vhs_d3_baka |
| 和平卫士 | sniperrifle/sniper_tun/ar15_xiaohua.xml | deep_ar15_50_xiaohua |
| m14ebr | sniperrifle/sniper_tun/m14ebr_moonwolf.xml | deep_m14ebr_moonwolf |
| mk17 | rifle/rifle_tun/mk17_peach.xml | deep_mk17_peach |
| mkb42h | rifle/rifle_steel/mkb42h.xml | deep_mkb42h |
| 赤霄 | rifle/rifle_tun/QBZ95_chixiao.xml | deep_qbz95_chixiao |
| 三管霰弹枪 | shotgun/shotgun_tun/three_shotgun.xml | deep_pigcat_three_shotgun |
| 乌川 | melee/melee.xml L3（item 块剪切） | deep_wuchuan |
| 伊邪那岐 | sniperrifle/sniper_tun/izanagi_paidaxing.xml | deep_izanagi_paidaxing |
| 高斯 | sniperrifle/sniper_tun/gauss.xml | deep_Gauss_Benzoyl_Peroxide |
| 陨星 | grenadelauncher/gl_phy/meteorite.xml | deep_meteorite |
| 圣徒掠夺者 | launchers/launchers_tun/saintpredator.xml | deep_saintpredator |
| 黑色气旋 | machinegun/machinegun_tun/hs3000.xml | deep_hs3000 |

### 专属弹匣 → 所在文件（都需从主模组剪切）

| 弹匣 identifier | 主模组位置 |
|---|---|
| deep_762x54r_virtual_100_6p41 | ammo/NewMag/NewMag.xml L758 |
| deep_338nm_virtual_100_rm338 | ammo/NewMag/NewMag.xml L1117 |
| deep_762x39_virtual_100_redsun（云霄） | ammo/NewMag/NewMag.xml L448 |
| deep_338lm_virtual_10_mk22 | ammo/NewMag/NewMag.xml L1184 |
| deep_792x33_virtual_30_mkb42h | ammo/NewMag/NewMag.xml L959 |
| deep_50beowulf_virtual_10_ar50（和平卫士） | ammo/NewMag/NewMag.xml L1786 |
| deep_gauss_mag | ammo/NewMag/SpecialMag.xml L3 |
| deep_izanagi_paidaxing_mag_fu / _ap | ammo/NewMag/SpecialMag.xml L48 / L78 |
| deep_three_mag（三管霰弹枪） | ammo/NewMag/SpecialMag.xml L108 |
| deep_meteorite_mag（陨星） | grenadelauncher/gl_ammo.xml L79 起 |
| deep_clustermsl_saint（圣徒掠夺者） | launchers/launchers_shell.xml L3 起（文件首个 item） |

**配套专属弹药（弹匣内装的子弹，必须随弹匣迁移）** — 剪切自 ammo/NewAmmoRound/SpecialRound.xml：
- `gauss_round`（L341）、`izanagi_paidaxing_round_fu`（L379）、`izanagi_paidaxing_round_ap`（L416）、`deep_12shell_three`（L453）
- 其余 ptrd_145mm_* 系列属 NTW/PTRD（主模组），不动。

**配套设计图（22 个，剪切自 weapon/part/part.xml）**：
`6p41_design, aek973_design, mygo74m_design, g36c_roger_design, MK22_design, ots14_design, rm338_design, 74m_103_design, sa58_sheep_design, rpd_thesun_design, vhs_d3_baka_design, mk17_peach_design, m14ebr_moonwolf_design, ar15_50_xiaohua_design, qbz95_chixiao_design, three_shotgun_design, wuchuan_design, izanagi_paidaxing_design, gauss_design, meteorite_design, saintpredator_design, lyxn_design`
（part.xml 中 L513–L972 之间；其余 design 如 SCAR_shield/NTW/gm6 等属主模组，不动）

### 衣物
- `jobgear/common_suit.xml` — 整文件迁出（全部为支持者 suit，约 30 件；部分贴图引用原版 `Content/...` 路径，保持不变）。
- `jobgear/common_hat.xml` — 整文件迁出（2 件 hat）。
- `deep_exoskeleton_ast_rivet` — 在 `jobgear/exoskeleton.xml`（实施时确认是否单 item 文件；是则整文件迁，否则剪切）。
- `deep_alice_battlesuit_longhair_EXO` / `deep_alice_battlesuit_shorthair_EXO` — 在 `testfiles/Exosuit.xml`（3 个 item；剪切 alice 两个块，第 3 个 item 实施时确认归属）。

### 任务与关联资源
- 任务定义：`Missions/Missions.xml` L342 起 `deep_destory_pigcatteam_nightmare_first`（OutpostDestroyMission，约 24 行），引用 NPC 组 `deep_pigcat_team`、LocationType `deep_outpost_fight`（主模组，跨包引用即可）、图标 `Missions/icon/destory.png`。
- **音乐**：`music/music.xml` L20–32 的 `deep_pigcatteam_1~6/_end` 条目 + 14 个 ogg（Flame of Nuclear、The Survivor The Winner、Steel Rain、Battlefield 6 Warsaw Theme、Razormind、XI、Hunted、Decible、Host .b、tragedy、Disposal Unit、The Automaton Legion、grizzlies3 等），**仅此任务使用**，随任务迁移。
- **事件反向引用**：`Missions/event.xml` L775–968 共 8 处 `MissionStateAction` 引用该任务，全部属于主模组任务事件 `deep_meet_on_the_battleground`（L396 起）。按决策**留在主模组**；实施时查游戏源码确认 MissionStateAction 对未加载任务的容错行为（预期静默跳过；若报错则对该子块做条件化处理）。

### NPC
- `NPC/Pigcat/Pigcat1.xml`（npcset `deep_pigcat_team`，约 50 个 NPC）、`NPC/Pigcat/Pigcat2.xml`（npcset `deep_pigcat_team2`，15 个 NPC）整文件迁出。
- NPC 的 NpcMagazineLoadout 引用专属弹匣（redsun/gauss_mag/three_mag/meteorite_mag/ar50/mkb42h/izanagi_ap 等，同包内解析）+ 大量通用弹匣（主模组跨包解析）。job 引用 `deep_securityofficer_enemy` 等（主模组 Jobs.xml，跨包解析）。

### 翻译
- `text/Chinese.xml`、`text/English.xml` 中所有支持包条目（武器/弹匣/设计图/衣物/任务 missionname、missiondescription、missionsuccess、missionfailure、missionheader0、missionmessage0、Pigcat npc 相关）剪切到 SupporterPack 的 text 文件，主模组删除原行。
- GunSmith/Config 文本确认无支持包条目（探索未发现），实施时再复核一遍。

### Lua 硬编码引用（留主模组，加守卫）
- `Lua/Scripts/PeachTechnology/SpinningBarrels.lua` — `deep_hs3000`
- `Lua/Scripts/AliceTechnology/armorconfigs.lua` — `deep_exoskeleton_ast_rivet`（L2452）、`deep_alice_battlesuit_longhair_EXO`（L2491）、`deep_alice_battlesuit_shorthair_EXO`（L2540）
- `Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config/` — HeldWeapons.lua / MainItems.lua / WeaponMagazines.lua 中大量支持包 identifier
- `Lua/Scripts/PeachTechnology/LegacyAfflictions.lua` L150 — `deep_wuchuan_detection`
- `Lua/Scripts/Gunsmith/JSON/*.json` — 检查引用支持包武器的条目
- `Lua/Scripts/BenzeneTechnology/AllSprite/AllSprite.lua` — 6P41/RM338/MK22 换弹动画 Hook（由武器 xml 的 sprite 事件触发，物品不存在时 Hook 不触发，天然安全；确认无加载期硬引用即可）

## 三、SupporterPack 目录结构

```
深潜拓展/SupporterPack/
├── filelist.xml                        # 新建
├── weapon/
│   ├── machinegun/machinegun_tun/{6p41_darkdog,rm338,rpd_thesun,hs3000}.xml
│   ├── machinegun/machinegun_tun/Sprite/{6P41_darkdog,RM338_taizong,RPD_TheSun,HS_3000,MG42}.png
│   ├── rifle/rifle_tun/{aek973,ak74m_mygo,g36c_roger,lyxn,ak74m_103,sa58_sheep,vhs_d3_baka,mk17_peach,QBZ95_chixiao,ots14}.xml
│   ├── rifle/rifle_tun/{rifle_tun,rifle_tun_45}.png
│   ├── rifle/rifle_steel/mkb42h.xml + rifle_steel_45.png + rifle_steel.png
│   ├── sniperrifle/sniper_tun/{mk22,ar15_xiaohua,m14ebr_moonwolf,izanagi_paidaxing,gauss}.xml + {sniper_tun,sniper_tun_2}.png
│   ├── sniperrifle/{sniper45,sniper}.png
│   ├── machinegun/machinegun45.png
│   ├── shotgun/shotgun_tun/three_shotgun.xml + shotgun_tun.png；shotgun45.png
│   ├── grenadelauncher/gl_phy/meteorite.xml + {grenadelauncher,grenadelauncher45}.png
│   ├── launchers/launchers_tun/saintpredator.xml + launchers_45.png + launchers_tun/saint_predator/Saint_Predator.png
│   ├── melee/wuchuan.xml + melee.png + melee45.png + sound/{wuchuan_xuli,wuchuan_sata,wuchuan_bgm}.ogg
│   ├── ammo/NewMag/SupporterMag.xml          # 6 个虚拟弹匣（剪切自 NewMag.xml）
│   ├── ammo/NewMag/SupporterSpecialMag.xml   # gauss/izanagi/three 弹匣（剪切自 SpecialMag.xml）
│   ├── ammo/NewAmmoRound/SupporterRound.xml  # gauss_round/izanagi×2/deep_12shell_three
│   ├── grenadelauncher/gl_ammo.xml           # deep_meteorite_mag（剪切）
│   ├── launchers/launcher_shell_supporter.xml# deep_clustermsl_saint（剪切）
│   ├── part/design_supporter.xml             # 22 个设计图（剪切）
│   ├── ammo/*.ogg（武器引用的全部音效，同路径复制）
│   ├── ammo/mute/*.ogg
│   ├── sight/{frontsight,Launchers_Crosshairs}.png
│   └── launchers/Sound/{rocket_fire_1,rocket_re_2}.ogg
├── Sound/Weapons/{AWM,M14}/...         # mk22/m14ebr 引用音效，同路径复制
├── misc/{ui,ui2,ui3}.png               # SlotIcon 共享贴图
├── jobgear/
│   ├── common_suit.xml + suit/*.png（common_suit 引用的全部 %ModDir% 贴图）
│   ├── common_hat.xml + hat/hat.png
│   ├── exoskeleton.xml + exoskeleton/AST.png   # ast_rivet
│   └── alice_exo.xml + 对应贴图                # alice 两个 EXO（剪切自 testfiles/Exosuit.xml）
├── Missions/
│   ├── mission_pigcat_nightmare.xml    # 剪切自 Missions.xml L342+
│   └── icon/destory.png
├── music/music.xml + 14 个 ogg
├── NPC/Pigcat/{Pigcat1,Pigcat2}.xml
└── text/{Chinese,English}.xml          # 支持包条目
```

## 四、实施步骤

### 步骤 1：创建 SupporterPack 骨架与 filelist.xml
- 新建目录与 `filelist.xml`：
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <contentpackage name="Deep Diving Supporter Pack" modversion="0.1.0" corepackage="False" gameversion="1.15.33.2">
    <Dependency identifier="Deep-Diving-Armory" names="Deep-Diving-Armory" ids="3159849099" order="After" />
    <!-- 后续步骤填充文件条目 -->
  </contentpackage>
  ```
- 复制资源采用**同相对路径**策略：对每个迁移的 xml，扫描其中 `%ModDir%/` 引用的 png/ogg，逐一复制到 SupporterPack 相同相对路径（实施用 PowerShell 脚本自动收集，避免遗漏）。

### 步骤 2：整文件迁移（复制到 SupporterPack + 主模组 filelist 移除注册）
- 24 个武器 xml（乌川除外，见步骤 3）→ 复制。
- `jobgear/common_suit.xml`、`jobgear/common_hat.xml`、`jobgear/exoskeleton.xml` → 复制。
- `NPC/Pigcat/Pigcat1.xml`、`Pigcat2.xml` → 复制。
- 主模组 `filelist.xml` 移除对应 `<Item>` / `<NPCSets>` 行（L12/36/49-58/138/146-149/204/209-211/220/225/249-250/253/271-272/335）。

### 步骤 3：剪切型迁移（从主模组文件删除 item 块 → 写入 SupporterPack 新文件）
| 主模组源文件 | 剪切内容 | SupporterPack 目标 |
|---|---|---|
| weapon/melee/melee.xml L3 起 | deep_wuchuan item 块 | weapon/melee/wuchuan.xml |
| weapon/ammo/NewMag/NewMag.xml | 6 个专属虚拟弹匣块 | weapon/ammo/NewMag/SupporterMag.xml |
| weapon/ammo/NewMag/SpecialMag.xml | gauss/izanagi×2/three 4 个弹匣块 | weapon/ammo/NewMag/SupporterSpecialMag.xml |
| weapon/ammo/NewAmmoRound/SpecialRound.xml | gauss_round、izanagi_round×2、deep_12shell_three | weapon/ammo/NewAmmoRound/SupporterRound.xml |
| weapon/grenadelauncher/gl_ammo.xml | deep_meteorite_mag | weapon/grenadelauncher/gl_ammo.xml |
| weapon/launchers/launchers_shell.xml | deep_clustermsl_saint | weapon/launchers/launcher_shell_supporter.xml |
| weapon/part/part.xml | 22 个设计图 item 块 | weapon/part/design_supporter.xml |
| testfiles/Exosuit.xml | alice 两个 EXO item 块 | jobgear/alice_exo.xml |
| Missions/Missions.xml L342–365 | 任务定义 | Missions/mission_pigcat_nightmare.xml |
| music/music.xml L20–32 | pigcat 音乐条目 | music/music.xml |

- 每处剪切后**必须**从主模组源文件删除原块（防 identifier 冲突）。
- 主模组 `filelist.xml` 移除 `music/music.xml` 注册（若该文件剪切后无剩余内容）；`Missions/Missions.xml` 保留注册（剩余任务仍在）。

### 步骤 4：文本迁移
- 按 identifier 关键字（见第二节清单 + `deep_destory_pigcatteam`、pigcat npc、common suit/hat 的 nameidentifier、alice EXO、ast_rivet）从 `text/Chinese.xml`、`text/English.xml` 剪切条目到 SupporterPack `text/Chinese.xml`、`text/English.xml`；主模组删除原行。
- 用 item xml 中的 `nameidentifier`（若有）反查文本，确保无遗漏；再全文 grep 支持包 identifier 复核主模组 text 无残留。

### 步骤 5：资源自动收集复制
- 写一次性 PowerShell 脚本：读取 SupporterPack 全部 xml，正则收集 `(%ModDir%|Content)/[^"]*\.(png|ogg)` 引用 → 从主模组复制 `%ModDir%` 资源到 SupporterPack 同路径；`Content/` 开头为原版资源跳过。
- 复制完成后删除该脚本（不留中间文件）。

### 步骤 6：Lua nil 安全守卫
逐一检查并按需加守卫（模式：使用前 `ItemPrefab.GetItemPrefab(id)` 判空跳过；不引入 pcall）：
- SpinningBarrels.lua（deep_hs3000）
- armorconfigs.lua 三个条目
- AdjustStatvalue 配置表（确认配置驱动、物品缺失时自然跳过；若直接索引 prefab 则加守卫）
- LegacyAfflictions.lua L150
- Gunsmith JSON 中引用支持包武器的条目
- AllSprite.lua 确认无加载期硬引用

### 步骤 7：主模组 filelist.xml 收尾
- 全部移除后核对：无指向已剪切内容的注册残留；`NewMag.xml/SpecialMag.xml/SpecialRound.xml/gl_ammo.xml/launchers_shell.xml/part.xml/melee.xml/Missions.xml` 保留注册（剩余内容仍在）。
- 主模组 `modversion` 不主动 bump（由用户后续发布时决定）。

### 步骤 8：SupporterPack filelist.xml 填充完整
注册所有迁移文件：Item（武器/弹匣/弹药/设计图/衣物）、NPCSets×2、Missions、Sounds（music.xml）、Text×2。不含 event.xml（事件留主模组）。

## 五、验证

1. **加载测试（debug 模式）**：主模组 + SupporterPack 同时启用启动游戏，确认无 "duplicate identifier"、无 missing file 报错。
2. **独立运行**：仅启用主模组（不含 SupporterPack）启动，确认无 Lua 报错、无 missing identifier 报错。
3. **内容冒烟**：游戏内 spawn 每件支持包武器/弹匣，检查贴图显示、射击音效、弹匣装填（6P41/RM338 手动装填动画）。
4. **任务验证**：debug 触发 `deep_destory_pigcatteam_nightmare_first`，确认 NPC 生成（含专属弹匣装填）、任务音乐播放、击杀后 `deep_meet_on_the_battleground` 的 MissionStateAction 正常联动。
5. **文本验证**：中文/英文语言下检查武器名、任务文本无 entityname 缺失（显示原始 identifier 即为缺失）。

## 六、风险与注意事项

- **identifier 冲突**是最大风险：所有剪切型迁移必须同步删除主模组源块；text 条目同理。
- 共享贴图（rifle_tun.png、machinegun45.png、ui.png 等）与共享音效（jam_alarm.ogg 等）复制到 SupporterPack 会造成磁盘冗余，但保证包自包含，符合用户"保留旧文件"决策。
- `deep_meet_on_the_battleground` 事件的 MissionStateAction 引用迁移后的任务：实施时查游戏源码 `MissionStateAction`/`MissionAction` 对不存在 identifier 的行为，若非静默跳过则在 Lua 层或事件结构上兜底。
- 武器 xml 内部可能引用 affliction/particle/GunSmith 部件 identifier（主模组），跨包解析依赖依赖声明与加载顺序（order="After"）。
- 多人服务器：支持包与主模组必须同时安装于服务器与客户端，否则客户端物品校验不一致（Barotrauma 原生机制保证，无需额外代码）。
