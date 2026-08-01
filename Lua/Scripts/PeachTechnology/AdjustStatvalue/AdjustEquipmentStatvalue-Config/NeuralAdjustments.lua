return {
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

}
