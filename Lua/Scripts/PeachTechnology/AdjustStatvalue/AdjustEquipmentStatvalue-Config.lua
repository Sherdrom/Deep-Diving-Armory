-- ============================================================
-- AdjustEquipmentStatvalue-Config.lua
-- CONFIG 配置模块，通过全局变量 AdjustEquipmentConfig 暴露
-- ============================================================
--
-- >> 完整配置说明 <<
--
-- [顶层参数]
--   checkInterval (number)  think 轮询间隔（秒），默认 0.5。
--                          仅子体（IsSub）需要轮询检测放入/取出；
--                          主体（IsMain）完全由 item.equip/item.unequip 事件驱动，不受此值影响。
--   debug         (bool)    是否启用 dbgPrint 调试输出，生产环境设为 false。
--
-- [items — 物品配置]
--   键为物品的 Identifier (Prefab ID)，值为配置表，支持的字段：
--
--   IsMain (bool)  标记为"可直接穿戴于装备栏"的主体装备。
--                  主体槽位范围：Head / InnerClothes / OuterClothes / Headset / Card / Bag。
--                  装备时触发效果，脱下 / 丢弃 / 移除时自动撤销。
--
--   IsSub  (bool)  标记为"可放入主体装备库存"的子体配件。
--                  子体被放入主体时触发效果，取出或主体脱离角色时自动撤销。
--                  IsMain 和 IsSub 互斥，每个物品只能二选一。
--
--   stats  (table[]) 修改角色的 StatValue。每项是一条记录：
--     { statType = "StatTypes枚举名", value = number }
--     - statType: StatTypes 枚举中的成员名（大小写敏感），见附录A
--     - value: 数值。技能类（SkillBonus）为整数加成，百分比类（*Multiplier/Speed）为小数
--       （0.2 = 20%），Override 类为覆盖值
--     例: { statType = "WalkingSpeed", value = -0.15 }
--
--   flags  (string[]) 修改角色的 AbilityFlag。每项是 AbilityFlags 枚举成员名（大小写敏感），
--                     见附录B。装备时添加，脱下时移除。
--     例: flags = { "ImmuneToPressure", "MustWalk" }
--
--   affliction (table) 装备时向角色 Head 肢体施加指定 Affliction，脱下时移除。
--     { id = "Affliction Prefab 标识名", strength = number }
--     - id: AfflictionPrefab 的 Identifier 名称
--     - strength: 强度值
--     例: affliction = { id = "burn", strength = 50 }
--
--   以上 stats / flags / affliction 均为选填，不填则跳过，无副作用。
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
    checkInterval = 0.5,
    debug = false,
    items = {

        --主体（插板防弹衣）
        ["deep_6b13"] = {
            IsMain = true,
        },

        ["deep_Guardian"] = {
            IsMain = true,
        },

        ["deep_6b23"] = {
            IsMain = true,
        },

        ["deep_6b43"] = {
            IsMain = true,
        },

        ["deep_defender"] = {
            IsMain = true,
        },

        ["deep_fort_t5"] = {
            IsMain = true,
        },

        ["gen4_heavy"] = {
            IsMain = true,
        },

        ["gen4_protection"] = {
            IsMain = true,
        },

        ["gen4_high_mobility"] = {
            IsMain = true,
        },

        ["deep_hpc"] = {
            IsMain = true,
        },

        ["deep_thor_protection"] = {
            IsMain = true,
        },

        ["thor"] = {
            IsMain = true,
        },

        ["deep_zhuk_6a"] = {
            IsMain = true,
        },

        --主体（插板胸挂）
        ["deep_Obsidian"] = {
            IsMain = true,
        },

        ["deep_osprey_protection"] = {
            IsMain = true,
        },

        ["deep_osprey"] = {
            IsMain = true,
        },

        ["deep_bagariy"] = {
            IsMain = true,
        },

        ["deep_tactec"] = {
            IsMain = true,
        },

        --主体（衣服）
        ["deep_heyuanmu_suit"] = {
            IsMain = true,
        },



        --子体（钢制主插板）
        ["deep_plate_metal_3"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.15 },
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_4"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_5"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.25 },
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_6"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.3 },
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_7"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.35 },
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        ["deep_plate_metal_8"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.4 },
                { statType = "WeaponsSkillBonus", value = -40 },
            },
        },

        ["deep_plate_metal_9"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.45 },
                { statType = "WeaponsSkillBonus", value = -45 },
            },
        },

        ["deep_plate_metal_10"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.5 },
                { statType = "WeaponsSkillBonus", value = -50 },
            },
        },

        --子体（钢制手臂插板）
        ["deep_plate_metal_arm_4"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_metal_arm_5"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_arm_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_arm_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_arm_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_arm_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        --子体（钢制腹股沟插板）
        ["deep_plate_metal_groin_4"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_metal_groin_5"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_metal_groin_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -20 },
            },
        },

        ["deep_plate_metal_groin_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -25 },
            },
        },

        ["deep_plate_metal_groin_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -30 },
            },
        },

        ["deep_plate_metal_groin_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -35 },
            },
        },

        --子体（陶瓷主插板）
        ["deep_plate_ceramic_4"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_5"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_6"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_7"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_8"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_9"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_10"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.1 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        --子体（陶瓷手臂插板）
        ["deep_plate_ceramic_arm_4"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_5"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_arm_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        --子体（陶瓷腹股沟插板）
        ["deep_plate_ceramic_groin_4"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_5"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_ceramic_groin_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        --子体（复合主插板）
        ["deep_plate_composite_6"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_7"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_8"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_9"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_composite_10"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_rf3"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        ["deep_plate_br6"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -10 },
            },
        },

        --子体（复合手臂插板）
        ["deep_plate_composite_arm_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_arm_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        --子体（复合腹股沟插板）
        ["deep_plate_composite_groin_6"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_7"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_8"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },

        ["deep_plate_composite_groin_9"] = {
            IsSub = true,
            stats = {
                { statType = "WeaponsSkillBonus", value = -15 },
            },
        },



        
        --子体（护甲升级）
        ["chip_ergonomics"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = 0.2 },
                { statType = "WeaponsSkillBonus", value = 20 },
            },
        },

        ["chip_heavy_armor"] = {
            IsSub = true,
            stats = {
                { statType = "MovementSpeed", value = -0.2 },
                { statType = "WeaponsSkillBonus", value = -20 },
            },
            affliction = { id = "chip_heavy_armor", strength = 1 },
        },

        ["chip_strengthening_of_limbs"] = {
            IsSub = true,
            affliction = { id = "chip_strengthening_of_limbs", strength = 1 },
        },

        ["chip_emergency_defibrillation"] = {
            IsSub = true,
            affliction = { id = "chip_emergency_defibrillation_detect", strength = 1 },
        },

        -- 主体 Affliction 示例（装备此物品时施加指定 affliction）
        -- ["example_main_with_affliction"] = {
        --     IsMain = true,
        --     affliction = { id = "some_affliction_id", strength = 10 },
        -- },

        -- 子体 Affliction 示例
        -- ["example_sub_with_affliction"] = {
        --     IsSub = true,
        --     affliction = { id = "some_affliction_id", strength = 5 },
        -- },

    },
}

-- ============================================================
-- 模块级缓存
-- ============================================================

_G.AdjustEquipmentSubConfigCache = {}
for itemId, cfg in pairs(CONFIG.items) do
    if cfg.IsSub then
        _G.AdjustEquipmentSubConfigCache[itemId] = cfg
    end
end

_G.AdjustEquipmentWearableSlots = {
    InvSlotType.Head,
    InvSlotType.InnerClothes,
    InvSlotType.OuterClothes,
    InvSlotType.Headset,
    InvSlotType.Card,
    InvSlotType.Bag,
}

_G.AdjustEquipmentConfig = CONFIG