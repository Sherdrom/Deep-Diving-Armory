-- ============================================================
-- AdjustEquipmentStatvalue-Config.lua
-- CONFIG 配置模块，通过全局变量 AdjustEquipmentConfig 暴露
-- ============================================================
--
-- [分类文件]
--   MainItems.lua          主体装备
--   ArmorPlates.lua        插板
--   ArmorUpgrades.lua      护甲升级
--   NeuralAdjustments.lua  神经调整
--   AssistUpgrades.lua     辅助升级
--   Weapon*.lua            手持武器配件与弹匣
--   HeldWeapons.lua        武器本体自带效果
--
-- >> 完整配置说明 <<
--
-- [顶层参数]
--   fallbackInterval (number)        失败效果、限时 Affliction 与复活兜底间隔（秒），默认 5；不会扫描全部装备。
--   dynamicInterval  (number)        when 动态条件的检查间隔（秒），默认 0.5；只访问当前动态效果来源。
--   wearableSlots   (InvSlotType[]) 主体装备所在的角色装备槽。
--   weaponSlots     (InvSlotType[]) 武器配件生效的手持槽。
--   debug           (bool)          是否启用调试输出，生产环境设为 false。
--
-- [mainItems — 主体装备]
--   只登记已将本配置所管效果从 XML 迁移到 Lua、可直接穿戴于装备栏的主体装备。
--   主体槽位由 wearableSlots 指定；装备时触发效果，脱下 / 丢弃 / 移除时自动撤销。
--
-- [subItems — 内部配件]
--   登记可放入主体装备库存的插板与芯片；无需加入 mainItems。
--   配件插入主体时触发效果，取出或主体脱离角色时自动撤销。
--
-- [weaponAccessories / heldWeapons — 武器配件、弹匣与武器本体效果]
--   配件和弹匣仅在母武器位于 weaponSlots 时生效；普通物品栏与背包中的武器不生效。
--   heldWeapons 管理武器本体自带的数值、标记及不能原生化的事件 Affliction。
--
-- 各配置表均以物品 Identifier (Prefab ID) 为键，支持以下效果字段：
--
--   stats  (table[]) 修改角色的 StatValue。每项是一条记录：
--     { statType = "StatTypes枚举名", value = number }
--     - statType: StatTypes 枚举中的成员名（大小写敏感），见附录A
--     - value: 数值。技能类（SkillBonus）为整数加成，百分比类（*Multiplier/Speed）为小数
--       （0.2 = 20%），Override 类为覆盖值
--     例: { statType = "WalkingSpeed", value = -0.15 }
--   statsKey (string) 同名原 Affliction 的共享键；双持相同效果时只应用一次，最后一个来源移除时撤销。
--
--   statGroup (string) 将本物品的 stats 归入一个可屏蔽组。
--   blocksStatGroups (string[]) 装备期间不应用指定组的 stats；插入/取出时事件驱动刷新。
--
--   flags  (string[]) 修改角色的 AbilityFlag。每项是 AbilityFlags 枚举成员名（大小写敏感），
--                     见附录B。装备时添加，脱下时移除。
--     例: flags = { "ImmuneToPressure", "MustWalk" }
--
--   talentMarkers (string[]) 供原生人才条件 AbilityConditionHasPermanentStat 读取的事件标记。
--                            只在插入 / 取出时更新，不创建 Affliction，不由 think 刷新。
--     例: talentMarkers = { "chip_frogman_1" }
--
--   resistances (table[]) 通过角色原生 AbilityResistance 添加全身抗性，不创建 Affliction。
--     { id = "Affliction Identifier 或 Type", multiplier = number, source = "可选共享键" }
--     - multiplier: 伤害倍率；0.5 = 50% 抗性，1 = 无抗性。不能用于限定肢体的抗性。
--     例: resistances = { { id = "burn", multiplier = 0.5 } }
--
--   affliction (table) 装备时向角色 Head 肢体施加指定 Affliction，脱下时移除。
--     单个: { id = "Affliction Prefab 标识名", strength = number }
--     复数: { { id = "id1", strength = 10 }, { id = "id2", strength = 20 } }
--     - id: AfflictionPrefab 的 Identifier 名称
--     - strength: 强度值（默认 1）
--     例: affliction = { id = "burn", strength = 50 }
--     例(多个): affliction = {
--                  { id = "deep_helmet_tac_detect", strength = 1 },
--                  { id = "deep_gpnvg18", strength = 1 },
--              }
--
--   以上 stats / flags / talentMarkers / resistances / affliction 均为选填，不填则跳过，无副作用。
--   effects (table[]) 可将同一物品拆成多个独立效果组；使用后不再读取该物品的顶层效果字段。
--   blockedByEnemyResistance (bool) 保留 deep_enemy_affliction_resistance 对原 Affliction Buff 的抑制。
--   when (function) 每 dynamicInterval 秒判断一次；仅在返回 true 时应用本效果组。
--   pollInterval (number) 可选；覆盖该物品 when 条件的检查间隔。
--
-- [附录A — 常用 StatTypes]
--   技能加成:     ElectricalSkillBonus  HelmSkillBonus  MechanicalSkillBonus
--                MedicalSkillBonus  WeaponsSkillBonus
--   技能覆盖:     HelmSkillOverride  MedicalSkillOverride  WeaponsSkillOverride
--                ElectricalSkillOverride  MechanicalSkillOverride
--   移动:         MovementSpeed  WalkingSpeed  SwimmingSpeed  PropulsionSpeed
--   生命:         MaximumHealthMultiplier
--   伤害:         AttackMultiplier  TeamAttackMultiplier
--   Buff/Debuff:  BuffDurationMultiplier  DebuffDurationMultiplier
--   医疗:         MedicalItemEffectivenessMultiplier
--   水流:         FlowResistance
--   远程:         RangedAttackSpeed  RangedAttackMultiplier  RangedSpreadReduction
--   炮塔:         TurretAttackSpeed  TurretPowerCostReduction  TurretChargeSpeed
--   近战:         MeleeAttackSpeed  MeleeAttackMultiplier
--   修理:         RepairSpeed  MechanicalRepairSpeed  ElectricalRepairSpeed
--                DeconstructorSpeedMultiplier  RepairToolStructureRepairMultiplier
--                RepairToolStructureDamageMultiplier  RepairToolDeattachTimeMultiplier
--                MaxRepairConditionMultiplierMechanical  MaxRepairConditionMultiplierElectrical
--   制造:         IncreaseFabricationQuality  GeneticMaterialRefineBonus
--                GeneticMaterialTaintedProbabilityReductionOnCombine
--   技能成长:     SkillGainSpeed  ExtraLevelGain
--
-- [附录B — 所有 AbilityFlags]
--   MustWalk                — 无法奔跑
--   ImmuneToPressure        — 免疫水压
--   IgnoredByEnemyAI        — 不会被敌人AI锁定
--   MoveNormallyWhileDragging — 拖拽尸体无移速惩罚
--   CanTinker               — 可修补物品
--   CanTinkerFabricatorsAndDeconstructors — 可修补制造台/分解台
--   TinkeringPowersDevices  — 修补后的物品不耗电
--   GainSkillPastMaximum    — 技能可超过100级
--   RetainExperienceForNewCharacter — 新角色保留经验
--   AllowSecondOrderedTarget — 技能影响前2个指令目标
--   AlwaysStayConscious     — 血量低于0仍保持清醒
--   CanNotDieToAfflictions  — 不会因 Affliction 死亡
--
-- ============================================================

