-- ============================================================
-- AdjustEquipmentStatvalue-Config.lua
-- CONFIG 配置模块，通过全局变量 AdjustEquipmentConfig 暴露
-- ============================================================
--
-- >> 完整配置说明 <<
--
-- [顶层参数]
--   fallbackInterval (number)        think 兜底巡检间隔（秒），默认 5。
--   wearableSlots   (InvSlotType[]) 主体装备所在的角色装备槽。
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
-- 两张表均以物品 Identifier (Prefab ID) 为键，支持以下效果字段：
--
--   stats  (table[]) 修改角色的 StatValue。每项是一条记录：
--     { statType = "StatTypes枚举名", value = number }
--     - statType: StatTypes 枚举中的成员名（大小写敏感），见附录A
--     - value: 数值。技能类（SkillBonus）为整数加成，百分比类（*Multiplier/Speed）为小数
--       （0.2 = 20%），Override 类为覆盖值
--     例: { statType = "WalkingSpeed", value = -0.15 }
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
--     { id = "Affliction Identifier 或 Type", multiplier = number }
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

local CONFIG = {
    fallbackInterval = 5.0,
    debug = false,
    wearableSlots = {
        InvSlotType.Head,
        InvSlotType.InnerClothes,
        InvSlotType.OuterClothes,
        InvSlotType.Headset,
        InvSlotType.Card,
        InvSlotType.Bag,
    },
    mainItems = {

        -- 主体：插板防弹衣
        ["deep_6b13"] = {
        },

        ["deep_Guardian"] = {
        },

        ["deep_6b23"] = {
        },

        ["deep_6b43"] = {
        },

        ["deep_defender"] = {
        },

        ["deep_fort_t5"] = {
        },

        ["gen4_heavy"] = {
        },

        ["gen4_protection"] = {
        },

        ["gen4_high_mobility"] = {
        },

        ["deep_hpc"] = {
        },

        ["deep_thor_protection"] = {
        },

        ["thor"] = {
        },

        ["deep_zhuk_6a"] = {
        },

        -- 主体：插板胸挂
        ["deep_Obsidian"] = {
        },

        ["deep_osprey_protection"] = {
        },

        ["deep_osprey"] = {
        },

        ["deep_bagariy"] = {
        },

        ["deep_tactec"] = {
        },

        ["deep_m1"] = {
        },

        -- 主体：辅助芯片胸挂
        ["tanzan_m22"] = {
        },

        ["deep_alpha"] = {
        },

        ["deep_separatists"] = {
        },

        ["deep_commando"] = {
        },

        ["deep_coalition"] = {
        },

        ["deep_mk3"] = {
        },

        ["deep_m43"] = {
        },

        ["deep_ghost"] = {
        },

        ["deep_thunder"] = {
        },

        -- 主体：辅助芯片耳机
        ["gssh01_headset"] = {
        },

        ["m32_headset"] = {
        },

        ["walker_headset"] = {
        },

        ["deep_yangtuo_hat"] = {
        },

        -- 主体：衣服
        ["deep_heyuanmu_suit"] = {
        },

        -- 主体：头盔
        ["6b47"] = {
        },

        ["deep_fast_helmet"] = {
        },

        ["deep_fast_helmet_black"] = {
        },

        ["deep_fast_helmet_ghost_origin"] = {
        },

        ["deep_fast_helmet_ghost"] = {
        },

        ["deep_helmet_striker"] = {
        },

        ["deep_helmet_heavy_trooper"] = {
        },

        ["deep_helmet_ranger"] = {
        },

        ["deep_helmet_sledge_hammer"] = {
        },

        ["6b47_test_18"] = {
        },

        ["deep_altyn"] = {
        },

        ["deep_maska"] = {
        },

        ["deep_kiver_m"] = {
        },

        ["deep_Fearless_Vanguard"] = {
        },

        ["deep_zsh_1_2_m"] = {
        },

        ["6b47_npc_night4"] = {
        },

        ["deep_fast_helmet_npc_night4"] = {
        },

        ["deep_fast_helmet_black_npc_night4"] = {
        },

        ["deep_fast_helmet_ghost_origin_npc_night4"] = {
        },

        ["6b47_npc"] = {
        },


        ["6b47_npc_thermalgoggles"] = {
        },

        ["6b47_npc_healthscan"] = {
        },

        ["deep_fast_helmet_npc"] = {
        },

        ["deep_fast_helmet_npc_thermalgoggles"] = {
        },

        ["deep_fast_helmet_npc_healthscan"] = {
        },

        ["deep_fast_helmet_black_npc"] = {
        },

        ["deep_fast_helmet_black_npc_thermalgoggles"] = {
        },

        ["deep_fast_helmet_black_npc_healthscan"] = {
        },

        ["deep_fast_helmet_ghost_origin_npc"] = {
        },

        ["deep_fast_helmet_ghost_origin_npc_thermalgoggles"] = {
        },

        ["deep_fast_helmet_ghost_origin_npc_healthscan"] = {
        },
    },
    subItems = {

        -- 子体：钢制主插板
        ["deep_plate_metal_3"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.15 },
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_4"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_5"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.25 },
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_6"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.3 },
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_7"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.35 },
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        ["deep_plate_metal_8"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.4 },
                { statType = "WeaponsSkillBonus", value = -40 },
            },
        },

        ["deep_plate_metal_9"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.45 },
                { statType = "WeaponsSkillBonus", value = -45 },
            },
        },

        ["deep_plate_metal_10"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.5 },
                { statType = "WeaponsSkillBonus", value = -50 },
            },
        },

        -- 子体：钢制手臂插板
        ["deep_plate_metal_arm_4"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_metal_arm_5"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_arm_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_arm_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_arm_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_arm_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        -- 子体：钢制腹股沟插板
        ["deep_plate_metal_groin_4"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_metal_groin_5"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_groin_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_groin_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_groin_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_groin_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        -- 子体：陶瓷主插板
        ["deep_plate_ceramic_4"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_5"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_6"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_7"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_8"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_9"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_10"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        -- 子体：陶瓷手臂插板
        ["deep_plate_ceramic_arm_4"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_5"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        -- 子体：陶瓷腹股沟插板
        ["deep_plate_ceramic_groin_4"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_5"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        -- 子体：复合主插板
        ["deep_plate_composite_6"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_7"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_8"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_9"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_10"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_rf3"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_br6"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        -- 子体：复合手臂插板
        ["deep_plate_composite_arm_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        -- 子体：复合腹股沟插板
        ["deep_plate_composite_groin_6"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_7"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_8"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_9"] = {
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },



        
        -- 子体：护甲升级
        ["chip_ergonomics"] = {
            stats = {
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "WeaponsSkillBonus", value = 20 },
            },
        },

        ["chip_heavy_armor"] = {
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -20 },
            },
            affliction = { id = "chip_heavy_armor", strength = 1 },
        },

        ["chip_strengthening_of_limbs"] = {
            affliction = { id = "chip_strengthening_of_limbs", strength = 1 },
        },

        ["chip_emergency_defibrillation"] = {
            talentMarkers = { "chip_emergency_defibrillation_detect" },
        },

        -- 子体：神经调整
        ["chip_cqb"] = {
            stats = {
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "AttackMultiplier", value = 0.1 },
            },
            resistances = { { id = "stun", multiplier = 0.75 } },
        },

        ["chip_frogman"] = {
            talentMarkers = { "chip_frogman_1" },
        },

        ["chip_marksman"] = {
            stats = {
                { statType = "AttackMultiplier", value = 0.5 },
                { statType = "RangedSpreadReduction", value = 0.5 },
                { statType = "RangedAttackSpeed", value = -0.2 },
            },
            talentMarkers = { "deep_chip_marksman_1" },
        },

        ["chip_commando"] = {
            stats = {
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "RangedSpreadReduction", value = -0.5 },
            },
            resistances = {
                { id = "stun", multiplier = 0.75 },
                { id = "damage", multiplier = 0.75 },
            },
            talentMarkers = { "deep_commando_1" },
        },

        ["chip_heavy_defender"] = {
            stats = {
                { statType = "AttackMultiplier", value = -0.3 },
                { statType = "RangedAttackSpeed", value = -0.3 },
            },
            blocksStatGroups = { "deep_plate_debuff" },
            talentMarkers = { "deep_chip_heavy_defender" },
        },

        ["chip_blaster"] = {
            stats = {
                { statType = "ExplosionDamageMultiplier", value = 0.5 },
                { statType = "ExplosionRadiusMultiplier", value = 0.2 },
            },
            affliction = {
                { id = "deep_chip_blaster", strength = 2 },
            },
        },

        ["chip_machinegunner"] = {
            affliction = {
                { id = "deep_machinegunner_detect", strength = 2 },
            },
        },

        ["chip_striker"] = {
            stats = {
                { statType = "RangedSpreadReduction", value = -0.3 },
                { statType = "RangedAttackSpeed", value = -0.2 },
                { statType = "WalkingSpeed", value = 0.2 },
            },
            resistances = {
                { id = "damage", multiplier = 0.75 },
                { id = "stun", multiplier = 0.75 },
            },
            talentMarkers = { "deep_chip_striker" },
        },

        ["chip_doc"] = {
            stats = {
                { statType = "MedicalSkillOverride", value = 60 },
                { statType = "WeaponsSkillOverride", value = 60 },
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "DebuffDurationMultiplier", value = 0.5 },
            },
            flags = { "MoveNormallyWhileDragging"}
        },

        -- 子体：辅助升级
        ["chip_learn"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 1 },
            },
        },

        ["chip_learn_2"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 2 },
                { statType = "HelmSkillOverride", value = 60 },
                { statType = "MedicalSkillOverride", value = 60 },
                { statType = "WeaponsSkillOverride", value = 60 },
                { statType = "ElectricalSkillOverride", value = 60 },
                { statType = "MechanicalSkillOverride", value = 60 },
            },
        },

        ["chip_learn_3"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 3 },
                { statType = "HelmSkillOverride", value = 80 },
                { statType = "MedicalSkillOverride", value = 80 },
                { statType = "WeaponsSkillOverride", value = 80 },
                { statType = "ElectricalSkillOverride", value = 80 },
                { statType = "MechanicalSkillOverride", value = 80 },
            },
            flags = { "GainSkillPastMaximum"}
        },

        ["chip_mechanical"] = {
            stats = {
                { statType = "MechanicalSkillGainSpeed", value = 1 },
                { statType = "MechanicalRepairSpeed", value = 0.3 },
                { statType = "RepairToolStructureRepairMultiplier", value = 0.3 },
                { statType = "RepairToolStructureDamageMultiplier", value = 0.3 },
                { statType = "RepairToolDeattachTimeMultiplier", value = 0.3 },
                { statType = "FlowResistance", value = 0.5 },
            },
        },

        ["chip_mechanical_2"] = {
            stats = {
                { statType = "MechanicalSkillGainSpeed", value = 2 },
                { statType = "MechanicalSkillOverride", value = 55 },
                { statType = "MechanicalRepairSpeed", value = 0.5 },
                { statType = "RepairToolStructureRepairMultiplier", value = 0.5 },
                { statType = "RepairToolStructureDamageMultiplier", value = 0.5 },
                { statType = "RepairToolDeattachTimeMultiplier", value = 0.5 },
                { statType = "DeconstructorSpeedMultiplier", value = 0.5 },
                { statType = "FabricationSpeed", value = 0.5 },
                { statType = "IncreaseFabricationQuality", value = 1 },
                { statType = "FlowResistance", value = 0.8 },
            },
        },

        ["chip_electrician"] = {
            stats = {
                { statType = "ElectricalSkillGainSpeed", value = 1 },
                { statType = "MaxRepairConditionMultiplierElectrical", value = 0.3 },
                { statType = "RepairSpeed", value = 0.5 },
                { statType = "FlowResistance", value = 0.5 },
            },
            resistances = {
                { id = "burn", multiplier = 0.5 },
                { id = "electricshock", multiplier = 0.5 },
            },
        },

        ["chip_electrician_2"] = {
            stats = {
                { statType = "ElectricalSkillGainSpeed", value = 2 },
                { statType = "ElectricalSkillOverride", value = 55 },
                { statType = "MaxRepairConditionMultiplierElectrical", value = 0.5 },
                { statType = "RepairSpeed", value = 0.7 },
                { statType = "DeconstructorSpeedMultiplier", value = 0.5 },
                { statType = "FabricationSpeed", value = 0.5 },
                { statType = "IncreaseFabricationQuality", value = 1 },
                { statType = "FlowResistance", value = 0.8 },
            },
            resistances = {
                { id = "burn", multiplier = 0.5 },
                { id = "electricshock", multiplier = 0.5 },
            },
        },

        ["chip_security"] = {
            stats = {
                { statType = "WeaponsSkillGainSpeed", value = 1 },
                { statType = "MovementSpeed", value = 0.1 },
                { statType = "MaximumHealthMultiplier", value = 0.1 },
                { statType = "MeleeAttackMultiplier", value = 0.2 },
                { statType = "MeleeAttackSpeed", value = 0.2 },
                { statType = "BuffDurationMultiplier", value = 0.2 },
                { statType = "DebuffDurationMultiplier", value = 0.2 },
                { statType = "FlowResistance", value = 0.5 },
                { statType = "RangedSpreadReduction", value = 0.2 },
                { statType = "TurretAttackSpeed", value = 0.1 },
            },
        },

        ["chip_security_2"] = {
            stats = {
                { statType = "WeaponsSkillGainSpeed", value = 2 },
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "MaximumHealthMultiplier", value = 0.2 },
                { statType = "MeleeAttackMultiplier", value = 0.4 },
                { statType = "MeleeAttackSpeed", value = 0.4 },
                { statType = "BuffDurationMultiplier", value = 0.4 },
                { statType = "DebuffDurationMultiplier", value = 0.4 },
                { statType = "FlowResistance", value = 0.8 },
                { statType = "RangedSpreadReduction", value = 0.25 },
                { statType = "TurretAttackSpeed", value = 0.15 },
                { statType = "TeamAttackMultiplier", value = -0.5 },
                { statType = "TurretPowerCostReduction", value = 0.2 },
            },
        },

        ["chip_medic"] = {
            stats = {
                { statType = "MedicalSkillGainSpeed", value = 1 },
                { statType = "WalkingSpeed", value = 0.1 },
                { statType = "PoisonMultiplier", value = 0.2 },
                { statType = "CPRBoost", value = 0.5 },
                { statType = "GeneticMaterialRefineBonus", value = 0.1 },
                { statType = "GeneticMaterialTaintedProbabilityReductionOnCombine", value = 0.5 },
            },
        },

        ["chip_medic_2"] = {
            stats = {
                { statType = "MedicalSkillGainSpeed", value = 2 },
                { statType = "WalkingSpeed", value = 0.2 },
                { statType = "PoisonMultiplier", value = 0.3 },
                { statType = "CPRBoost", value = 0.7 },
                { statType = "GeneticMaterialRefineBonus", value = 0.2 },
                { statType = "GeneticMaterialTaintedProbabilityReductionOnCombine", value = 0.7 },
            },
        },

        -- 船长芯片保留 XML：多人唯一性依赖 Affliction 衰减与抗性。

        -- 助手芯片
        ["chip_assistant"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 0.5 },
                { statType = "MovementSpeed", value = 0.1 },
            },
            resistances = { { id = "oxygenlow", multiplier = 0 } },
            affliction = {
                { id = "clownpower", strength = 10 },
                { id = "psychosis", strength = 10 },
            },
        },

        ["chip_assistant_2"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 1 },
                { statType = "MovementSpeed", value = 0.2 },
            },
            resistances = { { id = "oxygenlow", multiplier = 0 } },
            affliction = {
                { id = "chip_assistant_2", strength = 2 },
                { id = "clownpower", strength = 10 },
            },
        },

        ["deep_ten_star_general_assist_upgrading"] = {
            stats = {
                { statType = "SkillGainSpeed", value = 10 },
                { statType = "ReputationGainMultiplier", value = 1 },
                { statType = "MissionMoneyGainMultiplier", value = 1 },
                { statType = "ExperienceGainMultiplier", value = 1 },
                { statType = "ExtraMissionCount", value = 10 },
                { statType = "ExtraSpecialSalesCount", value = 10 },
                { statType = "StoreSellMultiplier", value = 10 },
                { statType = "StoreBuyMultiplier", value = 1 },
                { statType = "ShipyardBuyMultiplier", value = 1 },
            },
        },

    },
}

-- 插板惩罚已迁移为原生 StatValue；重装防御者通过同组屏蔽保持原有免疫语义。
for itemId, cfg in pairs(CONFIG.subItems) do
    if itemId:sub(1, 11) == "deep_plate_" then cfg.statGroup = "deep_plate_debuff" end
end

_G.AdjustEquipmentConfig = CONFIG
