return {
    ["chip_friendly_fire"] = {
        blockedByEnemyResistance = true,
        talentMarkers = { "friendly_fire" },
    },
    ["chip_gun_in_water"] = {
        talentMarkers = { "deepgun_inwater_detect_chip" },
    },
    ["chip_first_aid"] = {
        blockedByEnemyResistance = true,
        statsKey = "chip_first_aid",
        stats = { { statType = "MovementSpeed", value = 0.1 } },
        flags = { "MoveNormallyWhileDragging" },
    },
    ["chip_rapid_receiver"] = {
        blockedByEnemyResistance = true,
        statsKey = "chip_rapid_receiver",
        stats = {
            { statType = "RangedAttackSpeed", value = 0.15 },
            { statType = "RangedSpreadReduction", value = -0.3 },
        },
    },
    ["chip_unstable_gunpowder"] = {
        blockedByEnemyResistance = true,
        statsKey = "chip_unstable_gunpowder",
        stats = { { statType = "RangedAttackMultiplier", value = 0.2 } },
    },
    ["chip_improved_barrel"] = {
        blockedByEnemyResistance = true,
        statsKey = "improved_barrel",
        stats = { { statType = "RangedSpreadReduction", value = 0.2 } },
    },
    ["chip_oc_gun"] = {
        blockedByEnemyResistance = true,
        statsKey = "chip_oc_gun",
        stats = {
            { statType = "RangedSpreadReduction", value = -0.8 },
            { statType = "RangedAttackMultiplier", value = 0.3 },
            { statType = "RangedAttackSpeed", value = 0.3 },
        },
    },
    ["chip_headshot"] = {
        talentMarkers = { "chip_headshot_detect" },
    },
    ["chip_bodyshot"] = {
        affliction = { id = "chip_bodyshot_detect", strength = 20 },
    },
}
