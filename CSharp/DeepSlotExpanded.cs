using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Xml.Linq;
using HarmonyLib;
using MoonSharp.Interpreter;

namespace DeepSlotExpanded
{
    /// <summary>
    /// 自定义服装槽框架 v1.0.0（DDA 专用版：代码与「潜水服独立槽」框架 M17 完全一致，唯一改动 = 删除内置潜水服槽声明）。
    /// 本框架不注册任何槽位——全部槽位由 XML/Lua 声明产生（见《框架接口说明书.md》）。
    ///
    /// 原理：
    ///  - InvSlotType 是 int32 底层 [Flags] 枚举，16384 及以上的位可用于自定义槽；
    ///  - SlotRegistry 维护「槽位声明」列表：每个声明 = 一个空闲 bit + 触发迁移的物品标签/identifier + 来源槽掩码；
    ///  - ParseSlotTypes postfix：角色槽位表含某声明的来源槽时，追加该声明的 bit（按 bit 升序，双端确定性一致）；
    ///  - Item 构造 postfix：物品标签/identifier 命中声明时，把来源槽位改写为新 bit（Item.allowedSlots 与 Pickable.AllowedSlots 双同步）；
    ///  - 客户端 transpiler：个人装备区掩码常量 504 → call GetPersonalSlotMaskAtRuntime()（504|全部注册 bit，运行时求值）；
    ///  - AI 前缀：HasEquippedItem/GetEquippedItem 请求掩码含 OuterClothes 位时并入全部注册 bit（AI 才能"看见"自定义槽）。
    ///
    /// 性能：布局 postfix 每帧执行；反射句柄/布局计划/掩码全部静态缓存，槽位尺寸仅在 UI 缩放变化时重算，
    /// 背景框扩展带"已覆盖"短路检查——低配机与联机场景无额外负担。
    /// ⚠️ 本文件与原「潜水服独立槽」框架代码同源：**两者不能同时启用**（同命名空间/Harmony id）。
    /// </summary>
    public static class FrameworkInfo
    {
        public const string Version = "1.0.0";
        public const int VanillaPersonalSlotsMask = 504; // Head|InnerClothes|OuterClothes|Headset|Card|Bag
        public const int FirstCustomBit = 16384;         // Unstable 的 1024~8192 已用于义肢槽。
        public const int MaxCustomBit = 1 << 30;         // bit31 是符号位，不可用
    }

    /// <summary>
    /// 一个自定义服装槽的声明。
    /// </summary>
    public class SlotDef
    {
        public int Bit;                 // 槽位标志位（16384/32768/...，必须是 2 的幂）
        public string Id;               // 诊断用标识
        public string[] Tags;           // 物品标签（命中即迁移），大小写不敏感
        public string[] Identifiers;    // 可选：物品 identifier 精确匹配（与 Tags 取并集，命中其一即迁移）
        public int FromMask;            // 来源槽掩码（默认 OuterClothes=32），命中的槽位被改写为新 bit
        public int Priority;            // 多声明命中同一物品时，小的优先（0 最高）
        public int Row = 1;             // 布局行：≥1 为覆写网格行（1=ID卡上方第一格，默认）；0 = 与 align 吸附槽同排（原版装备行）
        public int Col = 0;             // 布局列：0 = ID 卡基准列；正数向右、负数向左（负列需 v1.0.1+）
        public int YOff = 0;            // 垂直微调（像素）：负值=上移，正值=下移
        public string Align = null;     // 可选：吸附到原版槽位列（如 "Headset"/"Head"/"Bag"）；X = 原版列 + col 偏移（col=0 精确吸附）
        public bool IsBuiltin = false;  // 内置声明（潜水服槽 1024）不参与布局覆写
    }

    /// <summary>
    /// 槽位声明注册表。全部补丁逻辑的唯一数据源。
    /// 追加顺序按 bit 升序 → 客户端/服务端槽位表完全确定，与模组加载顺序无关。
    /// </summary>
    public static class SlotRegistry
    {
        private static readonly List<SlotDef> Slots = new List<SlotDef>();
        private static readonly object Lock = new object();
        private static int revision = 0;          // 注册表版本号，注册变化时递增（供缓存失效判断）
        private static int cachedAllBits = -1;
        private static int cachedAllBitsRev = -1;
        private static List<SlotDef> cachedDeclared = null;
        private static int cachedDeclaredRev = -1;

        /// <summary>注册一个槽位声明。bit 冲突/非法时拒绝并告警。</summary>
        public static bool Register(SlotDef def)
        {
            if (def == null) { return false; }
            bool hasTags = def.Tags != null && def.Tags.Length > 0;
            bool hasIds = def.Identifiers != null && def.Identifiers.Length > 0;
            if (!hasTags && !hasIds) { return false; }
            if (!IsValidBit(def.Bit))
            {
                Log("[框架] 拒绝非法 bit=" + def.Bit + " (id=" + def.Id + ")，必须为 16384~2^30 的 2 的幂");
                return false;
            }
            lock (Lock)
            {
                if (Slots.Any(s => s.Bit == def.Bit))
                {
                    Log("[框架] 拒绝重复 bit=" + def.Bit + " (id=" + def.Id + ")，已存在：" + Slots.First(s => s.Bit == def.Bit).Id);
                    return false;
                }
                Slots.Add(def);
                Slots.Sort((a, b) => a.Bit.CompareTo(b.Bit)); // 按 bit 升序：追加顺序确定
                revision++; // M17：缓存失效
                Log("[框架] 已注册槽位 bit=" + def.Bit + " id=" + def.Id + " tags=" + string.Join(",", def.Tags ?? new string[0]) + " identifiers=" + string.Join(",", def.Identifiers ?? new string[0]) + " from=" + def.FromMask + " row=" + def.Row + " col=" + def.Col);
                return true;
            }
        }

        /// <summary>
        /// M27：会话卸载（回主菜单）时清空声明注册表——下次进入会话全量重扫 XML，
        /// 保证用户中途修改的声明一定生效，并避免泄漏程序集中的旧注册表与新扫描叠加
        /// （重复 bit 被拒后新旧声明混用的隐患）。
        /// </summary>
        public static void ClearForReload()
        {
            lock (Lock)
            {
                int n = Slots.Count;
                if (n == 0) { return; }
                Slots.Clear();
                revision++;
                cachedAllBits = -1;
                cachedAllBitsRev = -1;
                cachedDeclared = null;
                cachedDeclaredRev = -1;
                Log("[框架] 声明注册表已清空（" + n + " 条），等待下次会话重新扫描");
            }
        }

        public static bool IsValidBit(int bit)
        {
            if (bit < FrameworkInfo.FirstCustomBit || bit > FrameworkInfo.MaxCustomBit) { return false; }
            return (bit & (bit - 1)) == 0; // 2 的幂
        }

        /// <summary>全部注册 bit 的按位或。</summary>
        public static int AllBits()
        {
            lock (Lock)
            {
                int mask = 0;
                foreach (var s in Slots) { mask |= s.Bit; }
                return mask;
            }
        }

        /// <summary>个人装备区掩码 = 原版 504 | 全部注册 bit。</summary>
        public static int PersonalSlotMask()
        {
            return FrameworkInfo.VanillaPersonalSlotsMask | AllBits();
        }

        /// <summary>按 bit 升序返回全部声明（供 ParseSlotTypes 追加使用，保证双端顺序一致）。</summary>
        public static List<SlotDef> GetSlotsByBit()
        {
            lock (Lock) { return new List<SlotDef>(Slots); } // Slots 已按 bit 排序
        }

        /// <summary>按 (Priority, Bit) 排序返回全部声明（供物品迁移匹配使用）。</summary>
        public static List<SlotDef> GetSlotsByPriority()
        {
            lock (Lock)
            {
                var list = new List<SlotDef>(Slots);
                list.Sort((a, b) =>
                {
                    int c = a.Priority.CompareTo(b.Priority);
                    return c != 0 ? c : a.Bit.CompareTo(b.Bit);
                });
                return list;
            }
        }

        /// <summary>外部声明（非内置）按 bit 升序；M8 布局覆写只作用于这些槽。</summary>
        public static List<SlotDef> GetDeclaredSlots()
        {
            lock (Lock) { return new List<SlotDef>(Slots.Where(s => !s.IsBuiltin)); }
        }

        /// <summary>M17：注册表版本号（注册变化时递增）。</summary>
        public static int Revision
        {
            get { lock (Lock) { return revision; } }
        }

        /// <summary>M17：全部注册 bit 的按位或（带缓存，仅在注册变化时重算）。</summary>
        public static int AllBitsCached()
        {
            lock (Lock)
            {
                if (cachedAllBitsRev != revision)
                {
                    int mask = 0;
                    foreach (var s in Slots) { mask |= s.Bit; }
                    cachedAllBits = mask;
                    cachedAllBitsRev = revision;
                }
                return cachedAllBits;
            }
        }

        /// <summary>M17：外部声明列表（带缓存；调用方不得修改返回列表）。</summary>
        public static List<SlotDef> GetDeclaredSlotsCached()
        {
            lock (Lock)
            {
                if (cachedDeclaredRev != revision)
                {
                    cachedDeclared = new List<SlotDef>(Slots.Where(s => !s.IsBuiltin));
                    cachedDeclaredRev = revision;
                }
                return cachedDeclared;
            }
        }

        /// <summary>按 (Priority, Bit) 匹配：Identifiers 或 Tags 第一个命中的声明；无命中返回 null。</summary>
        public static SlotDef Match(string identifier, IList<string> tags)
        {
            foreach (var def in GetSlotsByPriority())
            {
                if (def.Identifiers != null && identifier != null && identifier.Length > 0)
                {
                    foreach (var id in def.Identifiers)
                    {
                        if (string.Equals(identifier, id, StringComparison.OrdinalIgnoreCase)) { return def; }
                    }
                }
                if (def.Tags != null)
                {
                    foreach (var t in tags)
                    {
                        foreach (var dt in def.Tags)
                        {
                            if (string.Equals(t, dt, StringComparison.OrdinalIgnoreCase)) { return def; }
                        }
                    }
                }
            }
            return null;
        }

        /// <summary>掩码中每个置位 bit 的数值（1..bit30）。</summary>
        public static IEnumerable<int> BitsOf(int mask)
        {
            for (int i = 0; i < 31; i++)
            {
                int bit = 1 << i;
                if ((mask & bit) != 0) { yield return bit; }
            }
        }

        /// <summary>
        /// 来源槽掩码中的位是否包含槽位表字符串 s（如 "OuterClothes" 或数值 "1024"）。
        /// 原版枚举位用 Enum.GetName；自定义位没有枚举名，回退数值字符串比较。
        /// </summary>
        public static bool IsFromName(string s, int fromMask)
        {
            foreach (int bit in BitsOf(fromMask))
            {
                string name;
                try { name = Enum.GetName(typeof(Barotrauma.InvSlotType), (Barotrauma.InvSlotType)bit); }
                catch { name = null; }
                if (name == null) { name = bit.ToString(); }
                if (string.Equals(s, name, StringComparison.OrdinalIgnoreCase)) { return true; }
            }
            return false;
        }

        // ---- 调试开关（M24）----
        // true 时控制台输出全部调试信息；false 时只保留启动信息与错误。
        // 开启方式（任一）：
        //   1. Lua 全局脚本调用 DeepSlotExpanded.SetDebug(true)
        //   2. 游戏安装目录放置空文件 dda_debug.txt（启动后自动检测一次）
        public static bool DebugMode = false;
        internal static bool debugFileChecked = false;

        private static void CheckDebugFile()
        {
            if (debugFileChecked) { return; }
            debugFileChecked = true;
            try
            {
                string p = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "dda_debug.txt");
                if (System.IO.File.Exists(p)) { DebugMode = true; }
            }
            catch { }
        }

        /// <summary>统一日志：LuaCs 控制台优先，Console 兜底。用于启动信息与错误（始终输出）。</summary>
        public static void Log(string msg)
        {
            try
            {
                Barotrauma.LuaCsSetup.PrintCsMessage("[DeepSlotExpanded] " + msg);
                return;
            }
            catch { }
            try { Console.WriteLine("[DeepSlotExpanded] " + msg); } catch { }
        }

