using HarmonyLib;
using Barotrauma;
using Barotrauma.Items.Components;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using System.Linq;
using System.Collections.Generic;
using System.Xml.Linq;
using System.Text;
using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.IO;
using System.Text.RegularExpressions;
using System.Globalization;

namespace MoreInformationDisplay
{
    public class Plugin : IAssemblyPlugin
    {
        Harmony harmony;

        // 内置版使用独立补丁 ID；独立显示物品属性模组仍使用旧 ID
        private const string SelfHarmonyId = "deepdivingarmory.moreinfo";
        private const string StandaloneHarmonyId = "item.stats.tooltip.unified.fixed";

        public void Initialize()
        {
            harmony = new Harmony(SelfHarmonyId);
            harmony.PatchAll();
            LuaCsLogger.Log("[MoreInformationDisplay] Loaded");
        }

        public void Dispose() => harmony?.UnpatchSelf();
        public void PreInitPatching() { }

        // 所有模组加载完毕后触发：若玩家同时启用了独立显示物品属性模组，
        // 卸载其全部补丁，保证冲突时内置版唯一生效（与加载顺序无关）
        public void OnLoadCompleted()
        {
            var tooltipMethod = AccessTools.Method(typeof(ItemComponent), "AddTooltipInfo");
            if (tooltipMethod == null) return;
            var patchInfo = Harmony.GetPatchInfo(tooltipMethod);
            if (patchInfo?.Owners.Contains(StandaloneHarmonyId) != true) return;

            new Harmony(StandaloneHarmonyId).UnpatchSelf();
            LuaCsLogger.Log("[MoreInformationDisplay] 检测到独立显示物品属性模组，已停用其补丁");
        }
    }

    internal static class VirtualMagazineTooltip
    {
        private static ItemContainer Magazine(Item item)
        {
            if (item == null || !item.HasTag(new Identifier("556mag"))) return null;
            var container = item.GetComponent<ItemContainer>();
            return container?.GetType().FullName == "VCE_VirtualizedMagazine.VirtualizedMagazine" ? container : null;
        }

        private static IEnumerable<Identifier> Rounds(ItemContainer magazine)
        {
            // shortcut: read VCE's stack until it exposes a read-only contents API; never unload to inspect it.
            return AccessTools.Property(magazine.GetType(), "LoadedAmmoIdentifiers")?.GetValue(magazine) as IEnumerable<Identifier>;
        }

        internal static int State(Item item)
        {
            var magazine = Magazine(item);
            if (magazine == null) return 0;
            var type = magazine.GetType();
            var hash = new HashCode();
            hash.Add((int)type.GetProperty("LoadedCount").GetValue(magazine));
            hash.Add((Identifier)type.GetProperty("TopIdentifier").GetValue(magazine));
            var rounds = Rounds(magazine);
            if (rounds != null) foreach (var ammo in rounds) hash.Add(ammo);
            return hash.ToHashCode();
        }

        private static string AmmoName(Identifier id)
        {
            string fallback = ItemPrefab.Prefabs.TryGet(id, out var prefab) ? prefab.Name.Value : id.Value;
            return TextManager.Get("dda.ammo." + id.Value).Fallback(fallback).Value;
        }

        internal static string Describe(Item item)
        {
            var magazine = Magazine(item);
            if (magazine == null) return "";
            var type = magazine.GetType();
            int count = (int)type.GetProperty("LoadedCount").GetValue(magazine);
            int capacity = (int)type.GetProperty("MaxSize").GetValue(magazine);
            var next = (Identifier)type.GetProperty("TopIdentifier").GetValue(magazine);
            string nextName = count > 0 ? AmmoName(next) : TextManager.Get("dda.magazine.empty").Value;
            string text = $"{TextManager.Get("dda.magazine.loaded")}: {count}/{capacity}\n{TextManager.Get("dda.magazine.next")}: {nextName}";
            var rounds = Rounds(magazine);
            if (count > 0 && rounds != null)
            {
                text += "\n" + TextManager.Get("dda.magazine.contents").Value + ": "
                    + string.Join(" / ", rounds.GroupBy(id => id).Select(group => $"{AmmoName(group.Key)} × {group.Count()}"));
            }
            return text;
        }
    }

    /// <summary>
    /// 库存提示框缓存与显示条件同步：
    /// SlotReference 的提示文本构建后被缓存，仅当 TooltipNeedsRefresh 判定需要更新时才重建
    /// （耐久变化、Contextual 键变化）。若不补此丁，未按 Shift 时构建的缓存，
    /// 之后即使按住 Shift 也不会重建，导致属性永不显示。
    /// 处理：为每个槽位记录构建时的 Shift 状态，悬停时若状态与当前不一致即强制重建。
    /// 按槽位记录而非全局单字段，否则按住 Shift 切换槽位时其余槽位会命中旧缓存。
    /// 开销：悬停时每帧仅一次比较，仅在条件变化的瞬间多重建一次，无每帧文本构建开销。
    /// </summary>
    [HarmonyPatch]
    internal static class Patch_TooltipShiftRefresh
    {
        private sealed class BuildState
        {
            public bool ShiftDown;
            public int MagazineState;
        }

        private static readonly ConditionalWeakTable<Inventory.SlotReference, BuildState> buildStates
            = new ConditionalWeakTable<Inventory.SlotReference, BuildState>();

        [HarmonyPostfix]
        [HarmonyPatch(typeof(Inventory.SlotReference), nameof(Inventory.SlotReference.TooltipNeedsRefresh))]
        internal static void ForceRefreshOnConditionChange(Inventory.SlotReference __instance, ref bool __result)
        {
            if (__result) { return; }

            bool shiftDown = PlayerInput.IsShiftDown();
            if (buildStates.TryGetValue(__instance, out var state)
                && state.ShiftDown == shiftDown
                && state.MagazineState == VirtualMagazineTooltip.State(__instance.Item))
            {
                return;
            }
            __result = true;
        }

        [HarmonyPostfix]
        [HarmonyPatch(typeof(Inventory.SlotReference), nameof(Inventory.SlotReference.RefreshTooltip))]
        internal static void RecordBuildState(Inventory.SlotReference __instance)
        {
            BuildState state = buildStates.GetOrCreateValue(__instance);
            state.ShiftDown = PlayerInput.IsShiftDown();
            state.MagazineState = VirtualMagazineTooltip.State(__instance.Item);
        }
    }

