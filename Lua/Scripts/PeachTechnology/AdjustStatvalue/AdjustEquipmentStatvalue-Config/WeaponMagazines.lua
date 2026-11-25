local items = {}

local function add(itemIds, cfg)
    for _, itemId in ipairs(itemIds) do
        assert(not items[itemId], "duplicate weapon magazine config: " .. itemId)
        items[itemId] = cfg
    end
end

add({
    "deep_762x51_virtual_25_l7awm",
    "deep_762x51_virtual_10_m700",
    "deep_762x51_virtual_10_r93",
    "deep_762x54r_virtual_10_sv98",
    "deep_45acp_virtual_11_m1911",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_mag_light",
    stats = {
        { statType = "WeaponsSkillBonus", value = -10 },
        { statType = "MovementSpeed", value = -0.05 },
    },
})

add({
    "deep_556x45_virtual_40_stanag",
    "deep_545x39_virtual_45_6l26",
    "deep_762x39_virtual_40_6p2sb11",
    "deep_45acp_virtual_40_mac",
    "deep_46x30_virtual_40_mp7",
    "deep_9x19_virtual_33_glock",
    "deep_338lm_virtual_10_mk22",
    "deep_338lm_virtual_10_awm",
    "deep_762x51_virtual_20_m700",
    "deep_9x19_virtual_50_x5",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_mag",
    stats = {
        { statType = "WeaponsSkillBonus", value = -15 },
        { statType = "MovementSpeed", value = -0.1 },
    },
})

add({
    "deep_545x39_virtual_60_6l31",
    "deep_556x45_virtual_60_d60",
    "deep_556x45_virtual_60_stanag",
    "deep_762x39_virtual_50_x47",
    "deep_762x39_virtual_73_aka16",
    "deep_762x39_virtual_75_molot",
    "deep_762x51_virtual_50_x25",
    "deep_9x19_virtual_50_glock",
    "deep_45acp_virtual_50_tom50",
    "deep_12shell_virtual_25_aa12",
    "deep_58x42_virtual_75_qbz",
    "deep_762x51_virtual_50_m14",
    "deep_792x57_virtual_75_mg",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_drum",
    stats = {
        { statType = "WeaponsSkillBonus", value = -20 },
        { statType = "MovementSpeed", value = -0.15 },
    },
})

add({
    "deep_45acp_virtual_50_tom100",
    "deep_127x99_virtual_20_m82a1",
    "deep_545x39_virtual_95_rpk16",
    "deep_556x45_virtual_100_beta_cmag",
    "deep_556x45_virtual_100_stanag",
    "deep_58x42_virtual_100_qbz",
    "deep_792x57_virtual_300_mg",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_drum_heavy",
    stats = {
        { statType = "WeaponsSkillBonus", value = -35 },
        { statType = "MovementSpeed", value = -0.2 },
    },
})

-- 12号霰弹(6种材质)保留600-1200衰减标记；独头弹(deep_12slug_*)无衰减，不登记。
add({
    "deep_12shell_lead",
    "deep_12shell_tit",
    "deep_12shell_phy",
    "deep_12shell_fu",
    "deep_12shell_ap",
    "deep_12shell_du",
    "deep_three_mag",
}, {
    talentMarkers = { "deep_damage_fall_off_600_1200_detect" },
})

-- 9x39 30发弹匣：轻型扩容惩罚 + 1500-2300衰减标记合并为一条注册（同一物品只能注册一次）
add({
    "deep_9x39_virtual_30_mod4",
    "deep_9x39_virtual_30_sr3m130",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_mag_light",
    stats = {
        { statType = "WeaponsSkillBonus", value = -10 },
        { statType = "MovementSpeed", value = -0.05 },
    },
    talentMarkers = { "deep_damage_fall_off_1500_2300_detect" },
})

add({
    "deep_9x39_virtual_20_6l25",
    "deep_9x39_virtual_20_9a91",
}, {
    talentMarkers = { "deep_damage_fall_off_1500_2300_detect" },
})

return items
