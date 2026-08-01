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

local vceWarning = {
    affliction = { id = "deep_VCE_none", strength = 2 },
}

addEffect({
    "deep_127Magnum",
    "deep_1887",
    "deep_410",
    "deep_56ban",
    "deep_6p41_darkdog",
    "deep_74m_103",
    "deep_98k",
    "deep_9a91",
    "deep_aa12",
    "deep_AK101",
    "deep_AK103",
    "deep_AK12",
    "deep_AK15",
    "deep_AK19",
    "deep_AK201",
    "deep_AK205",
    "deep_AK47",
    "deep_AK47_gold",
    "deep_AK74",
    "deep_AK74M",
    "deep_AK74M_mygo",
    "deep_AK81",
    "deep_AKM",
    "deep_ar15_50_xiaohua",
    "deep_arx200",
    "deep_ASH",
    "deep_asval",
    "deep_asvalmod4",
    "deep_aug",
    "deep_AWM",
    "deep_bosg",
    "deep_c1",
    "deep_c7a1",
    "deep_C8-SFW",
    "deep_CZ75",
    "deep_deserteagle",
    "deep_doublebarrel",
    "deep_dp28",
    "deep_EF88",
    "deep_FAMAS",
    "deep_fn49",
    "deep_FN57",
    "deep_fn57_mute",
    "deep_G36C",
    "deep_g36c_roger",
    "deep_g3a3",
    "deep_Gauss_Benzoyl_Peroxide",
    "deep_gew43",
    "deep_gl40",
    "deep_glock17",
    "deep_glock18c",
    "deep_gm6",
    "deep_HK33",
    "deep_hk416",
    "deep_izanagi_paidaxing",
    "deep_L85A2",
    "deep_Lee",
    "deep_LYXN",
    "deep_m1_garand",
    "deep_m14",
    "deep_m14ebr_moonwolf",
    "deep_M1903",
    "deep_M1911",
    "deep_m249",
    "deep_m4",
    "deep_m4_super90",
    "deep_M45meusoc",
    "deep_m500Magnum",
    "deep_m590",
    "deep_m60",
    "deep_M700",
    "deep_m79",
    "deep_m82a1",
    "deep_m870",
    "deep_mac10",
    "deep_meteorite",
    "deep_mg42",
    "deep_mk17_peach",
    "deep_mk22_binary",
    "deep_mkb42h",
    "deep_Mosin",
    "deep_mp5k",
    "deep_mp5sd",
    "deep_mp7",
    "deep_ntw20",
    "deep_ots12",
    "deep_ots14",
    "deep_p90",
    "deep_pdw",
    "deep_pigcat_three_shotgun",
    "deep_pkp",
    "deep_pmm",
    "deep_pp19",
    "deep_pp19_warrior",
    "deep_ptrd",
    "deep_qbz_03",
    "deep_qbz_191",
    "deep_qbz_192",
    "deep_qbz_95",
    "deep_qbz_95_1",
    "deep_qbz_97",
    "deep_qbz95_chixiao",
    "deep_R4C",
    "deep_R93",
    "deep_rm338_taizong",
    "deep_rpd_thesun",
    "deep_rpk",
    "deep_rpk16",
    "deep_sa58_sheep",
    "deep_SCAR-H",
    "deep_SCAR-H_shield",
    "deep_sg556",
    "deep_short_doublebarrel",
    "deep_sks",
    "deep_sr25",
    "deep_sr3m",
    "deep_supernova",
    "deep_sv98",
    "deep_thompson",
    "deep_type_38",
    "deep_ump45",
    "deep_USP",
    "deep_vector",
    "deep_vhs_d3_baka",
    "deep_whiteeagle",
    "deep_xm25",
    "deep_zhongzheng",
}, vceWarning)

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