    [HarmonyPatch(typeof(ItemComponent), "AddTooltipInfo")]
    internal static class Patch_ItemStatsTooltip
    {
        static void Postfix(ItemComponent __instance, ref LocalizedString name, ref LocalizedString description)
        {
            Item item = __instance.Item;
            if (item == null) return;
            if (__instance == item.Components.First())
            {
                string magazineInfo = VirtualMagazineTooltip.Describe(item);
                if (!string.IsNullOrEmpty(magazineInfo))
                {
                    if (!description.IsNullOrEmpty()) description += "\n";
                    description += magazineInfo;
                }
            }
            // 显示条件：仅当鼠标悬停物品且按住 Shift 时显示（提示框仅在悬停时构建，此处补充 Shift 条件）
            if (!PlayerInput.IsShiftDown()) return;

            // 去重
            if (__instance == item.Components.First())
            {
                if ((__instance is Wearable || __instance.GetType() == typeof(ItemComponent))
                    && (item.GetComponent<MeleeWeapon>()?.Attack != null
                        || item.GetComponent<RangedWeapon>() != null
                        || item.GetComponent<Projectile>() != null
                        || item.GetComponent<Throwable>() != null))
                    return;
            }
            else
            {
                ItemComponent first = item.Components.First();
                if (!(first is Wearable) && first.GetType() != typeof(ItemComponent)) return;
                if (!(__instance is MeleeWeapon or RangedWeapon or Projectile or Throwable)) return;
            }

            var parts = new List<string>();
            bool isMedical = IsMedicalItem(item);

            // 医疗物品优先以医疗信息展示
            string medical = BuildMedicalInfo(item);
            if (!string.IsNullOrWhiteSpace(medical))
                parts.Add(medical);

            // 深潜护甲配置信息（armorconfigs.lua，以物品 identifier 为键）
            string armorCfg = BuildArmorConfigInfo(item);
            if (!string.IsNullOrWhiteSpace(armorCfg))
                parts.Add(armorCfg);

            if (!isMedical)
            {
                // 1. 投掷物处理
                var throwable = item.GetComponent<Throwable>();
                if (throwable != null)
                    parts.Add(BuildThrowableInfo(throwable));

                // 2. 近战武器处理
                var melee = item.GetComponent<MeleeWeapon>();
                if (melee?.Attack != null)
                    parts.Add(BuildAttackInfo("近战武器", melee.Attack, melee.Reload, item));

                // 3. 远程武器处理
                var ranged = item.GetComponent<RangedWeapon>();
                if (ranged != null)
                {
                    var sb = new StringBuilder();
                    sb.AppendLine("‖color:gui.orange‖<远程武器>‖color:end‖");
                    sb.AppendLine($"穿甲: {ranged.Penetration:F2}{PenArmorSuffix(ranged.Penetration)}");
                    sb.AppendLine($"重装: {ranged.Reload:F2}s");
                    sb.AppendLine($"散布: {ranged.Spread:F2}");
                    if (ranged.MaxChargeTime > 0f)
                        sb.AppendLine($"蓄力时间: {ranged.MaxChargeTime:F2}s");
                    sb.AppendLine($"过热条: {item.MaxCondition:F0}    ‖color:gui.blue‖水中开火不会过热‖color:end‖");
                    sb.AppendLine($"伤害倍率: {ranged.WeaponDamageModifier:F2}");
                    string effects = BuildItemComponentEffects(item);
                    if (!string.IsNullOrEmpty(effects)) sb.Append(effects);
                    parts.Add(sb.ToString().Trim());
                }

                // 4. 投射物处理
                var proj = FindProjectile(item);
                if (proj?.Attack != null)
                    parts.Add(BuildProjectileInfo(proj));

                // 5. 弹药盒子弹信息
                if (proj?.Attack == null)
                {
                    string ammo = BuildAmmoBoxInfo(item);
                    if (!string.IsNullOrWhiteSpace(ammo))
                        parts.Add(ammo);
                }

                // 6. 通用组件效果回退（排除已有专项处理的组件类型）
                bool hasWeaponOrProj = melee?.Attack != null || ranged != null || proj?.Attack != null;
                if (!hasWeaponOrProj || throwable != null)
                {
                    string compEffects = BuildItemComponentEffects(item, throwable);
                    if (!string.IsNullOrWhiteSpace(compEffects)) parts.Add(compEffects);
                }
            }

            // 7. 可穿戴物品的WiFi组件信息
            if (item.GetComponent<Wearable>() != null)
            {
                var wifi = item.GetComponent<WifiComponent>();
                if (wifi != null)
                    parts.Add(BuildWifiInfo(wifi));
            }

            string extra = string.Join("\n", parts.Where(s => !string.IsNullOrWhiteSpace(s)).Select(s => s.Trim())).Trim();

            // 深潜压弹器复装弹药箱提示：按识别表匹配，固定追加为物品信息最后一行
            foreach (var hint in reloadBoxHints)
            {
                if (!item.HasTag(hint.Tag)) continue;
                if (!string.IsNullOrWhiteSpace(extra))
                    extra += "\n";
                extra += $"‖color:{hint.Color}‖{hint.Text}‖color:end‖";
                break;
            }

            if (!string.IsNullOrWhiteSpace(extra))
            {
                if (!description.IsNullOrEmpty())
                    description += "\n";
                description += extra;
            }
        }

        private static string BuildItemComponentEffects(Item item, Throwable skipThrowable = null)
        {
            var sb = new StringBuilder();
            foreach (var comp in item.Components)
            {
                if (comp.statusEffectLists == null) continue;
                if (comp.InheritStatusEffects) continue;
                if (skipThrowable != null && comp == skipThrowable) continue;
                foreach (var list in comp.statusEffectLists.Values)
                {
                    string se = BuildStatusEffects(list, "附加效果", item);
                    if (!string.IsNullOrEmpty(se)) sb.Append(se);
                }
            }
            return sb.ToString();
        }

        private static string BuildAttackInfo(string title, Attack atk, float reload, Item item)
        {
            var sb = new StringBuilder();
            sb.AppendLine($"‖color:gui.orange‖<{title}>‖color:end‖");
            sb.AppendLine($"穿甲: {atk.Penetration:F2}{PenArmorSuffix(atk.Penetration)}");
            sb.AppendLine($"结构伤害: {atk.StructureDamage:F1}");
            sb.AppendLine($"物品伤害: {atk.ItemDamage:F1}");
            sb.AppendLine($"重装: {reload:F2}s");

            string affs = BuildAfflictions(atk);
            if (!string.IsNullOrEmpty(affs)) sb.AppendLine(affs);

            // 攻击自带状态效果
            string atkEffects = BuildStatusEffects(atk.StatusEffects, "攻击效果", item);
            if (!string.IsNullOrEmpty(atkEffects)) sb.Append(atkEffects);

            // 组件附加状态效果
            foreach (var comp in item.Components)
            {
                if (comp.statusEffectLists == null) continue;
                if (comp.InheritStatusEffects) continue;
                foreach (var list in comp.statusEffectLists.Values)
                {
                    string se = BuildStatusEffects(list, "附加效果", item);
                    if (!string.IsNullOrEmpty(se)) sb.Append(se);
                }
            }

            return sb.ToString().Trim();
        }

        private static string BuildProjectileInfo(Projectile proj)
        {
            var sb = new StringBuilder();
            int bullets = (proj.Hitscan && proj.HitScanCount > 0) ? proj.HitScanCount : 1;

            sb.AppendLine("‖color:gui.orange‖<发射物>‖color:end‖");
            sb.AppendLine($"穿甲: {proj.Attack.Penetration:F2}{PenArmorSuffix(proj.Attack.Penetration)}");
            sb.AppendLine($"射弹数: {bullets}");
            sb.AppendLine($"结构伤害: {proj.Attack.StructureDamage:F1}");
            sb.AppendLine($"物品伤害: {proj.Attack.ItemDamage:F1}");

            if (proj.MaxTargetsToHit > 1)
                sb.AppendLine($"‖color:gui.orange‖穿透层数: {proj.MaxTargetsToHit}‖color:end‖");

            if (!proj.FriendlyFire)
                sb.AppendLine("‖color:gui.green‖可穿透友军‖color:end‖");

            ItemPrefab ammoPrefab = proj.Item.Prefab;
            var magazine = proj.Item.Container?.GetComponent<ItemContainer>();
            if (magazine?.GetType().FullName == "VCE_VirtualizedMagazine.VirtualizedMagazine")
            {
                var ammoId = (Identifier)magazine.GetType().GetProperty("TopIdentifier").GetValue(magazine);
                if (ItemPrefab.Prefabs.TryGet(ammoId, out var loadedPrefab)) ammoPrefab = loadedPrefab;
            }
            string headshot = BuildHeadshotMultiplierLine(ammoPrefab);
            if (!string.IsNullOrEmpty(headshot)) sb.AppendLine(headshot);

            string affs = BuildAfflictions(proj.Attack);
            if (!string.IsNullOrEmpty(affs)) sb.AppendLine(affs);

            string atkEffects = BuildStatusEffects(proj.Attack.StatusEffects, "攻击效果", proj.Item);
            if (!string.IsNullOrEmpty(atkEffects)) sb.Append(atkEffects);

            foreach (var comp in proj.Item.Components)
            {
                if (comp.statusEffectLists == null) continue;
                if (comp.InheritStatusEffects) continue;
                // 仅显示投射物组件自身的效果，其他组件效果已在武器路径展示
                if (comp != proj) continue;
                foreach (var list in comp.statusEffectLists.Values)
                {
                    string se = BuildStatusEffects(list, "附加效果", proj.Item);
                    if (!string.IsNullOrEmpty(se)) sb.Append(se);
                }
            }

            return sb.ToString().Trim();
        }

        private static Projectile FindProjectile(Item item)
        {
            var p = item.GetComponent<Projectile>();
            if (p != null) return p;
            if (item.OwnInventory == null) return null;
            foreach (var it in item.OwnInventory.AllItems)
            {
                p = it.GetComponent<Projectile>();
                if (p != null) return p;
            }
            return null;
        }

        // 根据穿甲值生成防护等级提示：等级 = 穿甲值 * 10 截断取整，如 0.45 → 4级，1.0 → 10级
        // 穿甲值小于等于 0 时不追加
        private static string PenArmorSuffix(float penetration)
        {
            // 加 0.0001 余量修正浮点表示偏差（0.7f 实为 0.69999988，直接截断会得 6 而非 7）
            int level = (int)MathF.Floor(penetration * 10f + 0.0001f);
            if (level <= 0) return "";
            return $"    ‖color:gui.green‖可击穿{level}级防护‖color:end‖";
        }

