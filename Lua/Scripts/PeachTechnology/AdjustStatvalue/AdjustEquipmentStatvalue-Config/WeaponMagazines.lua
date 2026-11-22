local items = {}

local function add(itemIds, cfg)
    for _, itemId in ipairs(itemIds) do
        assert(not items[itemId], "duplicate weapon magazine config: " .. itemId)
        items[itemId] = cfg
    end
end

add({
    "deep_545x39_virtual_45_6l26",
    "deep_545x39_virtual_60_6l31",
    "deep_545x39_virtual_95_rpk16",
    "deep_556x45_virtual_60_d60",
    "deep_556x45_virtual_60_stanag",
    "deep_556x45_virtual_100_beta_cmag",
    "deep_556x45_virtual_100_stanag",
    "deep_762x39_virtual_40_6p2sb11",
    "deep_762x39_virtual_50_x47",
    "deep_762x39_virtual_73_aka16",
    "deep_762x39_virtual_75_molot",
    "deep_762x51_virtual_25_l7awm",
    "deep_762x51_virtual_50_x25",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_mag",
    stats = {
        { statType = "WeaponsSkillBonus", value = -15 },
        { statType = "WalkingSpeed", value = -0.15 },
    },
})

add({ "deep_9x19_virtual_33_glock" }, {
    statsKey = "deep_glock_long_mag",
    stats = {
        { statType = "WalkingSpeed", value = -0.1 },
        { statType = "WeaponsSkillBonus", value = -20 },
    },
})

add({ "deep_9x19_virtual_50_glock" }, {
    statsKey = "deep_glock_drum_mag",
    stats = {
        { statType = "WalkingSpeed", value = -0.2 },
        { statType = "WeaponsSkillBonus", value = -40 },
    },
})

add({
    "deep_12shell",
    "deep_12shell_arrow",
    "deep_12shell_boneshark",
    "deep_12shell_tigershark",
    "deep_aa12_12shell",
    "deep_three_mag",
}, {
    talentMarkers = { "deep_damage_fall_off_600_1200_detect" },
})

add({
    "deep_9x39_virtual_20_6l25",
    "deep_9x39_virtual_20_9a91",
    "deep_9x39_virtual_30_mod4",
    "deep_9x39_virtual_30_sr3m130",
}, {
    talentMarkers = { "deep_damage_fall_off_1500_2300_detect" },
})

return items
