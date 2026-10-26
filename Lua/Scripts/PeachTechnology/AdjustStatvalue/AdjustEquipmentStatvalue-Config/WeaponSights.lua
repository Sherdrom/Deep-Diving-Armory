local laser = {
    blockedByEnemyResistance = true,
    statsKey = "deep_laser_1",
    stats = {
        { statType = "RangedSpreadReduction", value = 0.1 },
        { statType = "WeaponsSkillBonus", value = 10 },
        { statType = "TeamAttackMultiplier", value = -0.5 },
    },
}

return {
    ["focusingflashlight_small"] = laser,
    ["spreadflashlight_small"] = laser,
    ["deep_laser"] = laser,
    ["deep_laser_R"] = laser,

    ["holographic_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "holographic_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.3 },
            { statType = "WalkingSpeed", value = 0.2 },
            { statType = "RangedAttackMultiplier", value = 0.15 },
            { statType = "WeaponsSkillBonus", value = 15 },
        },
    },
    ["2x_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "2x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.4 },
            { statType = "WeaponsSkillBonus", value = 10 },
            { statType = "RangedAttackMultiplier", value = 0.1 },
            { statType = "WalkingSpeed", value = 0.15 },
        },
    },
    ["2.5x_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "2.5x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.6 },
            { statType = "WeaponsSkillBonus", value = 20 },
            { statType = "RangedAttackMultiplier", value = 0.05 },
            { statType = "WalkingSpeed", value = 0.1 },
        },
    },
    ["3x_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "3x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.8 },
            { statType = "WeaponsSkillBonus", value = 30 },
            { statType = "WalkingSpeed", value = -0.25 },
        },
    },
    ["red_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "red_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.15 },
            { statType = "WalkingSpeed", value = 0.3 },
            { statType = "RangedAttackMultiplier", value = 0.2 },
            { statType = "WeaponsSkillBonus", value = 20 },
        },
    },
    ["thermalgoggles_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "thermalgoggles_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.3 },
            { statType = "WeaponsSkillBonus", value = -15 },
        },
    },
    ["thermalgoggles_sight_6x"] = {
        blockedByEnemyResistance = true,
        statsKey = "thermalgoggles_sight_6x",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.8 },
            { statType = "WeaponsSkillBonus", value = 25 },
            { statType = "WalkingSpeed", value = -0.3 },
        },
    },
    ["8x_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "8x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.9 },
            { statType = "WeaponsSkillBonus", value = 30 },
            { statType = "RangedAttackMultiplier", value = 0.3 },
            { statType = "RangedAttackSpeed", value = -0.2 },
            { statType = "WalkingSpeed", value = -0.3 },
        },
    },
    ["1_3x_sight"] = {
        blockedByEnemyResistance = true,
        statsKey = "1_3x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.7 },
            { statType = "WeaponsSkillBonus", value = 25 },
        },
    },
}