        // 子弹爆头倍率：识别 prefab tags 中 deep_headshot_gunshotwound_<倍率>，
        // 如 _2 → 200%、_2.5 → 250%、_4 → 400%；无对应 tag 时不显示
        private static string BuildHeadshotMultiplierLine(ItemPrefab prefab)
        {
            if (prefab == null) return "";
            foreach (var tag in prefab.Tags)
            {
                const string prefix = "deep_headshot_gunshotwound_";
                string value = tag.Value;
                if (!value.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
                if (float.TryParse(value.Substring(prefix.Length), NumberStyles.Float, CultureInfo.InvariantCulture, out float mult) && mult > 0f)
                    return $"‖color:gui.green‖爆头倍率: {mult * 100f:F0}%‖color:end‖";
            }
            return "";
        }

        // 仅当物品或 prefab 的 tags 含 grenade 或 explosive 时才显示爆炸信息
        private static bool HasExplosiveTag(Item item)
        {
            return item != null &&
                   (item.HasTag(new Identifier("grenade")) || item.HasTag(new Identifier("explosive")));
        }

        private static bool HasExplosiveTag(ItemPrefab prefab)
        {
            return prefab != null &&
                   (prefab.Tags.Contains(new Identifier("grenade")) || prefab.Tags.Contains(new Identifier("explosive")));
        }

        // armorconfigs.lua 解析缓存：物品 identifier -> 配置条目的标量字段
        private static Dictionary<string, Dictionary<string, string>> armorConfigs;
        private static bool armorConfigsLoaded;

        // 深潜护甲配置信息（VCE 护甲系统以物品 identifier 作为配置键）
        internal static string BuildArmorConfigInfo(Item item)
            => BuildArmorConfigInfoById(item.Prefab.Identifier.Value);

        // prefab 版本：加工台配方没有物品实例，直接用 identifier 查配置
        internal static string BuildArmorConfigInfoById(string identifier)
        {
            EnsureArmorConfigsLoaded();
            if (armorConfigs == null ||
                !armorConfigs.TryGetValue(identifier, out var fields)) return "";

            var sb = new StringBuilder();
            if (fields.TryGetValue("level", out var level))
                sb.AppendLine($"防护等级: {level}");

            // 跳弹率按百分数显示；等级+2 以上的穿甲可无视跳弹直接碾压
            // 跳弹率为 0 时无实际意义，不显示（含碾压提示）
            if (TryGetFieldFloat(fields, "ricochetchance", out float ricochet) && ricochet > 0f)
            {
                string crushHint = "";
                if (TryGetFieldFloat(fields, "level", out float levelVal))
                {
                    int crushLevel = (int)levelVal + 2;
                    crushHint = $"    ‖color:gui.red‖会被≥{crushLevel}穿的子弹碾压，无视跳弹率‖color:end‖";
                }
                sb.AppendLine($"跳弹率: {ricochet * 100f:F0}%{crushHint}");
            }

            if (TryGetFieldFloat(fields, "aftereffectmultiplier", out float afterEffect))
                sb.AppendLine($"子弹击穿后效: {afterEffect:F2}    ‖color:gui.green‖越低越好‖color:end‖");

            if (TryGetFieldFloat(fields, "correctionmultiplier", out float correction))
                sb.AppendLine($"子弹未击穿伤害系数: {correction:F2}    ‖color:gui.green‖越低越好‖color:end‖");

            // enablecorrection=false 时修正逻辑不生效，不显示未击穿施加的伤害
            if (fields.TryGetValue("enablecorrection", out var enable) && enable == "true" &&
                fields.TryGetValue("correctionaffliction", out var affliction) && !affliction.IsNullOrWhiteSpace())
                sb.AppendLine($"‖color:gui.red‖未击穿施加的伤害: {Patch_WearableTooltip.ResolveAfflictionName(new Identifier(affliction))}‖color:end‖");

            return sb.ToString().TrimEnd();
        }

        // 从缓存字段中读取浮点值（解析器存的是字符串，统一按不变区域设置转换）
        private static bool TryGetFieldFloat(Dictionary<string, string> fields, string key, out float value)
        {
            value = 0f;
            return fields.TryGetValue(key, out var raw) &&
                   float.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
        }

        // 加工台配方信息：无物品实例，全部基于 prefab 构建
        // 深潜压弹器复装弹药箱识别表：tag → 提示文本与颜色（新增弹药箱类型只需在此追加一行）
        private static readonly (Identifier Tag, string Text, string Color)[] reloadBoxHints =
        {
            (new Identifier("lead_ammobox"), "放入深潜压弹器复装，需要铅制复装弹药箱", "gui.green"),
            (new Identifier("tit_ammobox"), "放入深潜压弹器复装，需要钛制复装弹药箱", "186,85,211,255"),
            (new Identifier("phy_ammobox"), "放入深潜压弹器复装，需要刚素复装弹药箱", "gui.orange"),
            (new Identifier("phy_ful_ammobox"), "放入深潜压弹器复装，需要雷刚复装弹药箱", "gui.blue"),
            (new Identifier("tun_ful_ammobox"), "放入深潜压弹器复装，需要钨刚复装弹药箱", "60,120,255,255"),
            (new Identifier("du_ammobox"), "放入深潜压弹器复装，需要贫铀复装弹药箱", "gui.yellow"),
        };

        internal static string BuildFabricatorExtraInfo(ItemPrefab prefab)
        {
            if (prefab == null) return "";
            var parts = new List<string>();

            string armorCfg = BuildArmorConfigInfoById(prefab.Identifier.Value);
            if (!string.IsNullOrWhiteSpace(armorCfg)) parts.Add(armorCfg);

            string ranged = ParseRangedFromPrefab(prefab);
            if (!string.IsNullOrWhiteSpace(ranged)) parts.Add(ranged);

            // 枪械配方只显示远程武器属性；其余配方本体无 Projectile 时，
            // 仅弹匣（ItemContainer 带 SpawnWithId）显示默认子弹，普通容器不罗列内容物
            if (string.IsNullOrWhiteSpace(ranged))
            {
                string ammo = ParseProjectileFromPrefab(prefab);
                if (!string.IsNullOrWhiteSpace(ammo))
                {
                    parts.Add(ammo);
                }
                else
                {
                    string containedAmmo = ParseContainedAmmoFromPrefab(prefab);
                    if (!string.IsNullOrWhiteSpace(containedAmmo)) parts.Add(containedAmmo);
                }
            }

            foreach (var hint in reloadBoxHints)
            {
                if (!prefab.Tags.Contains(hint.Tag)) continue;
                parts.Add($"‖color:{hint.Color}‖{hint.Text}‖color:end‖");
                break;
            }

            return string.Join("\n", parts);
        }

        // 加工台弹药信息缓存：配方提示在界面打开及过滤条件变化时重建，
        // 按 identifier 缓存解析结果（会话内 prefab 内容不变）
        private static readonly Dictionary<string, string> fabricatorAmmoCache = new Dictionary<string, string>();

        // 弹匣配方：从自身 ItemContainer 的 SpawnWithId 解析默认子弹（该子弹才是正确的弹匣内子弹）
        internal static string ParseContainedAmmoFromPrefab(ItemPrefab prefab)
        {
            if (prefab?.ConfigElement == null) return "";
            string key = prefab.Identifier.Value;
            if (fabricatorAmmoCache.TryGetValue(key, out string cached)) return cached;

            var seen = new HashSet<string> { key };
            var sb = new StringBuilder();
            bool hasContent = false;
            ResolveSpawnWithIdProjectiles(prefab.ConfigElement, 0, seen, sb, ref hasContent);

            string result = sb.ToString().TrimEnd();
            fabricatorAmmoCache[key] = result;
            return result;
        }

        // 解析容器的 SpawnWithId 默认生成物（与游戏源码 ItemContainer.SpawnAlwaysContainedItems 一致：
        // 逗号分隔 identifier，逐个在 ItemPrefab.Prefabs 中查找）；生成物无 Projectile 且自身为容器时继续下钻
        private static void ResolveSpawnWithIdProjectiles(ContentXElement element, int depth, HashSet<string> seen, StringBuilder sb, ref bool hasContent)
        {
            if (element == null || depth > 3) return;
            var containerEl = FindChildElement(element, "ItemContainer");
            var spawnAttr = containerEl?.GetAttribute("SpawnWithId");
            if (spawnAttr == null || string.IsNullOrWhiteSpace(spawnAttr.Value)) return;

            foreach (string part in spawnAttr.Value.Split(','))
            {
                string id = part.Trim();
                if (id.Length == 0) continue;
                if (!ItemPrefab.Prefabs.TryGet(id.ToIdentifier(), out var spawned) || spawned == null) continue;
                if (!seen.Add(spawned.Identifier.Value)) continue;

                if (spawned.ConfigElement != null && FindChildElement(spawned.ConfigElement, "Projectile") != null)
                {
                    AppendProjectileInfo(spawned, sb, ref hasContent);
                }
                else
                {
                    ResolveSpawnWithIdProjectiles(spawned.ConfigElement, depth + 1, seen, sb, ref hasContent);
                }
            }
        }

        private static void AppendProjectileInfo(ItemPrefab prefab, StringBuilder sb, ref bool hasContent)
        {
            string info = ParseProjectileFromPrefab(prefab);
            if (string.IsNullOrEmpty(info)) return;
            if (!hasContent)
            {
                sb.AppendLine("‖color:gui.orange‖<装填弹药>‖color:end‖");
                hasContent = true;
            }
            sb.Append(info);
            sb.AppendLine();
        }

        // 从 prefab XML 读取远程武器基础属性（物品实例不存在时的替代路径）
        // 深潜模组枪械多用 SwitchableRangedWeapon，兼容两种元素名
        private static string ParseRangedFromPrefab(ItemPrefab prefab)
        {
            if (prefab.ConfigElement == null) return "";
            var el = FindChildElement(prefab.ConfigElement, "SwitchableRangedWeapon")
                     ?? FindChildElement(prefab.ConfigElement, "RangedWeapon");
            if (el == null) return "";

            var sb = new StringBuilder();
            sb.AppendLine("‖color:gui.orange‖<远程武器>‖color:end‖");
            // SwitchableRangedWeapon 的穿甲多由芯片等动态修改，XML 无此属性时不显示，避免误导
            var penAttr = el.GetAttribute("penetration");
            if (penAttr != null)
            {
                float penetration = el.GetAttributeFloat("penetration", 0f);
                sb.AppendLine($"穿甲: {penetration:F2}{PenArmorSuffix(penetration)}");
            }
            sb.AppendLine($"重装: {el.GetAttributeFloat("reload", 0f):F2}s");
            sb.AppendLine($"散布: {el.GetAttributeFloat("spread", 0f):F2}");
            float maxCharge = el.GetAttributeFloat("maxchargetime", 0f);
            if (maxCharge > 0f)
                sb.AppendLine($"蓄力时间: {maxCharge:F2}s");
            sb.AppendLine($"过热条: {prefab.ConfigElement.GetAttributeFloat("maxcondition", 100f):F0}    ‖color:gui.blue‖水中开火不会过热‖color:end‖");
            // SwitchableRangedWeapon 的伤害倍率属性名为 weapondamagemodifier，RangedWeapon 为 damagemodifier
            float dmgMod = el.GetAttributeFloat("weapondamagemodifier", -1f);
            if (dmgMod < 0f) dmgMod = el.GetAttributeFloat("damagemodifier", 1f);
            sb.AppendLine($"伤害倍率: {dmgMod:F2}");
            return sb.ToString().TrimEnd();
        }

        // 首次调用时扫描已启用模组目录下的 armorconfigs.lua
        // Lua 全局表无法从 C# 端读取，故直接解析配置文件；结果按模组加载顺序覆盖
        private static void EnsureArmorConfigsLoaded()
        {
            if (armorConfigsLoaded) return;
            armorConfigsLoaded = true;
            armorConfigs = new Dictionary<string, Dictionary<string, string>>();
            foreach (var package in ContentPackageManager.EnabledPackages.Regular)
            {
                try
                {
                    string dir = package.Dir;
                    if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir)) continue;
                    foreach (string file in Directory.GetFiles(dir, "armorconfigs.lua", SearchOption.AllDirectories))
                        ParseArmorConfigFile(file);
                }
                catch (Exception e)
                {
                    LuaCsLogger.Log($"[MoreInformationDisplay] 扫描模组目录失败: {e.Message}");
                }
            }
        }

