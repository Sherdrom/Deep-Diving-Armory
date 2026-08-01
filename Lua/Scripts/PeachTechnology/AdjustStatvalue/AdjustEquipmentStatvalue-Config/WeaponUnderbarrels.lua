local debuff = {
    blockedByEnemyResistance = true,
    statsKey = "deep_sub_hanging_debuff",
    stats = {
        { statType = "MovementSpeed", value = -0.2 },
        { statType = "WeaponsSkillBonus", value = -20 },
    },
}

return {
    ["deep_sub_hanging_master_key"] = debuff,
    ["deep_sub_hanging_m203"] = debuff,
    ["deep_sub_hanging_gp25"] = debuff,
    ["deep_sub_hanging_qlg10a"] = debuff,
}
