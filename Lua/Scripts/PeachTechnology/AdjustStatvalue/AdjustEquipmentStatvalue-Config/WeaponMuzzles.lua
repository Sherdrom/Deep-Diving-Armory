local shortMarkers = {
    affliction = {
        { id = "deep_muzzle_short_detect", strength = 2 },
        { id = "deep_muzzle_none_detect", strength = 2 },
    },
}

local longMarkers = {
    affliction = {
        { id = "deep_muzzle_long_detect", strength = 2 },
        { id = "deep_muzzle_none_detect", strength = 2 },
    },
}

return {
    ["extended_barrel"] = {
        effects = {
            {
                blockedByEnemyResistance = true,
                statsKey = "extended_barrel",
                stats = {
                    { statType = "RangedSpreadReduction", value = 0.3 },
                    { statType = "RangedAttackMultiplier", value = 0.2 },
                    { statType = "RangedAttackSpeed", value = -0.15 },
                    { statType = "WeaponsSkillBonus", value = -15 },
                },
            },
            longMarkers,
        },
    },
    ["deep_flash_hider"] = { effects = { shortMarkers } },
    ["deep_compensator"] = { effects = { shortMarkers } },
    ["deep_muzzle_brake"] = {
        effects = {
            {
                blockedByEnemyResistance = true,
                statsKey = "deep_muzzle_brake",
                stats = {
                    { statType = "RangedSpreadReduction", value = 0.3 },
                    { statType = "WeaponsSkillBonus", value = 20 },
                },
            },
            shortMarkers,
        },
    },
    ["deep_muffler"] = {
        effects = {
            {
                blockedByEnemyResistance = true,
                statsKey = "deep_muffler",
                stats = {
                    { statType = "SoundRangeMultiplier", value = -0.8 },
                    { statType = "RangedSpreadReduction", value = 0.2 },
                    { statType = "WeaponsSkillBonus", value = -15 },
                },
                talentMarkers = { "deep_muffler" },
            },
            longMarkers,
        },
    },
}