        // 解析单个 armorconfigs.lua：定位 ArmorConfigs/Armors 顶层赋值表，逐条提取标量字段
        private static void ParseArmorConfigFile(string filePath)
        {
            string content;
            try { content = File.ReadAllText(filePath); }
            catch { return; }

            var startMatch = Regex.Match(content, @"[\w.]+\.(?:ArmorConfigs|Armors)\s*=\s*\{");
            if (!startMatch.Success) return;

            var fieldRegex = new Regex(
                @"^\s*([A-Za-z_]\w*)\s*=\s*(?:""([^""]*)""|(-?[\d.]+)|(true|false))\s*,?\s*$",
                RegexOptions.Multiline);

            int n = content.Length;
            int i = startMatch.Index + startMatch.Length; // 停在顶层 '{' 之后
            while (i < n)
            {
                // 跳过空白与逗号
                while (i < n && (char.IsWhiteSpace(content[i]) || content[i] == ',')) i++;
                if (i >= n || content[i] == '}') break;

                // 跳过整行注释
                int lineEnd = content.IndexOf('\n', i);
                if (lineEnd < 0) break;
                if (content[i] == '-' && i + 1 < lineEnd && content[i + 1] == '-') { i = lineEnd + 1; continue; }

                int eq = content.IndexOf('=', i);
                if (eq < 0 || eq > lineEnd) { i = lineEnd + 1; continue; }

                string key = content.Substring(i, eq - i).Trim();
                if (!Regex.IsMatch(key, "^[A-Za-z_]\\w*$")) { i = eq + 1; continue; }

                int v = eq + 1;
                while (v < n && char.IsWhiteSpace(content[v])) v++;
                if (v >= n) break;

                // 非表条目（标量、函数、方法调用等）跳到行尾
                if (content[v] != '{')
                {
                    int eol = content.IndexOf('\n', v);
                    i = eol < 0 ? n : eol + 1;
                    continue;
                }

                // 花括号配对提取条目块
                int depth = 1;
                int j = v + 1;
                while (j < n && depth > 0)
                {
                    char c = content[j];
                    if (c == '{') depth++;
                    else if (c == '}') depth--;
                    j++;
                }
                string block = content.Substring(v, j - v);

                var fields = new Dictionary<string, string>();
                foreach (Match m in fieldRegex.Matches(block))
                {
                    string val = m.Groups[2].Success ? m.Groups[2].Value
                               : m.Groups[3].Success ? m.Groups[3].Value
                               : m.Groups[4].Value;
                    fields[m.Groups[1].Value] = val;
                }
                if (fields.Count > 0) armorConfigs[key] = fields;
                i = j;
            }
        }

        private static string BuildAfflictions(Attack atk)
        {
            if (atk.Afflictions == null || atk.Afflictions.Count == 0) return "";
            var lines = new List<string>();
            foreach (var kv in atk.Afflictions)
            {
                var aff = kv.Key;
                XElement e = kv.Value;
                string strength = aff.Strength.ToString("F1");
                if (e != null) strength = e.Attribute("strength")?.Value ?? e.Attribute("amount")?.Value ?? strength;
                string probability = (aff.Probability < 1f) ? $" ({aff.Probability * 100f:F0}%)" : "";
                string penetration = (aff.Penetration > 0f) ? $" [穿甲:{aff.Penetration:F2}]" : "";
                lines.Add($"‖color:gui.red‖{aff.Prefab.Name.Value}: {strength}{probability}{penetration}‖color:end‖");
            }
            return string.Join("\n", lines);
        }

