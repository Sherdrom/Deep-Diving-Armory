local items = {}

local function add(itemIds, cfg)
    for _, itemId in ipairs(itemIds) do
        assert(not items[itemId], "duplicate weapon magazine config: " .. itemId)
        items[itemId] = cfg
    end
end

add({
    "deep_5.45x39_expansion",
    "deep_5.56x45_expansion",
    "deep_545x39_expansion_phy",
    "deep_545x39_expansion_tit",
    "deep_556x45_expansion_phy",
    "deep_556x45_expansion_tit",
    "deep_762_expansion",
    "deep_762_expansion_lead",
    "deep_762_expansion_phy",
    "deep_762x51_expansion_lead",
    "deep_762x51_expansion_phy",
    "deep_762x51_expansion_tit",
}, {
    blockedByEnemyResistance = true,
    statsKey = "expansion_mag",
    stats = {
        { statType = "WeaponsSkillBonus", value = -15 },
        { statType = "WalkingSpeed", value = -0.15 },
    },
})

add({ "deep_glock_mag_long_phy", "deep_glock_mag_long_tit" }, {
    statsKey = "deep_glock_long_mag",
    stats = {
        { statType = "WalkingSpeed", value = -0.1 },
        { statType = "WeaponsSkillBonus", value = -20 },
    },
})

add({ "deep_glock_mag_drum_phy", "deep_glock_mag_drum_tit" }, {
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
    "deep_9a91_mag_ap",
    "deep_9a91_mag_du",
    "deep_9a91_mag_fu",
    "deep_9a91_mag_lead",
    "deep_9a91_mag_phy",
    "deep_9a91_mag_tit",
    "deep_9x39_mag_ap",
    "deep_9x39_mag_du",
    "deep_9x39_mag_fu",
    "deep_9x39_mag_lead",
    "deep_9x39_mag_phy",
    "deep_9x39_mag_tit",
}, {
    talentMarkers = { "deep_damage_fall_off_1500_2300_detect" },
})

return items