        /// <summary>M24：调试信息——仅在 DebugMode = true 时输出到控制台。</summary>
        public static void LogDebug(string msg)
        {
            CheckDebugFile();
            if (!DebugMode) { return; }
            Log(msg);
        }

        /// <summary>
        /// 落盘诊断日志（DDA 框架联调专用）：把客户端布局补丁的关键状态追加写入
        /// 游戏安装目录的 dda_layout_diag.txt——客户端 PrintCsMessage 只进 F3 控制台、
        /// 服务端日志文件看不到，落盘后才能从文件取证。
        /// M24：与控制台调试信息同受 DebugMode 控制，避免调试期外的文件 IO 开销。
        /// </summary>
        public static void DiagLog(string msg)
        {
            CheckDebugFile();
            if (!DebugMode) { return; }
            try
            {
                string path = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "dda_layout_diag.txt");
                System.IO.File.AppendAllText(path, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg + Environment.NewLine);
            }
            catch { }
        }
    }

    /// <summary>
    /// XML 槽位声明发现（M2）：
    /// 扫描所有已启用内容包根目录的 DeepSlotExpandedSlots.xml，把 &lt;Slot&gt; 声明注册进 SlotRegistry。
    /// 第三方模组零代码即可声明新服装槽。
    /// 格式：
    /// &lt;DeepSlotExpandeds&gt;
    ///   &lt;Slot bit="16384" id="belt" tags="..." identifiers="toolbelt" from="Bag" priority="0" row="1" col="0" /&gt;
    /// &lt;/DeepSlotExpandeds&gt;
    /// bit 必填；tags 与 identifiers 至少其一；from 缺省 OuterClothes；priority 缺省 0；
    /// row 缺省 1（装备行上方第一排；0 = 与 align 吸附槽同排）；col 缺省自动填空位（M8）；
    /// align 可选（如 "Bag"/"Head"）：X = 原版该列 + col 偏移。
    /// </summary>
    public static class SlotXmlDiscovery
    {
        public const string FileName = "DeepSlotExpandedSlots.xml";

        public static void ScanEnabledPackages()
        {
            try
            {
                Barotrauma.LuaCsSetup setup = Barotrauma.LuaCsSetup.Instance;
                if (setup == null) { SlotRegistry.LogDebug("[发现] LuaCsSetup.Instance 不可用，跳过 XML 扫描"); return; }

                var packages = ContentPackageManager.EnabledPackages.Regular;
                int total = 0;
                foreach (var pkg in packages)
                {
                    string dir = null;
                    try { dir = pkg.Dir; } catch { dir = null; }
                    if (string.IsNullOrEmpty(dir)) { continue; }
                    string path = System.IO.Path.Combine(dir, FileName);
                    if (!System.IO.File.Exists(path)) { continue; }

                    int loaded = 0;
                    try
                    {
                        var doc = XDocument.Load(path);
                        var root = doc.Root;
                        if (root == null || root.Name.LocalName != "DeepSlotExpandeds")
                        {
                            SlotRegistry.LogDebug("[发现] " + path + " 根元素不是 <DeepSlotExpandeds>，跳过");
                            continue;
                        }
                        foreach (var el in root.Elements("Slot"))
                        {
                            int bit;
                            if (!int.TryParse((string)el.Attribute("bit"), out bit))
                            {
                                SlotRegistry.Log("[发现] " + path + " 中 bit 属性非法，跳过一条");
                                continue;
                            }
                            string tagsStr = (string)el.Attribute("tags");
                            var tags = (tagsStr ?? "").Split(',')
                                .Select(t => t.Trim())
                                .Where(t => t.Length > 0)
                                .ToArray();
                            string idStr = (string)el.Attribute("identifiers");
                            var identifiers = (idStr ?? "").Split(',')
                                .Select(t => t.Trim())
                                .Where(t => t.Length > 0)
                                .ToArray();
                            if (tags.Length == 0 && identifiers.Length == 0)
                            {
                                SlotRegistry.Log("[发现] " + path + " 中 bit=" + bit + " 既无 tags 也无 identifiers，跳过");
                                continue;
                            }
                            string fromStr = (string)el.Attribute("from");
                            int fromMask = string.IsNullOrEmpty(fromStr)
                                ? (int)Barotrauma.InvSlotType.OuterClothes
                                : ParseMask(fromStr);
                            int priority;
                            int.TryParse((string)el.Attribute("priority") ?? "0", out priority);
                            int row;
                            if (!int.TryParse((string)el.Attribute("row") ?? "1", out row)) { row = 1; }
                            int col;
                            if (!int.TryParse((string)el.Attribute("col") ?? "0", out col)) { col = 0; }
                            int yoff;
                            if (!int.TryParse((string)el.Attribute("yoff") ?? "0", out yoff)) { yoff = 0; }
                            string alignStr = (string)el.Attribute("align");
                            string align = string.IsNullOrEmpty(alignStr) ? null : alignStr.Trim();
                            string id = (string)el.Attribute("id") ?? ("bit" + bit);
                            if (SlotRegistry.Register(new SlotDef
                            {
                                Bit = bit,
                                Id = id,
                                Tags = tags.Length > 0 ? tags : null,
                                Identifiers = identifiers.Length > 0 ? identifiers : null,
                                FromMask = fromMask,
                                Priority = priority,
                                Row = row,
                                Col = col,
                                YOff = yoff,
                                Align = align
                            }))
                            {
                                loaded++;
                            }
                        }
                    }
                    catch (Exception e)
                    {
                        SlotRegistry.Log("[发现] 解析失败 " + path + ": " + e.Message);
                        continue;
                    }
                    if (loaded > 0)
                    {
                        SlotRegistry.Log("[发现] 已从 " + (pkg.Name ?? dir) + " 加载 " + loaded + " 条槽位声明");
                        total += loaded;
                    }
                }
                if (total > 0) { SlotRegistry.Log("[发现] XML 扫描完成，共加载 " + total + " 条外部声明"); }
            }
            catch (Exception e)
            {
                SlotRegistry.Log("[发现] 扫描启用包失败: " + e);
            }
        }

        /// <summary>
        /// 解析 from 掩码字符串："OuterClothes" / "Bag" / "32" / "OuterClothes|Bag" / "32|256"。
        /// 解析失败或为空 → 返回 0，由调用方回退 OuterClothes。
        /// </summary>
        public static int ParseMask(string s)
        {
            int mask = 0;
            foreach (var part in s.Split('|'))
            {
                string p = part.Trim();
                if (p.Length == 0) { continue; }
                int num;
                if (int.TryParse(p, out num)) { mask |= num; continue; }
                try
                {
                    Barotrauma.InvSlotType v;
                    if (Enum.TryParse<Barotrauma.InvSlotType>(p, true, out v)) { mask |= (int)v; }
                }
                catch { }
            }
            return mask;
        }
    }

    /// <summary>
    /// Lua API（M4）：向 LuaCs 全局环境注册 DeepSlotExpanded 表，Lua 模组可动态声明槽位。
    /// 用法：
    ///   DeepSlotExpanded.RegisterSlot({ bit=16384, id="x", tags={"a","b"}, identifiers="toolbelt", from="Bag", priority=0, row=1, col=0 })
    /// tags/identifiers 可以是逗号分隔字符串或字符串数组；from 缺省 OuterClothes；priority 缺省 0；
    /// row 缺省 1（装备行上方第一排；0 = 与 align 吸附槽同排）；col 缺省自动填空位（M8）；align 可选。
    /// bit 冲突/非法时 Register 会拒绝并输出告警日志（冲突日志）。
    /// </summary>
    [MoonSharpUserData]
    public static class SlotLuaApi
    {
        public static bool RegisterSlot(Table t)
        {
            try
            {
                if (t == null) { SlotRegistry.Log("[Lua] RegisterSlot 参数不是 table"); return false; }
                DynValue vBit = t.Get("bit");
                int bit = vBit.IsNil() ? 0 : (int)vBit.Number;
                string id = t.Get("id").String ?? ("bit" + bit);
                string[] tags = ToArray(t.Get("tags"));
                string[] identifiers = ToArray(t.Get("identifiers"));
                string fromStr = t.Get("from").String;
                int fromMask = string.IsNullOrEmpty(fromStr)
                    ? (int)Barotrauma.InvSlotType.OuterClothes
                    : SlotXmlDiscovery.ParseMask(fromStr);
                DynValue vPri = t.Get("priority");
                int priority = vPri.IsNil() ? 0 : (int)vPri.Number;
                DynValue vRow = t.Get("row");
                int row = vRow.IsNil() ? 1 : Math.Max(0, (int)vRow.Number);
                DynValue vCol = t.Get("col");
                int col = vCol.IsNil() ? 0 : (int)vCol.Number;
                DynValue vYoff = t.Get("yoff");
                int yoff = vYoff.IsNil() ? 0 : (int)vYoff.Number;
                string alignStr = t.Get("align").String;
                string align = string.IsNullOrEmpty(alignStr) ? null : alignStr.Trim();
                return SlotRegistry.Register(new SlotDef
                {
                    Bit = bit,
                    Id = id,
                    Tags = tags,
                    Identifiers = identifiers,
                    FromMask = fromMask,
                    Priority = priority,
                    Row = row,
                    Col = col,
                    YOff = yoff,
                    Align = align
                });
            }
            catch (Exception e)
            {
                SlotRegistry.Log("[Lua] RegisterSlot 失败: " + e.Message);
                return false;
            }
        }

        /// <summary>M24：开关调试信息（true=控制台输出全部调试信息；false=只保留启动信息与错误）。</summary>
        public static void SetDebug(bool enabled)
        {
            SlotRegistry.debugFileChecked = true; // 跳过文件自动检测，以显式调用为准
            SlotRegistry.DebugMode = enabled;
            SlotRegistry.Log("DebugMode = " + enabled);
        }

        /// <summary>M24：查询当前调试开关状态。</summary>
        public static bool GetDebug()
        {
            return SlotRegistry.DebugMode;
        }

        private static string[] ToArray(DynValue v)
        {
            if (v == null || v.IsNil()) { return null; }
            if (v.Type == DataType.String)
            {
                var arr = (v.String ?? "").Split(',')
                    .Select(s => s.Trim())
                    .Where(s => s.Length > 0)
                    .ToArray();
                return arr.Length > 0 ? arr : null;
            }
            if (v.Type == DataType.Table)
            {
                var list = new List<string>();
                foreach (var item in v.Table.Values)
                {
                    if (item != null && !item.IsNil() && !string.IsNullOrEmpty(item.String))
                    {
                        list.Add(item.String);
                    }
                }
                return list.Count > 0 ? list.ToArray() : null;
            }
            return null;
        }
    }

    /// <summary>
    /// 游戏内置 LuaCs 的插件接口（不是空接口！）：
    /// 继承 IDisposable、IEventPluginPreInitialize、IEventPluginInitialize、IEventPluginLoadCompleted，
    /// 必须实现 Dispose/PreInitPatching/Initialize(实例)/OnLoadCompleted。
    /// 加载后由 PluginManagementService 实例化并按生命周期调用。
    /// </summary>
    public class DeepSlotExpandedPlugin : Barotrauma.LuaCs.IAssemblyPlugin
    {
        private const string HarmonyId = "net.diving.suit.slot.mod";
        private static bool initialized = false;
        private static bool initInProgress = false;     // M27：初始化中标志（防止并发重入）
        private static readonly object initLock = new object();
        private static Harmony c_harmony = null;        // M27：保留实例供卸载解挂

        public void PreInitPatching() { }
        public void Initialize() { ApplyPatches(); }
        public void OnLoadCompleted() { TryRegisterLuaApi(); }   // Lua 脚本此时已执行，Lua 全局可用

        /// <summary>
        /// M27：LuaCs 生命周期对称化。回主菜单时 RunStateRunning_OnExit → StopRunningPackages →
        /// 本方法被调用。此前为空实现，导致：补丁不解挂（旧 collectible 程序集被 Harmony 引用钉住
        /// 无法回收，旧 postfix 残留叠加）、声明注册表不清空、一次性标志不复位——读档重载路径
        /// 完全依赖泄漏状态，任何一环异常都表现为"回主菜单再读档后额外槽位全部消失"。
        /// 现在完整 teardown：解挂全部补丁 + 清空注册表 + 复位一次性标志，下次进入会话全量重初始化。
        /// </summary>
        public void Dispose()
        {
            Teardown();
        }

        private static void Teardown()
        {
            lock (initLock)
            {
                // M27：c_harmony != null 说明初始化进行到一半（部分补丁已挂）——同样需要解挂
                if (!initialized && !initInProgress && c_harmony == null) { return; }
            }
            try
            {
                if (c_harmony != null)
                {
                    c_harmony.UnpatchSelf();
                    c_harmony = null;
                }
            }
            catch (Exception e) { SlotRegistry.Log("卸载解挂补丁失败: " + e); }
            lock (initLock)
            {
                initialized = false;
                initInProgress = false;
            }
            luaApiDone = false;
            luaApiWarned = false;
            slotIconsDone = false;
            diagEntryLogged = false;
            diagPostfixEntered = false;
            SlotRegistry.ClearForReload();
            SlotRegistry.Log("框架已卸载（回主菜单），下次进入会话时自动重新初始化");
        }

        /// <summary>
        /// M27：初始化与状态严格绑定——只有扫描+全部补丁成功才置 initialized=true；
        /// 中途失败保持 false，由自愈入口（ParseSlotTypes 前缀 / 主菜单 StartGame/LoadGame 后缀）
        /// 在下一次调用时自动重试。此前 initialized 在进入 try 之前就置 true，读档路径上
        /// 任何一次初始化中途异常都会永久杀死框架且不再重试（报错只进控制台，诊断文件无痕迹）。
        /// </summary>
        public static void ApplyPatches()
        {
            lock (initLock)
            {
                if (initialized || initInProgress) { return; }
                initInProgress = true;
            }
            bool ok = false;
            try
            {
                SlotRegistry.DiagLog("框架初始化开始（M27：失败可自愈重试）");
                SlotXmlDiscovery.ScanEnabledPackages();      // 从各启用包根目录读取 DeepSlotExpandedSlots.xml
                c_harmony = new Harmony(HarmonyId);
                PatchShared(c_harmony);
                PatchClientOnly(c_harmony);
                TryRegisterLuaApi();                         // Lua API（可能因 Lua 未初始化而延后重试）
                ok = true;
                SlotRegistry.DiagLog("客户端补丁已尝试应用（PatchClientOnly 完成：SetSlotPositions/HideSlot/CBF/lambda/SubEditor）");
                SlotRegistry.Log("服装槽框架补丁已应用 v" + FrameworkInfo.Version + "，注册槽位：" + string.Join(",", SlotRegistry.GetSlotsByBit().Select(s => s.Id + "@" + s.Bit)));
            }
            catch (Exception e)
            {
                SlotRegistry.Log("初始化失败（下次入口自动重试）: " + e);
                SlotRegistry.DiagLog("框架初始化失败（落盘取证）: " + e);
            }
            finally
            {
                lock (initLock)
                {
                    initialized = ok;
                    initInProgress = false;
                }
            }
        }

        /// <summary>
        /// M27：自愈入口——未初始化/上次初始化失败时补跑 ApplyPatches（幂等：已初始化时
        /// 一次布尔判断即返回，每次角色物品栏解析的开销可忽略）。挂在双端 ParseSlotTypes
        /// 前缀与客户端主菜单 StartGame/LoadGame 后缀，保证在角色生成前生效。
        /// </summary>
        public static void SelfHealPrefix()
        {
            ApplyPatches();
        }

        /// <summary>
        /// M4/M6：把 SlotLuaApi 注册为 MoonSharp 静态 userdata，挂到 LuaCs 全局脚本的 DeepSlotExpanded 表上。
        /// 时机：插件 Initialize 时 Lua 脚本尚未执行（setup.Lua 为 null）→ 在 OnLoadCompleted 重试，
        /// 并由 ParseSlotTypes/ItemCtor postfix 惰性重试，成功一次后短路。
        /// </summary>
        private static bool luaApiDone = false;
        private static bool luaApiWarned = false;

        private static void TryRegisterLuaApi()
        {
            if (luaApiDone) { return; }
            try
            {
                Barotrauma.LuaCsSetup setup = Barotrauma.LuaCsSetup.Instance;
                if (setup == null) { return; }
                Script lua = setup.Lua;
                if (lua == null)
                {
                    if (!luaApiWarned) { SlotRegistry.LogDebug("Lua 全局脚本尚不可用，稍后自动重试注册"); luaApiWarned = true; }
                    return;
                }
                // 注意：SlotLuaApi 是静态类，不能作 RegisterType<T> 的泛型实参（CS0718）；
                // 静态 userdata 只需 [MoonSharpUserData] + CreateStatic。
                lua.Globals["DeepSlotExpanded"] = UserData.CreateStatic(typeof(SlotLuaApi));
                luaApiDone = true;
                SlotRegistry.Log("Lua API 已注册：DeepSlotExpanded.RegisterSlot({bit=..., id=..., tags={...}, identifiers=..., from=..., priority=...})");
            }
            catch (Exception e)
            {
                SlotRegistry.Log("Lua API 注册失败: " + e);
            }
        }

        // ===================== 客户端+服务端共用的补丁 =====================

        private static void PatchShared(Harmony harmony)
        {
            // 1) CharacterInventory.ParseSlotTypes: 按注册表追加自定义槽位
            var ciType = AccessTools.TypeByName("Barotrauma.CharacterInventory");
            if (ciType != null)
            {
                var parse = FindMethodByName(ciType, "ParseSlotTypes");
                if (parse != null)
                {
                    // M27：自愈前缀——角色物品栏解析是声明槽位表生效的最晚时机，
                    // 若 LuaCs 重载路径上插件初始化被跳过或中途失败，在此补跑（幂等）。
                    // 注意：本次调用内的 postfix 可能尚未挂上（Harmony 下次调用生效），
                    // 该角色可能缺自定义槽；后续角色与主菜单自愈入口保证最终一致。
                    harmony.Patch(parse,
                        prefix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(SelfHealPrefix)),
                        postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(ParseSlotTypesPostfix)));
                }
            }

            // 2) Item 主构造函数(首参数为 Rectangle): 标签命中的物品槽位迁移
            var itemType = AccessTools.TypeByName("Barotrauma.Item");
            if (itemType != null)
            {
                ConstructorInfo ctor = null;
                try
                {
                    ctor = itemType.GetConstructors(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
                        .FirstOrDefault(c =>
                        {
                            var p = c.GetParameters();
                            return p.Length == 5 && p[0].ParameterType.Name == "Rectangle";
                        });
                }
                catch { ctor = null; }
                if (ctor != null)
                {
                    harmony.Patch(ctor, postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(ItemCtorPostfix)));
                }
            }

            // 3) AI 槽位识别补丁（v1.2.0 逻辑泛化到全部注册 bit）
            PatchAI(harmony);
        }

        /// <summary>
        /// 游戏 AI 按槽位掩码查询"是否装备了某类物品"的两个中央入口：
        ///  - Character.HasEquippedItem(Item, InvSlotType?, Func&lt;InvSlotType,bool&gt;)
        ///  - Character.GetEquippedItem(Identifier, InvSlotType?)
        /// 两者内部都是 slotType.HasFlag(实际槽类型)：请求掩码（如 48/56/32）不含自定义 bit → 自定义槽物品被跳过。
        /// 前缀把"含 OuterClothes 位"的请求掩码并入全部注册 bit，语义不变且对原版完全兼容。
        /// （刻意不并入纯 Head/RightHand 等查询——避免 AI 把自定义槽物品误认为头盔/手持物。）
        /// </summary>
        private static void PatchAI(Harmony harmony)
        {
            var chrType = AccessTools.TypeByName("Barotrauma.Character");
            if (chrType == null) { return; }

            var hasEquippedItem = AccessTools.Method(chrType, "HasEquippedItem",
                new[]
                {
                    typeof(Barotrauma.Item),
                    typeof(Barotrauma.InvSlotType?),
                    typeof(Func<Barotrauma.InvSlotType, bool>)
                });
            if (hasEquippedItem != null)
            {
                harmony.Patch(hasEquippedItem, prefix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(HasEquippedItemPrefix)));
            }

            var getEquippedItem = AccessTools.Method(chrType, "GetEquippedItem",
                new[]
                {
                    typeof(Barotrauma.Identifier),
                    typeof(Barotrauma.InvSlotType?)
                });
            if (getEquippedItem != null)
            {
                harmony.Patch(getEquippedItem, prefix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(GetEquippedItemPrefix)));
            }

            if (hasEquippedItem != null && getEquippedItem != null)
            {
                SlotRegistry.Log("AI 槽位识别补丁已应用 (HasEquippedItem + GetEquippedItem)");
            }
        }

        // ===================== 仅客户端的补丁（服务端无 UI，自动跳过） =====================

        private static void PatchClientOnly(Harmony harmony)
        {
            var ciType = AccessTools.TypeByName("Barotrauma.CharacterInventory");
            SlotRegistry.DiagLog("PatchClientOnly 开始: ciType=" + (ciType != null));
            if (ciType != null)
            {
                // ---- 类型解剖探针：运行时类型来自哪个程序集 + 槽相关方法清单 ----
                try
                {
                    SlotRegistry.DiagLog("ciType 程序集: " + ciType.Assembly.FullName + " @ " + ciType.Assembly.Location);
                    var all = new System.Collections.Generic.List<string>();
                    for (var t = ciType; t != null && t != typeof(object); t = t.BaseType)
                    {
                        foreach (var m in t.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                        {
                            if (m.Name.Contains("Slot") || m.Name == "DrawOwn" || m.Name == "CreateSlots")
                            {
                                all.Add(t.Name + "." + m.Name + "(" + string.Join(",", System.Array.ConvertAll(m.GetParameters(), p => p.ParameterType.Name)) + ")");
                            }
                        }
                    }
                    SlotRegistry.DiagLog("槽相关方法清单: " + (all.Count == 0 ? "(空!)" : string.Join(" | ", all)));
                }
                catch (Exception te)
                {
                    SlotRegistry.DiagLog("类型解剖异常: " + te);
                }

                var ssp = FindMethodByName(ciType, "SetSlotPositions");
                var hide = FindMethodByName(ciType, "HideSlot");
                var cbf = FindMethodByName(ciType, "CalculateBackgroundFrame");
                SlotRegistry.DiagLog("PatchClientOnly 目标: ssp=" + (ssp != null) + " hide=" + (hide != null) + " cbf=" + (cbf != null));

                PatchTranspiler(harmony, ssp);
                PatchTranspiler(harmony, hide);

                // M8：postfix 接管声明槽布局（第二排 / row-col 定制）；M22：prefix 临时隔离声明槽
                // 的个人槽计数，防止 1-10 物品栏被防重叠约束整体左移一格
                if (ssp != null)
                {
                    try
                    {
                        var patched = harmony.Patch(ssp,
                            prefix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(SetSlotPositionsLayoutPrefix)),
                            postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(SetSlotPositionsLayoutPostfix)));
                        SlotRegistry.DiagLog("SetSlotPositions prefix+postfix patch 结果: " + (patched != null));
                    }
                    catch (Exception pe)
                    {
                        SlotRegistry.DiagLog("SetSlotPositions postfix patch 异常: " + pe);
                    }
                }

                // M20：CreateSlots postfix。CreateSlots 被大量路径单独调用（互动视图打开/关闭、
                // 移动物品 RemoveItem、子背包切换、Lua 刷新钩子等），都不经过 SetSlotPositions：
                // 声明槽矩形会被原版按 ItemContainer 贴图重新扩宽（如已装备胸挂 → 槽位变大且残留）。
                // 挂上后所有 CreateSlots 入口统一走同一布局覆写（位置+尺寸），与 SetSlotPositions 一致。
                try
                {
                    int csPatched = 0;
                    for (var ht = ciType; ht != null && ht != typeof(object); ht = ht.BaseType)
                    {
                        foreach (var m in ht.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly))
                        {
                            if (m.Name != "CreateSlots" || m.GetParameters().Length != 0) { continue; }
                            try
                            {
                                harmony.Patch(m, postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(CreateSlotsPostfix)));
                                csPatched++;
                                SlotRegistry.DiagLog("CreateSlots postfix 已挂: " + ht.Name + "::" + m.Name);
                            }
                            catch (Exception ce2)
                            {
                                SlotRegistry.DiagLog("CreateSlots postfix 挂载失败(" + ht.Name + "): " + ce2.Message);
                            }
                        }
                    }
                    SlotRegistry.DiagLog("CreateSlots postfix patch 计数: " + csPatched);
                }
                catch (Exception cse)
                {
                    SlotRegistry.DiagLog("CreateSlots patch 异常: " + cse);
                }

                // M9：CalculateBackgroundFrame 会重算背景框覆盖扩展，挂 postfix 重新扩展
                if (cbf != null)
                {
                    try
                    {
                        var patched2 = harmony.Patch(cbf, postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(CalculateBackgroundFramePostfix)));
                        SlotRegistry.DiagLog("CBF postfix patch 结果: " + (patched2 != null));
                    }
                    catch (Exception pe2)
                    {
                        SlotRegistry.DiagLog("CBF postfix patch 异常: " + pe2);
                    }
                }

                // HideSlot 兜底 postfix：新版构建里 vanilla HideSlot(i) 的"个人槽掩码"判断
                // 若未把自定义 bit 算入（transpiler 的 504 模式在新 IL 中可能匹配不上），
                // 会把自定义槽隐藏 → 什么都对但槽位不画。凡声明 bit 的槽强制不隐藏。
                try
                {
                    var hideMethods = new System.Collections.Generic.List<MethodInfo>();
                    for (var ht = ciType; ht != null && ht != typeof(object); ht = ht.BaseType)
                    {
                        foreach (var m in ht.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                        {
                            if (m.Name == "HideSlot" && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(int))
                            {
                                hideMethods.Add(m);
                            }
                        }
                    }
                    foreach (var hm in hideMethods)
                    {
                        try
                        {
                            harmony.Patch(hm, postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(HideSlotPostfix)));
                            SlotRegistry.DiagLog("HideSlot postfix 已挂: " + hm.DeclaringType.Name + "::" + hm.Name);
                        }
                        catch (Exception he)
                        {
                            SlotRegistry.DiagLog("HideSlot postfix 挂载失败: " + he.Message);
                        }
                    }
                    if (hideMethods.Count == 0) { SlotRegistry.DiagLog("HideSlot 方法未找到（异常！）"); }
                }
                catch (Exception hle)
                {
                    SlotRegistry.DiagLog("HideSlot 查找异常: " + hle);
                }

                // M3：SetSlotPositions 里编译器生成的 <>c 静态 lambda（b__19_2/b__19_3）
                // 也用 504 掩码，v1.2.0/M1/M2 均未覆盖（潜在小缺陷），此处一并补上。
                try
                {
                    foreach (var nt in ciType.GetNestedTypes(BindingFlags.Public | BindingFlags.NonPublic))
                    {
                        if (nt.Name != "<>c") { continue; }
                        foreach (var m in nt.GetMethods(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic))
                        {
                            if (m.Name.Contains("SetSlotPositions"))
                            {
                                PatchTranspiler(harmony, m);
                                SlotRegistry.LogDebug("已补丁 lambda 方法: " + m.Name);
                            }
                        }
                    }
                }
                catch (Exception e)
                {
                    SlotRegistry.Log("lambda 补丁失败: " + e.Message);
                }
            }
            var subEditor = AccessTools.TypeByName("Barotrauma.SubEditorScreen");
            if (subEditor != null)
            {
                PatchTranspiler(harmony, FindMethodByName(subEditor, "CreateDummyCharacter"));
            }

            // M27：主菜单入口自愈——StartGame（新开局）/ LoadGame（读取存档）是客户端进入
            // 会话的最早入口，在会话与角色创建之前触发。若 LuaCs 重载路径上插件 Initialize
            // 未执行或中途失败，此处补跑初始化（幂等：已初始化时一次布尔判断即返回）。
            try
            {
                var mmType = AccessTools.TypeByName("Barotrauma.MainMenuScreen");
                int mmPatched = 0;
                if (mmType != null)
                {
                    foreach (var mname in new[] { "StartGame", "LoadGame" })
                    {
                        var mm = FindMethodByName(mmType, mname);
                        if (mm == null) { continue; }
                        harmony.Patch(mm, postfix: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(SelfHealPrefix)));
                        mmPatched++;
                    }
                }
                SlotRegistry.DiagLog("主菜单自愈入口已挂: " + mmPatched + "/2");
            }
            catch (Exception he)
            {
                SlotRegistry.DiagLog("主菜单自愈入口挂载异常: " + he);
            }
            SlotRegistry.DiagLog("PatchClientOnly 完成");
        }

        /// <summary>
        /// 按名字找方法（任意重载、Public/NonPublic/Instance/Static 全查）。
        /// 不用 AccessTools.Method(name)：新版游戏里 SetSlotPositions 等带 CharacterInventory/Layout
        /// 嵌套类型参数，AccessTools 按名查找会落空（实测 ssp/hide/cbf 全 False 导致补丁从未挂上）。
        /// </summary>
        private static MethodInfo FindMethodByName(Type t, string name)
        {
            try
            {
                if (t == null) { return null; }
                return t.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static)
                    .FirstOrDefault(m => m.Name == name);
            }
            catch { return null; }
        }

        private static void PatchTranspiler(Harmony harmony, MethodBase method)
        {
            if (method == null) { return; }
            harmony.Patch(method, transpiler: new HarmonyMethod(typeof(DeepSlotExpandedPlugin), nameof(MaskTranspiler)));
        }

        /// <summary>
        /// M3：把"个人装备区"掩码常量 504（且下一条指令是 box InvSlotType 的位置）替换为
        /// call GetPersonalSlotMaskAtRuntime() —— 运行时求值，M4 的 Lua 动态注册也能立即生效；
        /// 模式匹配保证不会误伤 Homoglyphs 等无关的 504 常量。
        /// </summary>
        public static IEnumerable<CodeInstruction> MaskTranspiler(IEnumerable<CodeInstruction> instructions)
        {
            var list = instructions.ToList();
            var maskGetter = typeof(DeepSlotExpandedPlugin).GetMethod(nameof(GetPersonalSlotMaskAtRuntime), BindingFlags.Public | BindingFlags.Static);
            for (int i = 0; i < list.Count - 1; i++)
            {
                var code = list[i];
                var next = list[i + 1];
                if (code.opcode == OpCodes.Ldc_I4 && code.operand is int v && v == 504
                    && next.opcode == OpCodes.Box && next.operand is Type boxedType
                    && boxedType.FullName == "Barotrauma.InvSlotType")
                {
                    var call = new CodeInstruction(OpCodes.Call, maskGetter);
                    call.MoveLabelsFrom(code);   // 保留分支目标标签
                    call.MoveBlocksFrom(code);   // 保留异常块边界
                    list[i] = call;
                }
            }
            return list;
        }

        /// <summary>运行时求值的个人装备区掩码（被 transpiler 注入到原版布局代码中）；M17 起用缓存掩码。</summary>
        public static int GetPersonalSlotMaskAtRuntime()
        {
            return FrameworkInfo.VanillaPersonalSlotsMask | SlotRegistry.AllBitsCached();
        }

        /// <summary>
        /// M8/M11：声明槽布局覆写（M11 起采用 More Equipment Slots 同款成熟机制）。
        /// 原版 SetSlotPositions 跑完后：
        ///  1) 用真实槽位像素尺寸（SlotSpriteSmall.size × UIScale × AspectRatioAdjustment）与间距（5×GUI.Scale）；
        ///  2) 把声明槽按 row/col 排到原版装备网格下方；
        ///  3) 同步写 SlotPositions + VisualSlot.Rect（InteractRect 外扩半间距）；
        ///  4) 把 personalSlotArea 覆写为全部个人槽的并集 → 原版背景框/可见面板自动包住新行。
        /// M17：反射句柄/计划/掩码全部静态缓存，尺寸仅在缩放变化时重算，背景框扩展带短路检查。
        /// 全程反射处理 XNA 类型（编译环境无 XNA 引用，教训 #3）。
        /// </summary>

        // ===================== M17 布局缓存（静态，一次初始化） =====================
        private static bool layoutCacheInit = false;
        private static PropertyInfo c_slotTypesProp;
        private static FieldInfo c_posField;
        private static FieldInfo c_areaField;
        private static FieldInfo c_vsArrField;
        private static ConstructorInfo c_vecCtor;
        private static ConstructorInfo c_rectCtor;
        private static PropertyInfo c_smallProp;
        private static PropertyInfo c_uiScaleProp;
        private static PropertyInfo c_frameProp;
        private static MethodInfo c_frameSetter;
        private static FieldInfo c_spriteSizeField;
        private static FieldInfo c_vsRectField;
        private static FieldInfo c_vsIrField;
        private static FieldInfo c_vsDirField; // M25：VisualSlot.SubInventoryDir（展开方向）
        private static PropertyInfo c_guiAspectProp;
        private static PropertyInfo c_guiScaleProp;
        private static float c_lastUi = -1f, c_lastAspect = -1f, c_lastGui = -1f;
        private static int c_slotW = 80, c_slotH = 80, c_spacing = 5;
        private static int c_planRev = -1;
        private static Dictionary<int, int[]> c_plan = null;
        private static Dictionary<int, string> c_align = null;   // bit -> align 原版槽名（与 plan 同生命周期）
        private static int c_lastUX = 0, c_lastUY = 0, c_lastUR = 0, c_lastUB = 0;
        private static bool diagEntryLogged = false;   // 落盘诊断：布局 postfix 首帧快照只记一次
        private static bool diagPostfixEntered = false; // 落盘诊断：postfix 入口探针只记一次
        private static bool slotIconsDone = false;      // 渲染层：图标注入只做一次
        private static bool hideDiagLogged = false;     // HideSlot 兜底诊断只记一次（防刷屏）

        /// <summary>M21：沿类型链搜索属性（含静态/非公有）——Type.GetProperty 默认标志搜不到基类静态成员。</summary>
        private static PropertyInfo FindPropInChain(Type t, string name)
        {
            for (var ht = t; ht != null && ht != typeof(object); ht = ht.BaseType)
            {
                PropertyInfo p;
                try { p = ht.GetProperty(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static); }
                catch { p = null; }
                if (p != null) { return p; }
            }
            return null;
        }

        /// <summary>M21：属性取值辅助——静态属性传 null，实例属性传对象（静态属性传实例在部分运行时会抛 ArgumentException）。</summary>
        private static object PropGet(PropertyInfo p, object instance)
        {
            if (p == null) { return null; }
            var gm = p.GetMethod;
            return (gm != null && gm.IsStatic) ? p.GetValue(null) : p.GetValue(instance);
        }

        private static void EnsureLayoutCache(object __instance)
        {
            if (layoutCacheInit) { return; }
            try
            {
                var invType = __instance.GetType();
                c_slotTypesProp = invType.GetProperty("SlotTypes");
                c_posField = FindFieldInChain(invType, "SlotPositions");
                c_areaField = FindFieldInChain(invType, "personalSlotArea");
                c_vsArrField = FindFieldInChain(invType, "visualSlots");
                var posArr = c_posField == null ? null : c_posField.GetValue(__instance) as Array;
                if (posArr != null)
                {
                    var vecType = posArr.GetType().GetElementType();
                    if (vecType != null) { c_vecCtor = vecType.GetConstructor(new[] { typeof(float), typeof(float) }); }
                }
                if (c_areaField != null)
                {
                    var rectType = c_areaField.FieldType;
                    c_rectCtor = rectType.GetConstructor(new[] { typeof(int), typeof(int), typeof(int), typeof(int) });
                }
                // M21：SlotSpriteSmall/UIScale 是基类 Inventory 上的静态属性，
                // GetProperty 默认 BindingFlags 只含 Public|Instance 且不向上搜静态成员 → 绑定失败（diag: smallProp=False），
                // 兜底尺寸 80/80/5 被永久锁死 → 声明槽常驻放大。改为沿类型链搜索并允许静态。
                c_smallProp = FindPropInChain(invType, "SlotSpriteSmall");
                c_uiScaleProp = FindPropInChain(invType, "UIScale");
                c_frameProp = invType.GetProperty("BackgroundFrame");
                if (c_frameProp != null) { c_frameSetter = c_frameProp.GetSetMethod(); }
                var guiType = AccessTools.TypeByName("Barotrauma.GUI");
                if (guiType != null)
                {
                    c_guiAspectProp = guiType.GetProperty("AspectRatioAdjustment", BindingFlags.Public | BindingFlags.Static);
                    c_guiScaleProp = guiType.GetProperty("Scale", BindingFlags.Public | BindingFlags.Static);
                }
                var spr = c_smallProp == null ? null : PropGet(c_smallProp, __instance);
                if (spr != null)
                {
                    c_spriteSizeField = spr.GetType().GetField("size", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                }
                var vsArr0 = c_vsArrField == null ? null : c_vsArrField.GetValue(__instance) as Array;
                if (vsArr0 != null && vsArr0.Length > 0 && vsArr0.GetValue(0) != null)
                {
                    var vsType = vsArr0.GetValue(0).GetType();
                    c_vsRectField = vsType.GetField("Rect", BindingFlags.Public | BindingFlags.Instance);
                    c_vsIrField = vsType.GetField("InteractRect", BindingFlags.Public | BindingFlags.Instance);
                    c_vsDirField = vsType.GetField("SubInventoryDir", BindingFlags.Public | BindingFlags.Instance);
                }
                layoutCacheInit = true;
                SlotRegistry.DiagLog("布局缓存初始化成功: slotTypesProp=" + (c_slotTypesProp != null) + " posField=" + (c_posField != null) + " areaField=" + (c_areaField != null) + " vsArrField=" + (c_vsArrField != null) + " vecCtor=" + (c_vecCtor != null) + " rectCtor=" + (c_rectCtor != null) + " smallProp=" + (c_smallProp != null) + " uiScaleProp=" + (c_uiScaleProp != null) + " frameProp=" + (c_frameProp != null) + " vsRectField=" + (c_vsRectField != null) + " vsIrField=" + (c_vsIrField != null) + " guiAspect=" + (c_guiAspectProp != null) + " guiScale=" + (c_guiScaleProp != null));
            }
            catch (Exception e)
            {
                SlotRegistry.Log("M17 布局缓存初始化失败: " + e.Message);
                SlotRegistry.DiagLog("布局缓存初始化失败: " + e);
                layoutCacheInit = false;
            }
        }

        private static bool c_metricsLocked = false;   // 尺寸锁定：本地玩家面板首次真实计算后冻结（防交互界面缩放污染）
        private static bool metricsFailLogged = false; // 尺寸计算失败诊断只记一次（未锁定期间每帧重试但不刷日志）
        private static int metricsChangeLogs = 0;       // 尺寸重算日志计数（前 12 次）

        private static void UpdateMetricsIfNeeded(object __instance)
        {
            try
            {
                if (c_metricsLocked) { return; }
                // 只有本地操控角色的面板才计算并锁定尺寸——BOT/预览面板一律不碰缓存
                if (!IsControlledCharacterInventory(__instance)) { return; }
                float ui = 1f, aspect = 1f, gui = 1f;
                if (c_uiScaleProp != null) { try { ui = (float)PropGet(c_uiScaleProp, __instance); } catch { } }
                if (c_guiAspectProp != null) { try { aspect = (float)c_guiAspectProp.GetValue(null); } catch { } }
                if (c_guiScaleProp != null) { try { gui = (float)c_guiScaleProp.GetValue(null); } catch { } }
                float sx = 0f, sy = 0f;
                var spr = c_smallProp == null ? null : PropGet(c_smallProp, __instance);
                if (spr != null && c_spriteSizeField != null)
                {
                    var sizeObj = c_spriteSizeField.GetValue(spr);
                    if (sizeObj != null) { sx = FldFloat(sizeObj, "X"); sy = FldFloat(sizeObj, "Y"); }
                }
                // M21：只有拿到真实贴图尺寸才写缓存并永久锁定；
                // 绑定失败（sx/sy=0）时不锁、不写兜底值，未锁定期间每帧重试——
                // 去重逻辑会让失败帧因 ui 未变而永远跳过，故已移除（锁定后本方法第一行即返回）
                bool sizeValid = sx > 0f && sy > 0f && c_smallProp != null && c_uiScaleProp != null;
                if (sizeValid)
                {
                    float mult = ui * aspect;
                    c_slotW = Math.Max(1, (int)(sx * mult));
                    c_slotH = Math.Max(1, (int)(sy * mult));
                    c_spacing = Math.Max(1, (int)(5f * gui));
                    c_metricsLocked = true; // 首次本地真实计算后永久锁定
                }
                c_lastUi = ui; c_lastAspect = aspect; c_lastGui = gui;
                if (sizeValid)
                {
                    if (metricsChangeLogs < 12)
                    {
                        metricsChangeLogs++;
                        SlotRegistry.DiagLog("尺寸锁定#" + metricsChangeLogs + ": 实例=" + __instance.GetHashCode() + " ui=" + ui + " aspect=" + aspect + " gui=" + gui + " sx=" + sx + " sy=" + sy + " slotW=" + c_slotW + " slotH=" + c_slotH + " spacing=" + c_spacing);
                    }
                }
                else if (!metricsFailLogged)
                {
                    metricsFailLogged = true; // 失败只记一次，未锁定期间每帧静默重试
                    SlotRegistry.DiagLog("尺寸计算失败(不锁定,下帧重试): smallProp=" + (c_smallProp != null) + " uiScaleProp=" + (c_uiScaleProp != null) + " spriteSizeField=" + (c_spriteSizeField != null) + " sx=" + sx + " sy=" + sy + " ui=" + ui);
                }
            }
            catch { }
        }

        private static Dictionary<int, int[]> GetPlan()
        {
            int rev = SlotRegistry.Revision;
            if (c_planRev == rev && c_plan != null) { return c_plan; }
            var declared = SlotRegistry.GetDeclaredSlotsCached();
            var plan = new Dictionary<int, int[]>();
            var align = new Dictionary<int, string>();
            foreach (var d in declared)
            {
                int row = Math.Max(0, d.Row);   // row=0 = 与 align 吸附槽同排（原版装备行）；≥1 为装备行上方覆写行
                // col 任意整数：0 = ID 卡基准列，正数向右、负数向左（v1.0.1 起支持负 col 向左延伸）
                int col = d.Col;
                plan[d.Bit] = new[] { row, col, d.YOff };
                if (!string.IsNullOrEmpty(d.Align)) { align[d.Bit] = d.Align; }
            }
            c_plan = plan;
            c_align = align;
            c_planRev = rev;
            return plan;
        }

        // ---- 是否本地操控角色的库存（NPC/BOT 面板不做 UI 干预，走原版） ----
        private static System.Collections.Generic.HashSet<int> diagInstances = new System.Collections.Generic.HashSet<int>();

        /// <summary>
        /// 用 Character.Controlled?.Inventory 与 __instance 引用比较（零反射）。
        /// M23 起仅用于「尺寸缓存计算」把关：UpdateMetricsIfNeeded 只允许本地操控角色的
        /// 面板计算并锁定全局静态尺寸（c_slotW 等），BOT/预览面板一律不碰缓存。
        /// 布局覆写/背景框扩展/取消隐藏已改为「Controlled 非 null + CharacterInventory」门槛，
        /// 覆盖本地与 BOT 双面板（几何按各实例自身坐标求解，互不依赖此判定）。
        /// Controlled 为 null（回合构建早期/读条中）时返回 false——此阶段面板坐标
        /// 全为 0，覆写会把垃圾几何写进矩形并污染静态尺寸缓存。
        /// </summary>
        private static bool IsControlledCharacterInventory(object __instance)
        {
            try
            {
                if (__instance == null) { return false; }
                var controlled = Barotrauma.Character.Controlled;
                if (controlled == null)
                {
                    if (diagInstances.Add(__instance.GetHashCode()))
                    {
                        SlotRegistry.DiagLog("实例判定: hash=" + __instance.GetHashCode() + " 类型=" + __instance.GetType().Name + " controlled=null -> 跳过覆写");
                    }
                    return false;
                }
                var inv = controlled.Inventory;
                bool local = inv != null && ReferenceEquals(inv, __instance);
                if (diagInstances.Add(__instance.GetHashCode()))
                {
                    SlotRegistry.DiagLog("实例判定: hash=" + __instance.GetHashCode() + " 类型=" + __instance.GetType().Name + " controlled=" + (controlled == null ? "null" : controlled.Name) + " controlledInvHash=" + (inv == null ? -1 : inv.GetHashCode()) + " isLocal=" + local);
                }
                return local;
            }
            catch { return false; }
        }

        /// <summary>
        /// M22：SetSlotPositions 前缀。原版 Default 布局按「个人槽数量」在普通槽行右侧预留空间
        /// （CharacterInventory.SetSlotPositions 的防重叠约束），而声明槽被 transpiler 计入
        /// PersonalSlots（504→504|声明bit）→ personalSlotCount 从 6 变 7 → 预留区多占一格
        /// → 1-10 物品栏整体左移一格。
        /// 修复：原版计算前把声明槽类型临时换成 HealthInterface——它不在个人掩码内
        /// （504|1024 不含 512）、不计入 normalSlotCount（被 s != HealthInterface 排除）、
        /// 且位于类型数组末尾，不占用 Any 槽的顺序坐标 → 原版几何与无声明槽时完全一致。
        /// postfix 恢复类型后由布局覆写重新定位声明槽。
        /// M23：对所有 CharacterInventory 无条件生效——本地角色面板在构造阶段
        /// （InitProjSpecial → SetSlotPositions）执行时 Character.Controlled 尚未指向它，
        /// 按「仅本地面板」过滤会导致进场首帧 1-10 左移一格。类型替换只影响原版几何
        /// 计算（个人槽计数/顺序坐标），与面板归属无关，全量替换对 BOT/其他玩家面板同样正确。
        /// </summary>
        public static void SetSlotPositionsLayoutPrefix(object __instance, out Barotrauma.InvSlotType[] __state)
        {
            __state = null;
            try
            {
                var declared = SlotRegistry.GetDeclaredSlotsCached();
                if (declared == null || declared.Count == 0) { return; }
                var ci = __instance as Barotrauma.CharacterInventory;
                if (ci == null) { return; }
                var types = ci.SlotTypes;
                if (types == null) { return; }
                int declaredMask = 0;
                foreach (var d in declared) { declaredMask |= d.Bit; }
                __state = (Barotrauma.InvSlotType[])types.Clone(); // 先克隆原值再替换
                bool changed = false;
                for (int i = 0; i < types.Length; i++)
                {
                    if (((int)types[i] & declaredMask) != 0)
                    {
                        types[i] = Barotrauma.InvSlotType.HealthInterface;
                        changed = true;
                    }
                }
                if (changed && !c_maskSwapLogged)
                {
                    c_maskSwapLogged = true;
                    SlotRegistry.DiagLog("SetSlotPositions 前缀: 声明槽临时替换为 HealthInterface（隔离个人槽计数，1-10 行不再左移）");
                }
            }
            catch (Exception e)
            {
                SlotRegistry.DiagLog("SetSlotPositions 前缀异常: " + e);
            }
        }

        private static bool c_maskSwapLogged = false;

        public static void SetSlotPositionsLayoutPostfix(object __instance, Barotrauma.InvSlotType[] __state)
        {
            // M22：先恢复被前缀临时替换的槽位类型（皮肤/枚举相关逻辑依赖原值），再覆写布局
            try
            {
                if (__state != null)
                {
                    var ci = __instance as Barotrauma.CharacterInventory;
                    var types = ci == null ? null : ci.SlotTypes;
                    if (types != null)
                    {
                        for (int i = 0; i < types.Length && i < __state.Length; i++) { types[i] = __state[i]; }
                    }
                }
            }
            catch (Exception e)
            {
                SlotRegistry.DiagLog("SetSlotPositions 后缀类型恢复异常: " + e);
            }
            ApplyDeclaredSlotLayout(__instance, "SetSlotPositions");
        }

        /// <summary>
        /// M20：CreateSlots postfix 入口。原版大量路径单独调用 CreateSlots（互动视图、移动物品、
        /// 子背包切换、Lua 刷新钩子）而不经过 SetSlotPositions，声明槽矩形会被重建并按
        /// ItemContainer 贴图扩宽（已装备胸挂 → 槽位变大且关闭互动后残留）。
        /// 与 SetSlotPositions postfix 共用同一覆写逻辑，保证任意入口后几何一致。
        /// </summary>
        public static void CreateSlotsPostfix(object __instance)
        {
            // 基类 Inventory.CreateSlots 也被挂（覆盖 CharacterInventory 重载全部入口），
            // 物品容器栏等非角色栏实例直接跳过，避免污染一次性反射句柄缓存
            if (!(__instance is Barotrauma.CharacterInventory)) { return; }
            ApplyDeclaredSlotLayout(__instance, "CreateSlots");
        }

        private static void ApplyDeclaredSlotLayout(object __instance, string source)
        {
            try
            {
                // ---- 入口探针：只看第一帧，位于 declared 检查之前 ----
                if (!diagPostfixEntered)
                {
                    diagPostfixEntered = true;
                    var dc0 = SlotRegistry.GetDeclaredSlotsCached();
                    SlotRegistry.DiagLog("postfix 已进入（首次）: __instance类型=" + (__instance == null ? "null" : __instance.GetType().FullName) + " declaredCount=" + (dc0 == null ? -1 : dc0.Count) + " layoutCacheInit=" + layoutCacheInit);
                }
                var declared = SlotRegistry.GetDeclaredSlotsCached(); // 缓存列表（注册变化时自动失效）
                if (declared == null || declared.Count == 0) { return; }
                // M23：覆写扩展到所有角色面板（本地/BOT/其他玩家）——prefix 已把声明槽排除出
                // 原版个人槽区，不覆写定位的话 BOT 面板的声明槽会被 HideSlot 隐藏。
                // 尺寸缓存只由本地面板计算（UpdateMetricsIfNeeded 内部把关），几何按各实例
                // 自身的原版坐标求解（vanillaColX/posArr），双面板互不污染。
                // Controlled 为 null（回合构建早期）时仍跳过——坐标未初始化且无面板绘制。
                if (Barotrauma.Character.Controlled == null) { return; }
                if (!(__instance is Barotrauma.CharacterInventory)) { return; }

                EnsureLayoutCache(__instance);   // 反射句柄只初始化一次
                if (!layoutCacheInit) { return; }
                UpdateMetricsIfNeeded(__instance); // 尺寸/间距只在缩放变化时重算
                var plan = GetPlan();              // row/col/yoff 计划按注册表版本缓存

                int declaredMask = 0;
                foreach (var d in declared) { declaredMask |= d.Bit; }
                int slotW = c_slotW, slotH = c_slotH, spacing = c_spacing;

                var typeArr = c_slotTypesProp == null ? null : c_slotTypesProp.GetValue(__instance) as Array;
                if (typeArr == null) { return; }
                var posArr = c_posField == null ? null : c_posField.GetValue(__instance) as Array;
                if (posArr == null) { return; }
                var area = c_areaField == null ? null : c_areaField.GetValue(__instance);
                if (area == null) { return; }

                // ---- 落盘诊断：布局 postfix 首次进入时的环境快照 ----
                if (!diagEntryLogged)
                {
                    diagEntryLogged = true;
                    bool has4096 = false;
                    var bitList = new System.Collections.Generic.List<string>();
                    for (int i = 0; i < typeArr.Length && i < 20; i++)
                    {
                        int tv = (int)typeArr.GetValue(i);
                        if (tv == 4096) { has4096 = true; }
                        bitList.Add(tv.ToString());
                    }
                    // 视觉槽状态：4096 槽位有没有对应的 VisualSlot（没有 = 不绘制，需 CreateSlots 重建）
                    var vsDiag = c_vsArrField == null ? null : c_vsArrField.GetValue(__instance) as Array;
                    bool vs4096Missing = true;
                    if (vsDiag != null)
                    {
                        for (int i = 0; i < typeArr.Length && i < vsDiag.Length; i++)
                        {
                            if ((int)typeArr.GetValue(i) == 4096 && vsDiag.GetValue(i) != null) { vs4096Missing = false; break; }
                        }
                    }
                    SlotRegistry.DiagLog("布局 postfix 首次进入: declaredMask=" + declaredMask + " typeArr前20=[" + string.Join(",", bitList) + "] 含4096=" + has4096 + " vsArr长度=" + (vsDiag == null ? -1 : vsDiag.Length) + " 4096视觉槽缺失=" + vs4096Missing + " slotW=" + slotW + " slotH=" + slotH + " spacing=" + spacing + " area=" + FldInt(area, "X") + "," + FldInt(area, "Y") + "," + FldInt(area, "Width") + "x" + FldInt(area, "Height"));
                }

                // ---- 第一排锚点（M12）：只用原版 6 个装备槽（504 位）求最底边/最左；
                //      内置 1024 潜水服槽会被原版排到左侧延伸区（X 很小甚至出画），不能作锚点
                //      （M11 用户实测：背包槽跑到物品栏左下扇区并出画——正是 1024 的左侧位置当了锚）。 ----
                int firstRowBottom = 0;
                int gridLeft = FldInt(area, "X");
                {
                    float maxY = float.MinValue;
                    float minX = float.MaxValue;
                    for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                    {
                        int v = (int)typeArr.GetValue(i);
                        if ((v & 504) == 0) { continue; }
                        object pv = posArr.GetValue(i);
                        if (pv == null) { continue; }
                        float pxv = FldFloat(pv, "X");
                        float pyv = FldFloat(pv, "Y");
                        if (pxv < minX) { minX = pxv; }
                        if (pyv > maxY) { maxY = pyv; }
                    }
                    // M21：原版槽位坐标尚未初始化（SlotPositions 全 0，回合构建早期）时
                    // 直接跳过本帧——否则 cardX=0/maxY=0 会当锚点写出 (-85,0) 垃圾几何
                    if (maxY <= 0f) { return; }
                    if (maxY > -1e8f) { firstRowBottom = (int)(maxY + slotH); }
                    if (minX < 1e8f) { gridLeft = (int)minX; }
                }
                if (firstRowBottom <= 0) { firstRowBottom = FldInt(area, "Y") + FldInt(area, "Height"); }

                // ---- row/col 计划（M17：按注册表版本缓存）----
                int pad = spacing / 2 + 1;

                // ---- M13：默认锚点 = 原版 ID 卡槽（Card=128）正上方一个区块（用户指定理想位置）；
                //      找不到 Card 时回退 M12 行为（原版 6 槽下方第二排）。 ----
                int cardX = 0, cardY = 0;
                bool hasCard = false;
                for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                {
                    int v = (int)typeArr.GetValue(i);
                    if (v == 128)
                    {
                        object pv = posArr.GetValue(i);
                        if (pv != null)
                        {
                            cardX = (int)FldFloat(pv, "X");
                            cardY = (int)FldFloat(pv, "Y");
                            hasCard = true;
                        }
                        break;
                    }
                }

                // ---- 覆写声明槽：SlotPositions + VisualSlot.Rect/InteractRect（M17：缓存句柄） ----
                var vsArr = c_vsArrField == null ? null : c_vsArrField.GetValue(__instance) as Array;
                // 收集原版各槽位列 X/Y（首个出现者）：align 吸附用
                var vanillaColX = new Dictionary<int, float>();
                var vanillaColY = new Dictionary<int, float>();
                for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                {
                    int v0 = (int)typeArr.GetValue(i);
                    if ((v0 & 504) == 0) { continue; }
                    object pv0 = posArr.GetValue(i);
                    if (pv0 == null) { continue; }
                    if (!vanillaColX.ContainsKey(v0))
                    {
                        vanillaColX[v0] = FldFloat(pv0, "X");
                        vanillaColY[v0] = FldFloat(pv0, "Y");
                    }
                }

                // ---- M18 自校准：直接从原版槽位实测盒宽/步距/间距（覆写 rect 前读取）。
                //      反射 Sprite/Scale 计算尺寸可能失败并锁定兜底值（80/5），
                //      导致 align 偏移用 85 而实际步距 65 → 与原版间隔差 20px。
                //      实测值与 UIScale/布局完全同步，优先级高于反射值。 ----
                int boxW = slotW, boxH = slotH, sp = spacing, stepW = 0;
                {
                    var xs = new System.Collections.Generic.List<float>();
                    for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                    {
                        int v0 = (int)typeArr.GetValue(i);
                        if ((v0 & 504) == 0) { continue; }
                        object pv0 = posArr.GetValue(i);
                        if (pv0 == null) { continue; }
                        xs.Add(FldFloat(pv0, "X"));
                        if (vsArr != null && i < vsArr.Length)
                        {
                            var vsObj = vsArr.GetValue(i);
                            var rectObj = (vsObj != null && c_vsRectField != null) ? c_vsRectField.GetValue(vsObj) : null;
                            if (rectObj != null)
                            {
                                int w = (int)FldFloat(rectObj, "Width");
                                int h = (int)FldFloat(rectObj, "Height");
                                if (w > 0 && w < boxW) { boxW = w; }
                                if (h > 0 && h < boxH) { boxH = h; }
                            }
                        }
                    }
                    xs.Sort();
                    for (int i = 1; i < xs.Count; i++)
                    {
                        float d = xs[i] - xs[i - 1];
                        if (d > 0.5f && (stepW == 0 || d < stepW)) { stepW = (int)d; }       // 取最小正步距
                    }
                    if (stepW == 0) { stepW = slotW + spacing; }                             // 无实测数据时回退反射值
                    if (stepW > boxW) { sp = stepW - boxW; }                                 // 实测间距 = 步距 - 盒宽
                    else { sp = spacing; }
                }
                // M21：实测值来自原版本帧真实布局，永远比反射缓存权威——有效时回写静态缓存。
                // UI 缩放变化时原版重建矩形，实测值自动跟随；反射兜底值（80/80/5）被彻底排除
                if (boxW > 0 && boxH > 0 && (boxW != c_slotW || boxH != c_slotH))
                {
                    c_slotW = boxW;
                    c_slotH = boxH;
                }
                pad = sp / 2 + 1;
                // M26：布局方向检测——Default/Right 布局个人槽从 Card 向左排列（Headset 在 Card 左侧），
                // Left 布局（G 互动对方面板）则从 Card 向右排列。col 偏移的语义是"紧贴原版槽位组"，
                // 方向向右时取镜像（col 反号），否则声明槽会按固定负偏移漂到面板组外侧。
                // 判据：Headset 列在 Card 列右侧 → 该实例个人槽行向右增长 → colDir=-1
                int colDir = 1;
                if (vanillaColX != null && vanillaColX.ContainsKey(128) && vanillaColX.ContainsKey(64))
                {
                    if (vanillaColX[64] > vanillaColX[128]) { colDir = -1; }
                }
                for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                {
                    int v = (int)typeArr.GetValue(i);
                    if ((v & declaredMask) == 0) { continue; }
                    int bit = v & declaredMask;
                    if (!plan.ContainsKey(bit)) { continue; }
                    int row = plan[bit][0];
                    int col = plan[bit][1];
                    int yoff = plan[bit][2];
                    int px, py;
                    string alignName;
                    int alignMask = 0;
                    if (c_align != null && c_align.TryGetValue(bit, out alignName) && !string.IsNullOrEmpty(alignName))
                    {
                        try { alignMask = (int)Enum.Parse(typeof(Barotrauma.InvSlotType), alignName, true); } catch { alignMask = 0; }
                    }
                    if (alignMask != 0 && vanillaColX.ContainsKey(alignMask))
                    {
                        // align 吸附：X = 原版槽位列 + col 偏移（col=0 精确吸附，负数向左/正数向右）；
                        // 偏移步长用实测 stepW（与原版槽间距像素级一致）；
                        // row=0 时 Y 直接取原版吸附槽行（与原版装备同排），row≥1 仍按覆写行排
                        px = (int)vanillaColX[alignMask] + col * colDir * stepW;
                        float alignedY;
                        if (row <= 0 && vanillaColY.TryGetValue(alignMask, out alignedY))
                        {
                            py = (int)alignedY + yoff;
                        }
                        else
                        {
                            py = hasCard ? (cardY - row * (boxH + sp) - 7 * sp + yoff) : (firstRowBottom + sp + (row - 1) * (boxH + sp) + yoff);
                        }
                    }
                    else if (hasCard)
                    {
                        // 默认额外上移 7 个间距；yoff 可继续微调（负=上移）
                        px = cardX + col * colDir * stepW;
                        py = cardY - row * (boxH + sp) - 7 * sp + yoff;
                    }
                    else
                    {
                        px = gridLeft + col * stepW;
                        py = firstRowBottom + sp + (row - 1) * (boxH + sp) + yoff;
                    }
                    if (c_vecCtor != null)
                    {
                        posArr.SetValue(c_vecCtor.Invoke(new object[] { (float)px, (float)py }), i);
                    }

                    if (vsArr != null && i < vsArr.Length && vsArr.GetValue(i) != null)
                    {
                        var vs = vsArr.GetValue(i);
                        if (c_vsRectField != null && c_rectCtor != null)
                        {
                            c_vsRectField.SetValue(vs, c_rectCtor.Invoke(new object[] { px, py, boxW, boxH }));
                        }
                        if (c_vsIrField != null && c_rectCtor != null)
                        {
                            c_vsIrField.SetValue(vs, c_rectCtor.Invoke(new object[] { px - pad, py - pad, boxW + 2 * pad, boxH + 2 * pad }));
                        }
                        // M25：按覆写后的最终几何重算 SubInventoryDir（-1=内容向上展开，+1=向下）。
                        // 原版只在 CreateSlots 时按"当时的矩形"计算一次——声明槽被临时替换为
                        // HealthInterface 后会被原版健康窗口重定位块挪到屏幕上半区，
                        // 嵌套 CreateSlots 残留 +1（向下展开），postfix 移回矩形后方向仍是错的。
                        // 公式与原版 CharacterInventory.CreateSlots 保持一致。
                        // M28：VisualSlot 与 GraphicsHeight 都是客户端专有——布局覆写循环本体在
                        // 双端执行（服务端仅做数据层），方向重算用 #if CLIENT 隔离，
                        // 否则专服编译 CS0117 直接炸掉整个框架（服务器无声明槽 → 联机槽位全失效）。
#if CLIENT
                        if (c_vsDirField != null)
                        {
                            c_vsDirField.SetValue(vs, Math.Sign(GameMain.GraphicsHeight / 2 - (py + boxH / 2)));
                        }
#endif
                    }
                }

                // 以原版 personalSlotArea 为基准（它已正确覆盖原版 6 槽与 1024 左侧延伸区），
                // 只把声明槽新行并入，避免从零求并集时把左侧延伸区带偏。
                int vax = FldInt(area, "X");   // 原版区域左缘（本帧 vanilla 计算值）
                int ux = vax;
                int uy = FldInt(area, "Y");
                int ur = ux + FldInt(area, "Width");
                int ub = uy + FldInt(area, "Height");
                bool hasU = (ur > ux && ub > uy);
                for (int i = 0; i < typeArr.Length && i < posArr.Length; i++)
                {
                    int v = (int)typeArr.GetValue(i);
                    if ((v & declaredMask) == 0) { continue; }
                    object pv = posArr.GetValue(i);
                    if (pv == null) { continue; }
                    int sx2 = (int)FldFloat(pv, "X");
                    int sy2 = (int)FldFloat(pv, "Y");
                    if (!hasU) { ux = sx2; uy = sy2; ur = sx2 + boxW; ub = sy2 + boxH; hasU = true; }
                    else
                    {
                        if (sx2 < ux) { ux = sx2; }
                        if (sy2 < uy) { uy = sy2; }
                        if (sx2 + boxW > ur) { ur = sx2 + boxW; }
                        if (sy2 + boxH > ub) { ub = sy2 + boxH; }
                    }
                }
                if (hasU && (ux != c_lastUX || uy != c_lastUY || ur != c_lastUR || ub != c_lastUB))
                {
                    // 并集边界不变时跳过（避免每帧创建 Rectangle/重设区域）
                    c_lastUX = ux; c_lastUY = uy; c_lastUR = ur; c_lastUB = ub;
                    // 写回 personalSlotArea 时：左缘钳制在原版左缘（不向左扩）——
                    // 物品栏网格锚定区域左缘，向左扩会让物品栏跟着左移让位。
                    int writeUX = Math.Max(ux, vax);
                    if (c_areaField != null && c_rectCtor != null)
                    {
                        try { c_areaField.SetValue(__instance, c_rectCtor.Invoke(new object[] { writeUX, uy, ur - writeUX, ub - uy })); } catch { }
                    }
                    // 背景框扩展仍用完整并集左缘（面板继续盖住左延伸的声明槽）；
                    // M23：区域按实例隔离存储（G 互动时本地/BOT 双面板并存，静态字段会交叉污染）
                    SetDeclaredArea(__instance, ux, uy, ur, ub);
                    ExpandFrame(__instance);
                    if (!m8Logged)
                    {
                        m8Logged = true;
                        SlotRegistry.LogDebug("布局覆写生效：声明槽锚定 Card 上方（默认额外上移 7 间距），slotW=" + slotW + " slotH=" + slotH + " spacing=" + spacing + " 实测boxW=" + boxW + " boxH=" + boxH + " step=" + stepW + " 间距=" + sp + " cardX=" + cardX + " cardY=" + cardY + " hasCard=" + hasCard + " 区域并集=" + ux + "," + uy + "," + (ur - ux) + "x" + (ub - uy));
                        SlotRegistry.DiagLog("布局覆写生效（落盘）source=" + source + ": cardX=" + cardX + " cardY=" + cardY + " hasCard=" + hasCard + " slotW=" + slotW + " slotH=" + slotH + " 并集=" + ux + "," + uy + "," + (ur - ux) + "x" + (ub - uy));
                    }
                    EnsureSlotIcons(__instance); // 渲染层：给声明 bit 注入图标（新构建走 LimbSlotIcons 字典）
                }
            }
            catch (Exception e)
            {
                SlotRegistry.Log("M8 布局覆写失败: " + e);
                SlotRegistry.DiagLog("postfix 异常: " + e);
            }
        }

        /// <summary>
        /// 渲染层：把声明槽的图标注入 CharacterInventory.LimbSlotIcons 字典。
        /// 新版游戏构建的槽位图标不只走 UI 样式（InventorySlot.&lt;bit&gt;），
        /// DrawSlot 还会查 LimbSlotIcons[slotType]；没有条目时槽位什么都不画（隐形）。
        /// 机制与 More Equipment Slots 的 MsCookieS_SlotIcons 完全一致，全程反射：
        /// 静态/实例属性 LimbSlotIcons → Dictionary&lt;InvSlotType, Sprite&gt; → 注入原版图标 Sprite。
        /// </summary>
        private static void EnsureSlotIcons(object __instance)
        {
            if (slotIconsDone) { return; }
            slotIconsDone = true;
            try
            {
                var ciType = __instance.GetType();
                var iconsProp = ciType.GetProperty("LimbSlotIcons", BindingFlags.Public | BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Instance);
                if (iconsProp == null) { SlotRegistry.DiagLog("图标注入: LimbSlotIcons 属性未找到"); return; }
                object icons = null;
                try { icons = iconsProp.GetValue(null); } catch { }
                if (icons == null) { try { icons = iconsProp.GetValue(__instance); } catch { } }
                var dict = icons as System.Collections.IDictionary;
                if (dict == null) { SlotRegistry.DiagLog("图标注入: LimbSlotIcons 不是字典或取不到"); return; }
                // 不依赖 TypeByName 找 XNA Sprite（实测查不到）：直接取字典里已存在的
                // 任意图标实例作类型样板；每个声明槽从本包 UI/slot_<id>.png 加载专属图标。
                object existing = null;
                foreach (var k in dict.Keys) { existing = dict[k]; if (existing != null) { break; } }
                if (existing == null) { SlotRegistry.DiagLog("图标注入: 字典里没有任何现有图标实例"); return; }
                var sprType = existing.GetType();
                // Barotrauma.Sprite 的真实构造器（Cecil 实测）：
                //   .ctor(String newFile, Nullable<Rectangle> sourceRectangle, Nullable<Vector2> origin, Single rotation)
                var sprCtor = sprType.GetConstructors().FirstOrDefault(c =>
                {
                    var ps = c.GetParameters();
                    if (ps.Length != 4 || ps[0].ParameterType != typeof(string) || ps[3].ParameterType != typeof(float)) { return false; }
                    var u = Nullable.GetUnderlyingType(ps[1].ParameterType);
                    return u != null && u.Name == "Rectangle";
                });
                Type rectType = null;
                ConstructorInfo rectCtor = null;
                ConstructorInfo nullableRectCtor = null;
                if (sprCtor != null)
                {
                    rectType = Nullable.GetUnderlyingType(sprCtor.GetParameters()[1].ParameterType);
                    rectCtor = rectType == null ? null : rectType.GetConstructor(new[] { typeof(int), typeof(int), typeof(int), typeof(int) });
                    nullableRectCtor = sprCtor.GetParameters()[1].ParameterType.GetConstructor(new[] { rectType });
                }
                // 本框架包目录（用于加载槽位图标 PNG）；pkg.Dir 是相对路径，拼上客户端根目录转绝对路径。
                // M29：兼容独立包与合并进本体两种目录结构——按标记文件候选依次探测：
                //   独立包：CSharp/Shared/DeepSlotExpanded.cs（旧结构）
                //   合并进 DDA：CSharp/DeepSlotExpanded.cs 或根目录 DeepSlotExpandedSlots.xml
                string pkgDir = null;
                try
                {
                    Barotrauma.LuaCsSetup setup = Barotrauma.LuaCsSetup.Instance;
                    if (setup != null)
                    {
                        string[] markers = new[]
                        {
                            System.IO.Path.Combine("CSharp", "Shared", "DeepSlotExpanded.cs"),
                            System.IO.Path.Combine("CSharp", "DeepSlotExpanded.cs"),
                            "DeepSlotExpandedSlots.xml"
                        };
                        foreach (var pkg in ContentPackageManager.EnabledPackages.Regular)
                        {
                            try
                            {
                                foreach (var mk in markers)
                                {
                                    if (System.IO.File.Exists(System.IO.Path.Combine(pkg.Dir, mk))) { pkgDir = pkg.Dir; break; }
                                }
                                if (pkgDir != null) { break; }
                            }
                            catch { }
                        }
                    }
                }
                catch { }
                SlotRegistry.DiagLog("图标注入: sprType=" + sprType.FullName + " sprCtor=" + (sprCtor != null) + " rectCtor=" + (rectCtor != null) + " nullableRectCtor=" + (nullableRectCtor != null) + " pkgDir=" + pkgDir + " 现有图标数=" + dict.Count);
                var invSlotType = typeof(Barotrauma.InvSlotType);
                var declared = SlotRegistry.GetDeclaredSlotsCached();
                int ok = 0;
                foreach (var d in declared)
                {
                    object key = Enum.ToObject(invSlotType, d.Bit);
                    if (dict.Contains(key)) { ok++; continue; }
                    try
                    {
                        object sprite = null;
                        string iconPath = null;
                        if (!string.IsNullOrEmpty(pkgDir))
                        {
                            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                            // 图标子目录兼容：独立框架结构为 UI\slot_<id>.png，
                            // 合并进 DDA 本体后为 UI\SlotIcon\slot_<id>.png，两者都认
                            string[] iconCandidates = new[]
                            {
                                System.IO.Path.Combine(baseDir, pkgDir, "UI", "SlotIcon", "slot_" + d.Id + ".png"),
                                System.IO.Path.Combine(baseDir, pkgDir, "UI", "slot_" + d.Id + ".png")
                            };
                            foreach (var cand in iconCandidates)
                            {
                                if (System.IO.File.Exists(cand)) { iconPath = cand; break; }
                            }
                        }
                        if (iconPath != null && sprCtor != null && rectCtor != null && nullableRectCtor != null)
                        {
                            try
                            {
                                // 读 PNG 头取真实尺寸（IHDR 宽高在字节 16-23，大端）
                                int w = 128, h = 128;
                                try
                                {
                                    byte[] head = System.IO.File.ReadAllBytes(iconPath);
                                    if (head.Length > 24)
                                    {
                                        w = (head[16] << 24) | (head[17] << 16) | (head[18] << 8) | head[19];
                                        h = (head[20] << 24) | (head[21] << 16) | (head[22] << 8) | head[23];
                                    }
                                }
                                catch { }
                                object rect = rectCtor.Invoke(new object[] { 0, 0, w, h });
                                object nrect = nullableRectCtor.Invoke(new object[] { rect });
                                sprite = sprCtor.Invoke(new object[] { iconPath, nrect, null, 0f });
                            }
                            catch (Exception ce)
                            {
                                SlotRegistry.DiagLog("Sprite 构造失败（" + d.Id + "，将复用现有图标）: " + ce.Message);
                            }
                        }
                        if (sprite == null) { sprite = existing; }
                        dict.Add(key, sprite);
                        ok++;
                        SlotRegistry.DiagLog("槽位 " + d.Id + " (bit=" + d.Bit + ") 图标=" + (iconPath == null ? "(复用现有)" : iconPath));
                    }
                    catch (Exception ie)
                    {
                        SlotRegistry.DiagLog("图标注入 bit=" + d.Bit + " 失败: " + ie.Message);
                    }
                }
                SlotRegistry.DiagLog("图标注入完成: " + ok + "/" + declared.Count + " 个槽位已注入图标");
            }
            catch (Exception e)
            {
                SlotRegistry.DiagLog("图标注入异常: " + e);
            }
        }

        /// <summary>
        /// M9：CalculateBackgroundFrame 会在 DrawOwn/创建槽位时重算背景框并覆盖我们的扩展，
        /// 挂 postfix 在它之后重新并入声明槽区域。
        /// </summary>
        public static void CalculateBackgroundFramePostfix(object __instance)
        {
            // M23：与布局覆写同一门槛——BOT 面板的声明槽同样参与背景框扩展；
            // 区域按实例隔离（ConditionalWeakTable），双面板互不污染
            if (Barotrauma.Character.Controlled == null) { return; }
            if (!(__instance is Barotrauma.CharacterInventory)) { return; }
            ExpandFrame(__instance);
        }

        // M23：声明槽网格区域按实例隔离（ConditionalWeakTable 随实例回收，无泄漏），
        // 取代原静态 m8AreaX/Y/RowRight/RowBottom——G 互动时本地/BOT 双面板并存会交叉污染
        private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<object, int[]> m8AreaByInstance =
            new System.Runtime.CompilerServices.ConditionalWeakTable<object, int[]>();
        private static bool m8Logged = false;

        private static void SetDeclaredArea(object __instance, int x, int y, int right, int bottom)
        {
            m8AreaByInstance.Remove(__instance);
            m8AreaByInstance.Add(__instance, new[] { x, y, right, bottom });
        }

        /// <summary>把 BackgroundFrame 与声明槽网格区域取并集（由 SetSlotPositions/CBF 两个 postfix 调用）。M17：已覆盖时短路。</summary>
        private static void ExpandFrame(object __instance)
        {
            try
            {
                int[] area;
                if (!m8AreaByInstance.TryGetValue(__instance, out area) || area == null || area[3] <= 0) { return; }
                int m8AreaX = area[0], m8AreaY = area[1], m8RowRight = area[2], m8RowBottom = area[3];
                var frameProp = c_frameProp;
                if (frameProp == null) { frameProp = __instance.GetType().GetProperty("BackgroundFrame"); }
                object oldFrame = frameProp == null ? null : frameProp.GetValue(__instance);
                if (oldFrame == null) { return; }
                int fx = FldInt(oldFrame, "X");
                int fy = FldInt(oldFrame, "Y");
                int fw = FldInt(oldFrame, "Width");
                int fh = FldInt(oldFrame, "Height");
                // M17：已覆盖 → 短路，不创建新矩形
                if (fx <= m8AreaX && fy <= m8AreaY && fx + fw >= m8RowRight && fy + fh >= m8RowBottom) { return; }
                int nx = Math.Min(fx, m8AreaX);
                int ny = Math.Min(fy, m8AreaY);
                int nw = Math.Max(fx + fw, m8RowRight) - nx;
                int nh = Math.Max(fy + fh, m8RowBottom) - ny;
                if (nw <= 0 || nh <= 0) { return; }
                object newRect = c_rectCtor != null
                    ? c_rectCtor.Invoke(new object[] { nx, ny, nw, nh })
                    : Activator.CreateInstance(oldFrame.GetType(), nx, ny, nw, nh);
                var setter = c_frameSetter;
                if (setter == null) { setter = frameProp.GetSetMethod(); }
                if (setter != null) { setter.Invoke(__instance, new object[] { newRect }); }
            }
            catch { }
        }

        /// <summary>沿继承链找字段（Public/NonPublic/Instance/Static 全查）。</summary>
        private static FieldInfo FindFieldInChain(Type t, string name)
        {
            while (t != null)
            {
                var f = t.GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static);
                if (f != null) { return f; }
                t = t.BaseType;
            }
            return null;
        }

        private static int FldInt(object obj, string name)
        {
            try
            {
                var f = obj.GetType().GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                return f == null ? 0 : (int)f.GetValue(obj);
            }
            catch { return 0; }
        }

        private static float FldFloat(object obj, string name)
        {
            try
            {
                var f = obj.GetType().GetField(name, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                return f == null ? 0f : (float)f.GetValue(obj);
            }
            catch { return 0f; }
        }

        // ===================== 前缀/后缀实现 =====================

        /// <summary>HasEquippedItem(Item, InvSlotType?, Func&lt;InvSlotType,bool&gt;) 前缀。</summary>
        public static void HasEquippedItemPrefix(ref Barotrauma.InvSlotType? slotType)
        {
            NormalizeSlotMask(ref slotType);
        }

        /// <summary>GetEquippedItem(Identifier, InvSlotType?) 前缀。</summary>
        public static void GetEquippedItemPrefix(ref Barotrauma.InvSlotType? slotType)
        {
            NormalizeSlotMask(ref slotType);
        }

        /// <summary>
        /// HideSlot(int i) postfix：vanilla 决定隐藏某槽时，若该槽类型含声明 bit，强制取消隐藏。
        /// 兜底新版构建中 transpiler 掩码替换失效导致自定义槽被当"非个人槽"隐藏的问题。
        /// M23：与布局覆写同一门槛，BOT 面板同样兜底。
        /// </summary>
        public static void HideSlotPostfix(object __instance, int i, ref bool __result)
        {
            if (!__result) { return; }
            if (Barotrauma.Character.Controlled == null) { return; }
            if (!(__instance is Barotrauma.CharacterInventory)) { return; }
            try
            {
                var prop = __instance.GetType().GetProperty("SlotTypes");
                var arr = prop == null ? null : prop.GetValue(__instance) as Array;
                if (arr == null || i < 0 || i >= arr.Length) { return; }
                int v = (int)arr.GetValue(i);
                int all = SlotRegistry.AllBitsCached();
                if (all != 0 && (v & all) != 0)
                {
                    __result = false;
                    if (!hideDiagLogged)
                    {
                        hideDiagLogged = true;
                        SlotRegistry.DiagLog("HideSlot 兜底：取消隐藏槽位 i=" + i + " 类型=" + v + "（仅记录首次，后续静默）");
                    }
                }
            }
            catch { }
        }

        private static void NormalizeSlotMask(ref Barotrauma.InvSlotType? slotType)
        {
            try
            {
                if (!slotType.HasValue) { return; }
                var v = (int)slotType.Value;
                int all = SlotRegistry.AllBits();
                if (all == 0) { return; }
                if ((v & (int)Barotrauma.InvSlotType.OuterClothes) != 0 && (v & all) != all)
                {
                    slotType = (Barotrauma.InvSlotType)(v | all);
                }
            }
            catch (Exception e)
            {
                SlotRegistry.Log("AI 掩码前缀失败: " + e);
            }
        }

        /// <summary>
        /// ParseSlotTypes postfix：对每个注册声明，若槽位表含来源槽且不含该 bit，则追加 bit 字符串。
        /// 按 bit 升序遍历 → 追加顺序与模组加载顺序无关（双端槽位表严格一致）。
        /// </summary>
        public static void ParseSlotTypesPostfix(ref string[] __result)
        {
            try
            {
                TryRegisterLuaApi(); // M6：Lua API 惰性重试（成功后短路）
                if (__result == null || __result.Length == 0) { return; }
                List<string> list = null;
                foreach (var def in SlotRegistry.GetSlotsByBit())
                {
                    string bitStr = def.Bit.ToString();
                    bool hasBit = false, hasFrom = false;
                    foreach (var s in __result)
                    {
                        if (s == null) { continue; }
                        string t = s.Trim();
                        if (t.Equals(bitStr, StringComparison.OrdinalIgnoreCase)) { hasBit = true; }
                        else if (SlotRegistry.IsFromName(t, def.FromMask)) { hasFrom = true; }
                        if (hasBit && hasFrom) { break; }
                    }
                    if (hasFrom && !hasBit)
                    {
                        if (list == null) { list = new List<string>(__result); }
                        list.Add(bitStr);
                        SlotRegistry.LogDebug("槽位表追加 " + bitStr + " (id=" + def.Id + ")");
                    }
                }
                if (list != null) { __result = list.ToArray(); }
            }
            catch (Exception e)
            {
                SlotRegistry.Log("ParseSlotTypes postfix 失败: " + e);
            }
        }

        /// <summary>
        /// Item 构造 postfix：标签命中声明后，把来源槽位改写为新 bit。
        /// 通过 Pickable.SetAllowedSlots 同步组件槽位与 Item 的装备校验缓存。
        /// </summary>
        public static void ItemCtorPostfix(object __instance)
        {
            try
            {
                TryRegisterLuaApi(); // M6：Lua API 惰性重试（成功后短路）
                var itemType = __instance.GetType();

                var tagsProp = itemType.GetProperty("Tags");
                string tags = tagsProp == null ? "" : (tagsProp.GetValue(__instance) as string);
                var tagList = (tags ?? "").Split(',')
                    .Select(t => t.Trim())
                    .Where(t => t.Length > 0)
                    .ToList();

                // 注意：Item 上没有 Identifier 属性（Cecil 核实，只有 Prefab/ContainerIdentifier）；
                // identifier 在 Prefab 基类的公共字段上（Barotrauma.Prefab.Identifier）。
                // 取 Item.Prefab → 沿继承链找 "Identifier" 字段（Public/NonPublic 双查）。
                string identifier = "";
                try
                {
                    var prefabProp = itemType.GetProperty("Prefab");
                    object prefab = prefabProp == null ? null : prefabProp.GetValue(__instance);
                    if (prefab != null)
                    {
                        var pfType = prefab.GetType();
                        FieldInfo idField = null;
                        while (idField == null && pfType != null)
                        {
                            idField = pfType.GetField("Identifier", BindingFlags.Public | BindingFlags.Instance)
                                   ?? pfType.GetField("Identifier", BindingFlags.NonPublic | BindingFlags.Instance);
                            pfType = pfType.BaseType;
                        }
                        if (idField != null)
                        {
                            var idVal = idField.GetValue(prefab);
                            identifier = idVal == null ? "" : (idVal.ToString() ?? "");
                        }
                    }
                }
                catch { identifier = ""; }
                if (tagList.Count == 0 && identifier.Length == 0) { return; }

                SlotDef def = SlotRegistry.Match(identifier, tagList);
                if (def == null) { return; }

                bool changed = false;

                // 组件层: Wearable 继承自 Pickable，同步它的 AllowedSlots 列表
                var componentsProp = itemType.GetProperty("Components");
                if (componentsProp != null && componentsProp.GetValue(__instance) is IEnumerable comps)
                {
                    foreach (var comp in comps)
                    {
                        if (!(comp is Barotrauma.Items.Components.Pickable pickable)) { continue; }
                        var list = pickable.AllowedSlots.ToList();
                        bool slotsChanged = false;
                        foreach (int bit in SlotRegistry.BitsOf(def.FromMask))
                        {
                            if (list.Remove((Barotrauma.InvSlotType)bit))
                            {
                                if (!list.Contains((Barotrauma.InvSlotType)def.Bit))
                                {
                                    list.Add((Barotrauma.InvSlotType)def.Bit);
                                }
                                slotsChanged = true;
                            }
                        }
                        if (slotsChanged)
                        {
                            pickable.SetAllowedSlots(list);
                            changed = true;
                        }
                    }
                }

                if (changed)
                {
                    var nameProp = itemType.GetProperty("Name");
                    SlotRegistry.LogDebug("物品已移入槽位 " + def.Id + " (bit=" + def.Bit + "): " + (nameProp == null ? "?" : nameProp.GetValue(__instance)));
                }
            }
            catch (Exception e)
            {
                SlotRegistry.Log("ItemCtor postfix 失败: " + e);
            }
        }
    }
}