        private static string BuildStatusEffects(IEnumerable<StatusEffect> effects, string headerTitle = "附加效果", Item item = null)
        {
            if (effects == null) return "";
            // 临时关闭附加效果与投掷效果板块（排查空标题问题），攻击效果仍显示
            // 板块关闭时仅隐藏标题与效果文本，其携带的爆炸内容仍独立显示
            bool suppressSection = headerTitle == "附加效果" || headerTitle == "投掷效果";
            var sb = new StringBuilder();
            foreach (var se in effects)
            {
                bool hasAffliction = se.Afflictions != null && se.Afflictions.Count > 0;
                bool hasReduce = se.ReduceAffliction != null && se.ReduceAffliction.Count > 0;
                bool hasExplosion = se.Explosions != null && se.Explosions.Any() && HasExplosiveTag(item);
                
                if (!hasAffliction && !hasReduce && !hasExplosion) continue;

                var targetList = new List<string>();
                if (se.HasTargetType(StatusEffect.TargetType.Character)) targetList.Add("使用者");
                if (se.HasTargetType(StatusEffect.TargetType.NearbyCharacters)) targetList.Add("附近生物");
                if (se.HasTargetType(StatusEffect.TargetType.AllLimbs)) targetList.Add("全肢体");
                
                bool hasUseTarget = se.HasTargetType(StatusEffect.TargetType.UseTarget);
                if (se.HasTargetType(StatusEffect.TargetType.Limb) && se.targetLimbs != null && se.targetLimbs.Length > 0)
                {
                    targetList.Add(BuildLimbGroups(se.targetLimbs));
                }
                else if (se.HasTargetType(StatusEffect.TargetType.Limb))
                {
                    targetList.Add("肢体");
                }

                if (targetList.Count == 0 && !hasUseTarget && !hasExplosion) continue;

                // 统一橙色标题（不再按目标类型区分红/青色）
                string headerColor = "gui.orange";

                // 先构建内容，无内容则整个状态效果不显示
                var content = new StringBuilder();

                if (!suppressSection && se.Duration > 0) content.AppendLine($"持续时间: {se.Duration:F1}s");

                if (!suppressSection && hasAffliction)
                {
                    var affLines = se.Afflictions.Select(aff => {
                        string prob = (aff.Probability > 0f && aff.Probability < 1f) ? $" ({aff.Probability * 100f:F0}%)" : "";
                        string pen = (aff.Penetration > 0f) ? $" [穿甲:{aff.Penetration:F2}]" : "";
                        return $"‖color:gui.red‖{aff.Prefab.Name.Value}: {aff.Strength}{prob}{pen}‖color:end‖";
                    });
                    content.AppendLine(string.Join("\n", affLines));
                }

                if (!suppressSection && hasReduce)
                {
                    var redLines = se.ReduceAffliction.Select(r => {
                        var prefab = AfflictionPrefab.Prefabs.FirstOrDefault(a => a.Identifier == r.AfflictionIdentifier);
                        string name = prefab != null ? prefab.Name.Value : r.AfflictionIdentifier.Value;
                        return $"‖color:gui.red‖{name}: -{r.ReduceAmount}‖color:end‖";
                    });
                    content.AppendLine(string.Join("\n", redLines));
                }

                if (hasExplosion)
                {
                    foreach (var exp in se.Explosions)
                    {
                        string expStr = BuildExplosion(exp);
                        if (!string.IsNullOrEmpty(expStr)) content.AppendLine(expStr);
                    }
                }

                if (content.Length == 0) continue;

                if (suppressSection)
                {
                    // 板块关闭时仅输出爆炸内容，不带标题
                    if (sb.Length > 0 && sb[sb.Length - 1] != '\n') sb.Append('\n');
                    sb.Append(content);
                    continue;
                }

                var headerSb = new StringBuilder();
                headerSb.Append($"‖color:{headerColor}‖<").Append(headerTitle);

                if (targetList.Count > 0)
                {
                    headerSb.Append(" 对");
                    for (int i = 0; i < targetList.Count; i++)
                    {
                        string targetText = targetList[i];
                        if (targetText.Contains("‖color:"))
                        {
                            // 如果是带颜色的肢体文本，先结束当前颜色，添加肢体，再重新开始当前颜色
                            headerSb.Append("‖color:end‖").Append(targetText).Append($"‖color:{headerColor}‖");
                        }
                        else
                        {
                            headerSb.Append(targetText);
                        }

                        if (i < targetList.Count - 1) headerSb.Append(",");
                    }
                }
                headerSb.Append(">‖color:end‖");

                if (sb.Length > 0 && sb[sb.Length - 1] != '\n') sb.Append('\n');
                sb.Append(headerSb.ToString()).Append('\n');
                sb.Append(content);
            }
            return sb.ToString();
        }

        private static string BuildLimbGroups(LimbType[] limbs)
        {
            var groups = new Dictionary<string, int>();
            foreach (var limb in limbs)
            {
                string group = limb switch
                {
                    LimbType.Head or LimbType.Jaw => "头部",
                    LimbType.Torso or LimbType.Waist => "躯干",
                    LimbType.LeftArm or LimbType.LeftForearm or LimbType.LeftHand => "左臂",
                    LimbType.RightArm or LimbType.RightForearm or LimbType.RightHand => "右臂",
                    LimbType.LeftLeg or LimbType.LeftThigh or LimbType.LeftFoot or LimbType.Legs => "左腿",
                    LimbType.RightLeg or LimbType.RightThigh or LimbType.RightFoot => "右腿",
                    _ => null
                };
                if (group != null)
                {
                    if (!groups.ContainsKey(group)) groups[group] = 0;
                    groups[group]++;
                }
            }

            var groupStrings = new List<string>();
            foreach (var kvp in groups)
            {
                // 分级颜色：黄 -> 橙 -> 红
                string color = kvp.Value switch
                {
                    1 => "gui.orange",
                    2 => "gui.orange",
                    _ => "gui.red"
                };
                groupStrings.Add($"‖color:{color}‖{kvp.Key}‖color:end‖");
            }
            return string.Join(",", groupStrings);
        }

        private static string BuildExplosion(Explosion exp)
        {
            if (exp?.Attack == null) return "";
            var atk = exp.Attack;
            var sb = new StringBuilder();
            sb.AppendLine("‖color:gui.orange‖<爆炸>‖color:end‖");
            sb.AppendLine($"范围: {atk.Range:F1}");
            sb.AppendLine($"结构伤害: {atk.StructureDamage:F1}");
            sb.Append($"物品伤害: {atk.ItemDamage:F1}");
            
            if (exp.EmpStrength > 0)
                sb.Append($"\nEMP强度: {exp.EmpStrength:F1}");
            if (exp.BallastFloraDamage > 0)
                sb.Append($"\n对丘脑泵: {exp.BallastFloraDamage:F1}");
            
            sb.AppendLine();

            string affs = BuildAfflictions(atk);
            if (!string.IsNullOrEmpty(affs)) sb.Append(affs);
            
            return sb.ToString().Trim();
        }

        private static string BuildMedicalInfo(Item item)
        {
            bool itemIsMedical = IsMedicalItem(item);
            var parts = new List<string>();
            HashSet<string> seenKeys = new HashSet<string>();
            foreach (var comp in item.Components)
            {
                if (comp.statusEffectLists == null) continue;
                foreach (var listPair in comp.statusEffectLists)
                {
                    ActionType actionType = listPair.Key;
                    if (actionType != ActionType.OnSuccess && actionType != ActionType.OnFailure 
                        && actionType != ActionType.OnUse && actionType != ActionType.OnSecondaryUse) continue;
                    foreach (var se in listPair.Value)
                    {
                        if (!itemIsMedical && !HasMedicalStatusTag(se)) continue;
                        string effectKey = BuildEffectKey(actionType, se);
                        if (!seenKeys.Add(effectKey)) continue;
                        
                        bool hasAff = se.Afflictions != null && se.Afflictions.Count > 0;
                        bool hasRed = se.ReduceAffliction != null && se.ReduceAffliction.Count > 0;
                        bool hasExp = se.Explosions != null && se.Explosions.Any();

                        if (!hasAff && !hasRed && !hasExp && se.Duration <= 0f) continue;

                        var sb = new StringBuilder();
                        string color = actionType == ActionType.OnSuccess ? "gui.green" : (actionType == ActionType.OnFailure ? "gui.red" : "gui.orange");
                        string prefix = actionType == ActionType.OnSuccess ? "<成功效果>" : (actionType == ActionType.OnFailure ? "<失败效果>" : "<使用效果>");

                        sb.AppendLine($"‖color:{color}‖{prefix} 持续时间:{se.Duration:F1}s‖color:end‖");
                        
                        if (hasAff)
                        {
                            var affLines = se.Afflictions.Select(aff => $"‖color:gui.red‖{aff.Prefab.Name.Value}: {aff.Strength}{(aff.Probability < 1f ? $" ({aff.Probability * 100f:F0}%)" : "")}‖color:end‖");
                            sb.AppendLine(string.Join("\n", affLines));
                        }
                        
                        if (hasRed)
                        {
                            var redLines = se.ReduceAffliction.Select(r => {
                                var prefab = AfflictionPrefab.Prefabs.FirstOrDefault(a => a.Identifier == r.AfflictionIdentifier);
                                return $"‖color:gui.red‖{(prefab != null ? prefab.Name.Value : r.AfflictionIdentifier.Value)}: -{r.ReduceAmount}‖color:end‖";
                            });
                            sb.AppendLine(string.Join("\n", redLines));
                        }

                        if (hasExp)
                        {
                            foreach (var exp in se.Explosions)
                            {
                                string es = BuildExplosion(exp);
                                if (!string.IsNullOrEmpty(es)) sb.AppendLine(es);
                            }
                        }

                        parts.Add(sb.ToString().Trim());
                    }
                }
            }
            return string.Join("\n", parts);
        }