-- 分类文件只返回物品配置表；此文件负责公共参数和合并。
local CATEGORY_PATH = Deep_Lua.Path
    .. "/Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config/"

local function loadCategory(fileName)
    return dofile(CATEGORY_PATH .. fileName)
end

local function merge(target, source)
    for itemId, cfg in pairs(source) do
        if target[itemId] then error("duplicate equipment config: " .. itemId) end
        target[itemId] = cfg
    end
end

local subItems = {}
merge(subItems, loadCategory("ArmorPlates.lua"))
merge(subItems, loadCategory("ArmorUpgrades.lua"))
merge(subItems, loadCategory("NeuralAdjustments.lua"))
merge(subItems, loadCategory("AssistUpgrades.lua"))

local weaponAccessories = {}
merge(weaponAccessories, loadCategory("WeaponGrips.lua"))
merge(weaponAccessories, loadCategory("WeaponSights.lua"))
merge(weaponAccessories, loadCategory("WeaponMuzzles.lua"))
merge(weaponAccessories, loadCategory("WeaponChips.lua"))
merge(weaponAccessories, loadCategory("WeaponUnderbarrels.lua"))
merge(weaponAccessories, loadCategory("WeaponMagazines.lua"))

local CONFIG = {
    fallbackInterval = 5.0,
    dynamicInterval = 0.5,
    debug = false,
    wearableSlots = {
        InvSlotType.Head,
        InvSlotType.InnerClothes,
        InvSlotType.OuterClothes,
        InvSlotType.Headset,
        InvSlotType.Card,
        InvSlotType.Bag,
    },
    weaponSlots = {
        InvSlotType.LeftHand,
        InvSlotType.RightHand,
    },
    mainItems = loadCategory("MainItems.lua"),
    subItems = subItems,
    weaponAccessories = weaponAccessories,
    heldWeapons = loadCategory("HeldWeapons.lua"),
}

_G.AdjustEquipmentConfig = CONFIG
