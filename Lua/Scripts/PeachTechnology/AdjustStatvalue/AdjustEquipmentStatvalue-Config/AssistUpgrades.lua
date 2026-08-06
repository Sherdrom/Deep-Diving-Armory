return {
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
            { id = "burn", multiplier = 0.7 },
            { id = "electricshock", multiplier = 0.7 },
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
            { statType = "MovementSpeed", value = 0.1 },
            { statType = "PoisonMultiplier", value = 0.2 },
            { statType = "CPRBoost", value = 0.5 },
            { statType = "GeneticMaterialRefineBonus", value = 0.1 },
            { statType = "GeneticMaterialTaintedProbabilityReductionOnCombine", value = 0.5 },
        },
    },

    ["chip_medic_2"] = {
        stats = {
            { statType = "MedicalSkillGainSpeed", value = 2 },
            { statType = "MovementSpeed", value = 0.2 },
            { statType = "PoisonMultiplier", value = 0.3 },
            { statType = "CPRBoost", value = 0.7 },
            { statType = "GeneticMaterialRefineBonus", value = 0.2 },
            { statType = "GeneticMaterialTaintedProbabilityReductionOnCombine", value = 0.7 },
        },
    },

    -- 船长芯片

    ["chip_captain"] = {
        stats = {
            { statType = "HelmSkillGainSpeed", value = 1 },
        },
        talentMarkers = { "chip_captain" },
    },

    ["chip_captain_2"] = {
        stats = {
            { statType = "HelmSkillGainSpeed", value = 2 },
        },
        talentMarkers = { "chip_captain_2" },
    },

    -- 十星将军(dlc)
    ["deep_ten_star_general_assist_upgrading"] = {
        stats = {
            { statType = "SkillGainSpeed", value = 10 },
        },
        talentMarkers = { "deep_ten_star_general_assist_upgrading" },
    },

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

}