        private static bool IsMedicalItem(Item item)
        {
            if (item == null) return false;
            // 检查物品分类
            if ((item.Prefab.Category & MapEntityCategory.Medical) != 0) return true;
            // 检查物品标签
            if (item.HasTag(new Identifier("medical"))) return true;
            // 检查是否有组件状态效果携带 medical 标签
            foreach (var comp in item.Components)
            {
                if (comp.statusEffectLists == null) continue;
                foreach (var list in comp.statusEffectLists.Values)
                {
                    if (list.Any(se => HasMedicalStatusTag(se))) return true;
                }
            }
            return false;
        }

        private static bool HasMedicalStatusTag(StatusEffect se)
        {
            if (se?.Tags == null) return false;
            return se.Tags.Split(',').Select(t => t.Trim()).Any(t => t.Equals("medical", StringComparison.OrdinalIgnoreCase));
        }

        private static string BuildEffectKey(ActionType actionType, StatusEffect effect)
        {
            var sb = new StringBuilder();
            sb.Append(actionType).Append('|').Append(effect.Duration.ToString("0.00"));
            if (effect.Afflictions != null)
                foreach (var a in effect.Afflictions.OrderBy(a => a.Prefab.Identifier.Value).ThenBy(a => a.Strength))
                    sb.Append("|A:").Append(a.Prefab.Identifier.Value).Append(':').Append(a.Strength.ToString("0.00"));
            if (effect.ReduceAffliction != null)
                foreach (var r in effect.ReduceAffliction.OrderBy(r => r.AfflictionIdentifier.Value).ThenBy(r => r.ReduceAmount))
                    sb.Append("|R:").Append(r.AfflictionIdentifier.Value).Append(':').Append(r.ReduceAmount.ToString("0.00"));
            return sb.ToString();
        }

        private static string BuildAmmoBoxInfo(Item item)
        {
            var container = item.GetComponent<ItemContainer>();
            if (container?.ContainableItems == null || container.ContainableItems.Count == 0) return "";

            var sb = new StringBuilder();
            bool hasContent = false;

            foreach (var containable in container.ContainableItems)
            {
                foreach (var identifier in containable.Identifiers)
                {
                    if (!ItemPrefab.Prefabs.TryGet(identifier, out var prefab)) continue;
                    string info = ParseProjectileFromPrefab(prefab);
                    if (string.IsNullOrEmpty(info)) continue;

                    if (!hasContent)
                    {
                        sb.AppendLine("‖color:gui.orange‖<装填弹药>‖color:end‖");
                        hasContent = true;
                    }
                    sb.Append(info);
                    sb.AppendLine();
                }
            }

            return sb.ToString().TrimEnd();
        }

        private static List<string> ParseExplosionsFromXml(ContentXElement parent)
        {
            var result = new List<string>();
            foreach (var seEl in parent.Elements().Where(e =>
                e.Name.LocalName.Equals("StatusEffect", StringComparison.OrdinalIgnoreCase)))
            {
                var typeAttr = seEl.GetAttribute("type");
                if (typeAttr == null) continue;
                if (!typeAttr.Value.Equals("OnImpact", StringComparison.OrdinalIgnoreCase)) continue;

                foreach (var expEl in seEl.Elements().Where(e =>
                    e.Name.LocalName.Equals("Explosion", StringComparison.OrdinalIgnoreCase)))
                {
                    var sb = new StringBuilder();

                    float range = 0, structureDamage = 0, itemDamage = 0;
                    float empStrength = 0, ballastFloraDamage = 0;

                    var rangeAttr = expEl.GetAttribute("range");
                    if (rangeAttr != null) float.TryParse(rangeAttr.Value, out range);
                    var sdAttr = expEl.GetAttribute("structuredamage");
                    if (sdAttr != null) float.TryParse(sdAttr.Value, out structureDamage);
                    var idAttr = expEl.GetAttribute("itemdamage");
                    if (idAttr != null) float.TryParse(idAttr.Value, out itemDamage);
                    var empAttr = expEl.GetAttribute("empstrength");
                    if (empAttr != null) float.TryParse(empAttr.Value, out empStrength);
                    var bfAttr = expEl.GetAttribute("ballastfloradamage");
                    if (bfAttr != null) float.TryParse(bfAttr.Value, out ballastFloraDamage);

                    sb.Append($"范围:{range:F1}");
                    sb.Append($"\n结构伤害:{structureDamage:F1}");
                    sb.Append($"\n物品伤害:{itemDamage:F1}");

                    if (empStrength > 0)
                        sb.Append($"\nEMP:{empStrength:F1}");
                    if (ballastFloraDamage > 0)
                        sb.Append($"\n对丘脑泵:{ballastFloraDamage:F1}");

                    var affs = ParseAfflictionsFromXml(expEl);
                    if (affs.Count > 0)
                        sb.Append("\n    " + string.Join("\n    ", affs));

                    result.Add(sb.ToString());
                }
            }
            return result;
        }

        private static string ParseProjectileFromPrefab(ItemPrefab prefab)
        {
            var cfg = prefab.ConfigElement;
            if (cfg == null) return "";

            var projEl = FindChildElement(cfg, "Projectile");
            if (projEl == null) return "";

            var sb = new StringBuilder();
            sb.Append($"‖color:gui.orange‖{prefab.Name.Value}‖color:end‖");

            int hitscan = 0;
            var hsAttr = projEl.GetAttribute("hitscancount");
            if (hsAttr != null) int.TryParse(hsAttr.Value, out hitscan);
            int bullets = hitscan > 0 ? hitscan : 1;

            int maxTargets = 0;
            var mtAttr = projEl.GetAttribute("MaxTargetsToHit");
            if (mtAttr != null) int.TryParse(mtAttr.Value, out maxTargets);

            var atkEl = FindChildElement(projEl, "Attack");
            if (atkEl != null)
            {
                float penetration = 0;
                float structureDamage = 0;
                float itemDamage = 0;
                var pn = atkEl.GetAttribute("penetration");
                if (pn != null) float.TryParse(pn.Value, out penetration);
                var sd = atkEl.GetAttribute("structuredamage");
                if (sd != null) float.TryParse(sd.Value, out structureDamage);
                var idAttr = atkEl.GetAttribute("itemdamage");
                if (idAttr != null) float.TryParse(idAttr.Value, out itemDamage);

                sb.Append($"穿甲:{penetration:F2}{PenArmorSuffix(penetration)}");
                sb.Append($"\n射弹数:{bullets}");
                sb.Append($"\n结构伤害:{structureDamage:F1}");
                sb.Append($"\n物品伤害:{itemDamage:F1}");
                if (maxTargets > 1)
                    sb.Append($"\n‖color:gui.orange‖穿透层数:{maxTargets}‖color:end‖");
                if (!projEl.GetAttributeBool("friendlyfire", true))
                    sb.Append("\n‖color:gui.green‖可穿透友军‖color:end‖");
                string headshot = BuildHeadshotMultiplierLine(prefab);
                if (!string.IsNullOrEmpty(headshot)) sb.Append('\n').Append(headshot);

                var afflictions = ParseAfflictionsFromXml(atkEl);
                if (afflictions.Count > 0)
                    sb.Append("\n  " + string.Join("\n  ", afflictions));

                // 临时关闭附加效果板块（排查空标题问题）
                //var atkSeLines = ParseStatusEffectsFromXml(atkEl);
                //if (atkSeLines.Count > 0)
                //{
                //    foreach (var line in atkSeLines)
                //    {
                //        if (sb.Length > 0 && sb[sb.Length - 1] != '\n')
                //            sb.AppendLine();
                //        sb.Append(line);
                //    }
                //}
            }
            else
            {
                sb.Append($"\n射弹数:{bullets}");
                if (maxTargets > 1)
                    sb.Append($"\n‖color:gui.orange‖穿透层数:{maxTargets}‖color:end‖");
                if (!projEl.GetAttributeBool("friendlyfire", true))
                    sb.Append("\n‖color:gui.green‖可穿透友军‖color:end‖");
                string headshot = BuildHeadshotMultiplierLine(prefab);
                if (!string.IsNullOrEmpty(headshot)) sb.Append('\n').Append(headshot);
            }

            // 仅当弹药 prefab 的 tags 含 grenade 或 explosive 时才显示爆炸信息
            var explosionLines = new List<string>();
            if (HasExplosiveTag(prefab))
            {
                explosionLines.AddRange(ParseExplosionsFromXml(projEl));
                if (cfg != projEl)
                {
                    var itemExplosions = ParseExplosionsFromXml(cfg);
                    if (itemExplosions.Count > 0)
                        explosionLines.AddRange(itemExplosions);
                }
            }

            if (explosionLines.Count > 0)
            {
                sb.AppendLine();
                sb.AppendLine("‖color:gui.orange‖<爆炸>‖color:end‖");
                foreach (var line in explosionLines)
                    sb.AppendLine(line);
            }

            // 临时关闭附加效果板块（排查空标题问题）
            //var statusEffectLines = ParseStatusEffectsFromXml(projEl);
            //if (cfg != projEl)
            //{
            //    var itemStatusEffects = ParseStatusEffectsFromXml(cfg);
            //    if (itemStatusEffects.Count > 0)
            //        statusEffectLines.AddRange(itemStatusEffects);
            //}

            //if (statusEffectLines.Count > 0)
            //{
            //    foreach (var line in statusEffectLines)
            //    {
            //        if (sb.Length > 0 && sb[sb.Length - 1] != '\n')
            //            sb.AppendLine();
            //        sb.Append(line);
            //    }
            //}

            return sb.ToString();
        }

