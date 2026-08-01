return {
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

}
