local items = {}

local function addEffect(itemIds, effect)
    for _, itemId in ipairs(itemIds) do
        local cfg = items[itemId]
        if not cfg then
            cfg = { effects = {} }
            items[itemId] = cfg
        end
        cfg.effects[#cfg.effects + 1] = effect
    end
end

local smg = {
    blockedByEnemyResistance = true,
    statsKey = "smg",
    stats = {
        { statType = "MaximumHealthMultiplier", value = 0.2 },
        { statType = "MovementSpeed", value = 0.15 },
        { statType = "FlowResistance", value = 1 },
    },
    resistances = { { id = "stun", multiplier = 0.7, source = "smg" } },
}

addEffect({
    "deep_c1",
    "deep_mac10",
    "deep_mp5k",
    "deep_mp5sd",
    "deep_mp7",
    "deep_p90",
    "deep_pdw",
    "deep_pp19",
    "deep_pp19_warrior",
    "deep_thompson",
    "deep_ump45",
    "deep_vector",
    "deep_vhs_d3_baka",
}, smg)

local muffler = {
    blockedByEnemyResistance = true,
    statsKey = "deep_muffler",
    stats = {
        { statType = "SoundRangeMultiplier", value = -0.8 },
        { statType = "RangedSpreadReduction", value = 0.2 },
        { statType = "WeaponsSkillBonus", value = -15 },
    },
    talentMarkers = { "deep_muffler" },
}

addEffect({
    "deep_asval",
    "deep_asvalmod4",
    "deep_g36c_roger",
    "deep_LYXN",
    "deep_mp5sd",
}, muffler)

addEffect({
    "deep_6p41_darkdog",
    "deep_dp28",
    "deep_m249",
    "deep_m60",
    "deep_mg42",
    "deep_pkp",
    "deep_rm338_taizong",
    "deep_rpd_thesun",
    "deep_rpk",
    "deep_rpk16",
}, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_machinegun_crouch" },
})

addEffect({
    "deep_6p41_darkdog",
    "deep_dp28",
    "deep_m60",
    "deep_mg42",
    "deep_pkp",
    "deep_rm338_taizong",
}, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_machinegunner_heavy_detect" },
})

addEffect({
    "deep_m249",
    "deep_rpd_thesun",
    "deep_rpk",
    "deep_rpk16",
}, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_machinegunner_light_detect" },
})

addEffect({
    "deep_CZ75",
    "deep_FN57",
    "deep_fn57_mute",
    "deep_glock17",
    "deep_M1911",
    "deep_M45meusoc",
    "deep_pmm",
    "deep_USP",
}, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_pistol_mozambique_hand" },
})

addEffect({
    "deep_m82a1",
    "deep_ntw20",
    "deep_ptrd",
}, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_sniper_aim_heavy" },
})

addEffect({ "deep_qbz_191", "deep_qbz_192" }, {
    talentMarkers = { "deep_stable_shooting" },
})

addEffect({ "deep_fn57_mute", "deep_sa58_sheep" }, {
    blockedByEnemyResistance = true,
    statsKey = "deep_fn57_mute",
    stats = {
        { statType = "SoundRangeMultiplier", value = -0.5 },
        { statType = "SightRangeMultiplier", value = -0.5 },
    },
})

addEffect({ "deep_sa58_sheep" }, {
    blockedByEnemyResistance = true,
    statsKey = "deep_laser_1",
    stats = {
        { statType = "RangedSpreadReduction", value = 0.1 },
        { statType = "WeaponsSkillBonus", value = 10 },
        { statType = "TeamAttackMultiplier", value = -0.5 },
    },
})

addEffect({ "deep_LYXN" }, {
    blockedByEnemyResistance = true,
    statsKey = "red_sight",
    stats = {
        { statType = "RangedSpreadReduction", value = 0.15 },
        { statType = "WalkingSpeed", value = 0.3 },
        { statType = "RangedAttackMultiplier", value = 0.2 },
        { statType = "WeaponsSkillBonus", value = 20 },
    },
})

-- 该效果对 miracleworker 提供 200% Affliction 抗性，原生 AbilityResistance
-- 会把负倍率钳制为 0，无法完全等价，因此保留为事件施加的 Affliction。
addEffect({ "deep_pp19" }, {
    blockedByEnemyResistance = true,
    affliction = { id = "deep_pp19_buffalo", strength = 2 },
})

addEffect({ "deep_knife" }, {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_knife_detect_1" },
})

addEffect({ "deep_wuchuan" }, {
    talentMarkers = { "deep_wuchuan_detection" },
})

addEffect({ "deep_g36c_roger" }, {
    talentMarkers = { "chip_headshot_detect" },
})

return items