        private static List<string> ParseAfflictionsFromXml(ContentXElement element)
        {
            var result = new List<string>();
            foreach (var affEl in element.GetChildElements("Affliction"))
            {
                string id = affEl.GetAttribute("identifier")?.Value ?? "???";
                float strength = 0;
                float.TryParse(affEl.GetAttribute("strength")?.Value ?? "0", out strength);
                float probability = 1f;
                var probAttr = affEl.GetAttribute("probability");
                if (probAttr != null) float.TryParse(probAttr.Value, out probability);

                var prefab = AfflictionPrefab.Prefabs.FirstOrDefault(a => a.Identifier == new Identifier(id));
                string name = prefab != null ? prefab.Name.Value : id;
                string probStr = probability < 1f ? $" ({probability * 100f:F0}%)" : "";
                result.Add($"‖color:gui.red‖{name}: {strength:F1}{probStr}‖color:end‖");
            }
            return result;
        }

        private static List<string> ParseReduceAfflictionsFromXml(ContentXElement element)
        {
            var result = new List<string>();
            foreach (var redEl in element.GetChildElements("ReduceAffliction"))
            {
                string id = redEl.GetAttribute("identifier")?.Value ?? redEl.GetAttribute("affliction")?.Value ?? "???";
                float amount = 0;
                float.TryParse(redEl.GetAttribute("reduceamount")?.Value ?? "0", out amount);

                var prefab = AfflictionPrefab.Prefabs.FirstOrDefault(a => a.Identifier == new Identifier(id));
                string name = prefab != null ? prefab.Name.Value : id;
                result.Add($"‖color:gui.red‖{name}: -{amount:F1}‖color:end‖");
            }
            return result;
        }

        private static List<string> ParseStatusEffectsFromXml(ContentXElement parent)
        {
            var result = new List<string>();
            foreach (var seEl in parent.Elements().Where(e =>
                e.Name.LocalName.Equals("StatusEffect", StringComparison.OrdinalIgnoreCase)))
            {
                float duration = 0;
                var durAttr = seEl.GetAttribute("duration");
                if (durAttr != null) float.TryParse(durAttr.Value, out duration);

                var afflictions = ParseAfflictionsFromXml(seEl);
                var reduceAffs = ParseReduceAfflictionsFromXml(seEl);

                if (afflictions.Count == 0 && reduceAffs.Count == 0) continue;

                string targetAttr = seEl.GetAttribute("target")?.Value ?? "";
                string[] targetParts = string.IsNullOrEmpty(targetAttr)
                    ? new string[0]
                    : targetAttr.Split(',').Select(s => s.Trim()).ToArray();

                var targetList = new List<string>();
                bool hasUseTarget = false;
                foreach (var t in targetParts)
                {
                    if (t.Equals("Character", StringComparison.OrdinalIgnoreCase))
                        targetList.Add("使用者");
                    else if (t.Equals("NearbyCharacters", StringComparison.OrdinalIgnoreCase))
                        targetList.Add("附近生物");
                    else if (t.Equals("AllLimbs", StringComparison.OrdinalIgnoreCase))
                        targetList.Add("全肢体");
                    else if (t.Equals("UseTarget", StringComparison.OrdinalIgnoreCase))
                        hasUseTarget = true;
                }

                string targetLimbsAttr = seEl.GetAttribute("targetlimbs")?.Value ?? "";
                if (!string.IsNullOrEmpty(targetLimbsAttr))
                {
                    var limbParts = targetLimbsAttr.Split(',').Select(s => s.Trim()).ToArray();
                    targetList.Add(BuildLimbGroupsFromStrings(limbParts));
                }
                else if (targetParts.Any(t => t.Equals("Limb", StringComparison.OrdinalIgnoreCase)))
                {
                    targetList.Add("肢体");
                }

                if (targetList.Count == 0 && !hasUseTarget && duration <= 0) continue;

                // 无实际内容（无持续时间、效果、减少项）时整个状态效果不显示
                if (duration <= 0 && afflictions.Count == 0 && reduceAffs.Count == 0) continue;

                // 统一橙色标题（不再按目标类型区分红/青色）
                string headerColor = "gui.orange";

                var headerSb = new StringBuilder();
                headerSb.Append($"‖color:{headerColor}‖<附加效果");

                if (targetList.Count > 0)
                {
                    headerSb.Append(" 对");
                    for (int i = 0; i < targetList.Count; i++)
                    {
                        string targetText = targetList[i];
                        if (targetText.Contains("‖color:"))
                            headerSb.Append("‖color:end‖").Append(targetText).Append($"‖color:{headerColor}‖");
                        else
                            headerSb.Append(targetText);

                        if (i < targetList.Count - 1) headerSb.Append(",");
                    }
                }
                headerSb.Append(">‖color:end‖");

                var sb = new StringBuilder();
                sb.AppendLine(headerSb.ToString());

                if (duration > 0) sb.AppendLine($"持续时间: {duration:F1}s");

                if (afflictions.Count > 0)
                    sb.AppendLine(string.Join("\n", afflictions));

                if (reduceAffs.Count > 0)
                    sb.AppendLine(string.Join("\n", reduceAffs));

                result.Add(sb.ToString().TrimEnd());
            }
            return result;
        }

        private static string BuildLimbGroupsFromStrings(string[] limbNames)
        {
            var groups = new Dictionary<string, int>();
            foreach (var limb in limbNames)
            {
                string l = limb.Trim();
                string group = null;
                if (l.Equals("Head", StringComparison.OrdinalIgnoreCase) || l.Equals("Jaw", StringComparison.OrdinalIgnoreCase))
                    group = "头部";
                else if (l.Equals("Torso", StringComparison.OrdinalIgnoreCase) || l.Equals("Waist", StringComparison.OrdinalIgnoreCase))
                    group = "躯干";
                else if (l.Equals("LeftArm", StringComparison.OrdinalIgnoreCase) || l.Equals("LeftForearm", StringComparison.OrdinalIgnoreCase) || l.Equals("LeftHand", StringComparison.OrdinalIgnoreCase))
                    group = "左臂";
                else if (l.Equals("RightArm", StringComparison.OrdinalIgnoreCase) || l.Equals("RightForearm", StringComparison.OrdinalIgnoreCase) || l.Equals("RightHand", StringComparison.OrdinalIgnoreCase))
                    group = "右臂";
                else if (l.Equals("LeftLeg", StringComparison.OrdinalIgnoreCase) || l.Equals("LeftThigh", StringComparison.OrdinalIgnoreCase) || l.Equals("LeftFoot", StringComparison.OrdinalIgnoreCase) || l.Equals("Legs", StringComparison.OrdinalIgnoreCase))
                    group = "左腿";
                else if (l.Equals("RightLeg", StringComparison.OrdinalIgnoreCase) || l.Equals("RightThigh", StringComparison.OrdinalIgnoreCase) || l.Equals("RightFoot", StringComparison.OrdinalIgnoreCase))
                    group = "右腿";

                if (group != null)
                {
                    if (!groups.ContainsKey(group)) groups[group] = 0;
                    groups[group]++;
                }
            }

            var groupStrings = new List<string>();
            foreach (var kvp in groups)
            {
                string color = kvp.Value switch
                {
                    1 => "gui.orange",
                    2 => "gui.orange",
                    _ => "gui.red"
                };
                groupStrings.Add($"‖color:{color}‖{kvp.Key}‖color:end‖");
            }
            return string.Join(",", groupStrings);
        }

        private static ContentXElement FindChildElement(ContentXElement parent, string name)
        {
            return parent.Elements().FirstOrDefault(e =>
                e.Name.LocalName.Equals(name, StringComparison.OrdinalIgnoreCase));
        }

        private static string BuildWifiInfo(WifiComponent wifi)
        {
            var player = Character.Controlled;
            bool isMismatch = player != null && wifi.TeamID != player.TeamID;
            var sb = new StringBuilder();
            if (isMismatch)
                sb.AppendLine("‖color:gui.red‖非同队伍设备‖color:end‖");
            sb.Append($"‖color:gui.orange‖通信范围: {wifi.Range / 100f:F0}米‖color:end‖");
            return sb.ToString();
        }

        private static string BuildThrowableInfo(Throwable throwable)
        {
            var sb = new StringBuilder();
            sb.AppendLine("‖color:gui.orange‖<投掷物>‖color:end‖");
            sb.Append($"投掷力度: {throwable.ThrowForce:F1}");

            if (throwable.statusEffectLists != null)
            {
                foreach (var list in throwable.statusEffectLists.Values)
                {
                    string se = BuildStatusEffects(list, "投掷效果", throwable.Item);
                    if (!string.IsNullOrEmpty(se)) sb.Append('\n').Append(se);
                }
            }

            return sb.ToString().Trim();
        }
    }

    [HarmonyPatch(typeof(Wearable))]
    internal static class Patch_WearableTooltip
    {
        internal static MethodBase TargetMethod()
        {
            return AccessTools.Method(typeof(Wearable), nameof(Wearable.AddTooltipInfo),
                new Type[] { typeof(LocalizedString).MakeByRefType(), typeof(LocalizedString).MakeByRefType() });
        }

        internal static bool Prefix(Wearable __instance, ref LocalizedString name, ref LocalizedString description)
        {
            // 显示条件：仅当鼠标悬停物品且按住 Shift 时显示；未按 Shift 时放行原方法
            if (!PlayerInput.IsShiftDown()) return true;
            string armorInfo = BuildWearableArmorInfo(__instance);
            if (!string.IsNullOrWhiteSpace(armorInfo))
            {
                if (!description.IsNullOrWhiteSpace())
                    description += "\n";
                description += armorInfo;
            }

            // armorconfigs.lua 配置信息（VCE 护甲系统的等级/后效等）
            // 仅当 Wearable 是第一个组件时由本前缀注入；否则第一个无重写组件会触发
            // ItemComponent 后缀的第一组件分支注入，这里再加就会双重显示
            if (__instance == __instance.Item.Components.First())
            {
                string armorCfg = Patch_ItemStatsTooltip.BuildArmorConfigInfo(__instance.Item);
                if (!string.IsNullOrWhiteSpace(armorCfg))
                {
                    if (!description.IsNullOrWhiteSpace())
                        description += "\n";
                    description += armorCfg;
                }
            }

            AppendSkillModifiers(__instance, ref description);
            return false;
        }

        private static void AppendSkillModifiers(Wearable wearable, ref LocalizedString description)
        {
            if (wearable.SkillModifiers == null || wearable.SkillModifiers.Count == 0) return;
            string colorStr = XMLExtensions.ToStringHex(GUIStyle.Green);
            foreach (var kv in wearable.SkillModifiers)
            {
                int rounded = (int)Math.Round(kv.Value);
                if (rounded == 0) continue;
                string skillName = TextManager.Get($"SkillName.{kv.Key}").Fallback(kv.Key.Value).Value;
                if (!description.IsNullOrWhiteSpace()) description += "\n";
                description += $"  ‖color:{colorStr}‖{rounded:+0;-#}‖color:end‖ {skillName}";
            }
        }

        private static string BuildWearableArmorInfo(Wearable wearable)
        {
            if (wearable.DamageModifiers == null) return "";
            var modifiers = wearable.DamageModifiers.ToList();
            if (modifiers.Count == 0) return "";

            var sb = new StringBuilder();
            AppendModifierGroupLines(sb, modifiers);

            return sb.ToString().TrimEnd();
        }

        private static void AppendModifierGroupLines(StringBuilder sb, List<DamageModifier> modifiers)
        {
            var groups = GroupModifiersByEffect(modifiers);
            foreach (var group in groups)
            {
                var allNames = new List<string>();
                foreach (var mod in group)
                    allNames.AddRange(ResolveModifierAfflictionNames(mod));
                var uniqueNames = allNames.Distinct().ToList();

                float protection = (1 - group[0].DamageMultiplier) * 100;

                string protectionStr = "";
                if (Math.Abs(protection) > 0.01f)
                {
                    protectionStr = protection > 0
                        ? $"‖color:gui.green‖-{protection:F0}%‖color:end‖"
                        : $"‖color:gui.red‖+{-protection:F0}%‖color:end‖";
                }

                int avoidPercent = (int)Math.Round((1 - group[0].ProbabilityMultiplier) * 100f);
                string probStr = avoidPercent > 0
                    ? $" ‖color:gui.orange‖[免伤率:{avoidPercent}%]‖color:end‖"
                    : "";

                foreach (var name in uniqueNames)
                {
                    if (string.IsNullOrEmpty(protectionStr) && string.IsNullOrEmpty(probStr))
                        continue;
                    sb.AppendLine($"  {protectionStr} {name}{probStr}".TrimEnd());
                }
            }
        }

        private static List<List<DamageModifier>> GroupModifiersByEffect(List<DamageModifier> modifiers)
        {
            var result = new List<List<DamageModifier>>();
            var remaining = new HashSet<DamageModifier>(modifiers);

            foreach (var mod in modifiers)
            {
                if (!remaining.Contains(mod)) continue;
                var group = modifiers.Where(m =>
                    remaining.Contains(m) &&
                    Math.Abs(m.DamageMultiplier - mod.DamageMultiplier) < 0.0001f &&
                    Math.Abs(m.ProbabilityMultiplier - mod.ProbabilityMultiplier) < 0.0001f).ToList();
                foreach (var m in group) remaining.Remove(m);
                result.Add(group);
            }
            return result;
        }

        private static List<string> ResolveModifierAfflictionNames(DamageModifier mod)
        {
            var names = new List<string>();

            foreach (var id in mod.ParsedAfflictionIdentifiers)
                names.Add(ResolveAfflictionName(id));

            foreach (var typeId in mod.ParsedAfflictionTypes)
            {
                var name = AfflictionPrefab.List
                    .FirstOrDefault(ap => ap.Identifier == typeId)
                    ?.Name
                    ?? TextManager.Get($"afflictiontype.{typeId}").Fallback(typeId.Value);
                names.Add(name.Value);
            }

            return names;
        }

        internal static string ResolveAfflictionName(Identifier id)
        {
            return (AfflictionPrefab.List
                    .FirstOrDefault(ap => ap.Identifier == id)
                    ?.Name
                    ?? TextManager.Get($"afflictiontype.{id}").Fallback(id.Value))
                .Value;
        }
    }

    // 加工台配方提示不经过 ItemComponent.AddTooltipInfo，用后缀补充属性信息
    // 注意：配方提示在界面打开时一次性构建，无法按住 Shift 动态刷新，故此处恒定附加
    [HarmonyPatch]
    internal static class Patch_FabricatorRecipeTooltip
    {
        internal static MethodBase TargetMethod()
        {
            return AccessTools.Method(typeof(Fabricator), "SetRecipeTooltip");
        }

        internal static void Postfix(GUIComponent component, FabricationRecipe recipe)
        {
            if (component == null || recipe?.TargetItem == null) return;

            string extra = Patch_ItemStatsTooltip.BuildFabricatorExtraInfo(recipe.TargetItem);
            string hint = "‖color:gui.red‖物品制造出来后，可鼠标悬停并按住Shift显示详情‖color:end‖";

            string baseTip = component.ToolTip?.ToString() ?? "";
            string combined = string.IsNullOrWhiteSpace(baseTip) ? "" : baseTip + "\n\n";
            if (!string.IsNullOrWhiteSpace(extra)) combined += extra + "\n\n";
            combined += hint;
            component.ToolTip = RichString.Rich(combined);
        }
    }
}
