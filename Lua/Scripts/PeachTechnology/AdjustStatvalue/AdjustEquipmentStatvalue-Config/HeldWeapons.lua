local items = {}
local COMMON_TALENT = Identifier("deep_talent_all")
local ELITE_ENEMY_TALENT = Identifier("deep_talent_elite_enemy")

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

local function hasTalent(character, identifier)
    return character and character:HasTalent(identifier)
end

local function isCrouched(character)
    local controller = character and character.AnimController
    return controller
        and LuaUserData.IsTargetType(controller, "Barotrauma.HumanoidAnimController")
        and controller.Crouching
end

local function vitalityAtMost(character, percentage)
    local maxVitality = character and character.MaxVitality
    return maxVitality and maxVitality > 0
        and character.Vitality / maxVitality <= percentage
end

local function hasCommonTalent(character)
    return hasTalent(character, COMMON_TALENT)
end

local function commonCrouched(character)
    return hasCommonTalent(character) and isCrouched(character)
end

local function commonBelow50(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.5)
end

local function commonBelow80(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.8)
end

local function commonBelow20(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.2)
end

local function wuchuanCrouched(character)
    return (hasCommonTalent(character) or hasTalent(character, ELITE_ENEMY_TALENT))
        and isCrouched(character)
end

local function wuchuanHidden(character)
    return wuchuanCrouched(character) and vitalityAtMost(character, 0.5)
end

local function commonInSmoke(character)
    local health = character and character.CharacterHealth
    return hasCommonTalent(character) and health
        and health:GetAfflictionStrengthByIdentifier("m18_smoke") > 0
end

local function switchableValue(item, field)
    local component = item and item.GetComponentString
        and item.GetComponentString("SwitchableRangedWeapon")
    return component and component[field]
end

local function currentFireMode(mode)
    return function(_, host)
        return tonumber(switchableValue(host, "currentFireModeSelected")) == mode
    end
end

local function currentProjectileWithMasterKey(_, host)
    if tonumber(switchableValue(host, "currentProjectileSelected")) == 1 then
        local inventory = host and host.OwnInventory
        local masterKey = inventory and inventory.GetItemAt and inventory:GetItemAt(1)
        return masterKey and masterKey.Prefab
            and tostring(masterKey.Prefab.Identifier) == "deep_sub_hanging_master_key"
    end
end

local function hasUpgradeTag(_, host)
    return host and host.HasTag and host.HasTag("deep_upgrade_tool_steel_tit_confirm")
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
    when = commonCrouched,
    statsKey = "deep_machinegun_crouch",
    stats = { { statType = "RangedSpreadReduction", value = 0.7 } },
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
    when = commonBelow50,
    statsKey = "deep_pistol_mozambique_aff",
    stats = {
        { statType = "AttackMultiplier", value = 0.5 },
        { statType = "RangedAttackSpeed", value = 0.1 },
    },
})

local heavySnipers = {
    "deep_m82a1",
    "deep_ntw20",
    "deep_ptrd",
}

addEffect(heavySnipers, {
    blockedByEnemyResistance = true,
    when = commonBelow80,
    statsKey = "deep_sniper_aim_heavy_damage_reduce_1",
    stats = {
        { statType = "AttackMultiplier", value = -0.1 },
        { statType = "RangedSpreadReduction", value = -0.3 },
    },
})

addEffect(heavySnipers, {
    blockedByEnemyResistance = true,
    when = commonBelow50,
    statsKey = "deep_sniper_aim_heavy_damage_reduce_2",
    stats = {
        { statType = "AttackMultiplier", value = -0.1 },
        { statType = "RangedSpreadReduction", value = -0.3 },
    },
})

addEffect(heavySnipers, {
    blockedByEnemyResistance = true,
    when = commonBelow20,
    statsKey = "deep_sniper_aim_heavy_damage_reduce_3",
    stats = {
        { statType = "AttackMultiplier", value = -0.1 },
        { statType = "RangedSpreadReduction", value = -0.3 },
    },
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
    when = commonInSmoke,
    statsKey = "deep_knife_detect_1",
    stats = {
        { statType = "MeleeAttackMultiplier", value = 20 },
        { statType = "MeleeAttackSpeed", value = -0.5 },
    },
})

addEffect({ "deep_wuchuan" }, {
    when = wuchuanCrouched,
    statsKey = "deep_wuchuan_crouch",
    stats = { { statType = "MeleeAttackSpeed", value = 3 } },
    resistances = { { id = "damage", multiplier = 0.2, source = "deep_wuchuan_crouch" } },
})

addEffect({ "deep_wuchuan" }, {
    when = wuchuanHidden,
    flags = { "IgnoredByEnemyAI" },
})

addEffect({ "deep_g36c_roger" }, {
    talentMarkers = { "chip_headshot_detect" },
})

-- SwitchableRangedWeapon modes and projectile selection. These were XML
-- OnActive Afflictions; the state machine now polls only the held host.
addEffect({
    "deep_74m_103", "deep_9a91", "deep_AK101", "deep_AK103", "deep_AK12",
    "deep_AK15", "deep_AK19", "deep_AK201", "deep_AK205", "deep_AK47",
    "deep_AK47_gold", "deep_AK74", "deep_AK74M", "deep_AK74M_mygo", "deep_AK81",
    "deep_AKM", "deep_arx200", "deep_ASH", "deep_asval", "deep_asvalmod4",
    "deep_aug", "deep_c1", "deep_c7a1", "deep_C8-SFW", "deep_EF88", "deep_FAMAS",
    "deep_G36C", "deep_g3a3", "deep_HK33", "deep_hk416", "deep_L85A2", "deep_LYXN",
    "deep_m4", "deep_mac10", "deep_mk17_peach", "deep_mkb42h", "deep_mp5k",
    "deep_mp5sd", "deep_mp7", "deep_ots12", "deep_ots14", "deep_p90", "deep_pdw",
    "deep_pp19", "deep_pp19_warrior", "deep_qbz_03", "deep_qbz_191", "deep_qbz_192",
    "deep_qbz_95", "deep_qbz_95_1", "deep_qbz_97", "deep_qbz95_chixiao", "deep_R4C",
    "deep_rpk", "deep_rpk16", "deep_sa58_sheep", "deep_SCAR-H", "deep_SCAR-H_shield",
    "deep_sg556", "deep_sr3m", "deep_thompson", "deep_ump45", "deep_vector",
    "deep_vhs_d3_baka",
}, {
    pollInterval = 0.9,
    when = currentFireMode(1),
    statsKey = "deep_Semi",
    statGroup = "deep_Semi",
    stats = {
        { statType = "RangedAttackMultiplier", value = 0.3 },
        { statType = "RangedSpreadReduction", value = 0.7 },
    },
})

addEffect({
    "deep_FAMAS", "deep_hk416", "deep_m4", "deep_mp5k", "deep_mp5sd", "deep_mp7",
    "deep_pdw", "deep_sg556", "deep_ump45", "deep_vector",
}, {
    pollInterval = 0.9,
    when = currentFireMode(2),
    statsKey = "deep_Burst",
    blocksStatGroups = { "deep_Semi" },
    stats = {
        { statType = "RangedAttackMultiplier", value = 0.1 },
        { statType = "RangedSpreadReduction", value = 0.5 },
    },
})

addEffect({
    "deep_1887", "deep_410", "deep_aa12", "deep_bosg", "deep_doublebarrel",
    "deep_m4_super90", "deep_m590", "deep_m870", "deep_pigcat_three_shotgun",
    "deep_short_doublebarrel", "deep_supernova",
}, {
    talentMarkers = { "deep_shotgun_damgage_balance" },
})

addEffect({
    "deep_74m_103", "deep_AK103", "deep_AK12", "deep_AK15", "deep_AK19", "deep_AK201",
    "deep_AK205", "deep_AK74M", "deep_AK74M_mygo", "deep_AKM", "deep_arx200", "deep_ASH",
    "deep_c7a1", "deep_C8-SFW", "deep_FAMAS", "deep_G36C", "deep_g3a3", "deep_HK33",
    "deep_hk416", "deep_L85A2", "deep_LYXN", "deep_mk17_peach", "deep_mkb42h", "deep_qbz_03",
    "deep_qbz_191", "deep_qbz_192", "deep_qbz_95_1", "deep_qbz_97", "deep_qbz95_chixiao",
    "deep_R4C", "deep_SCAR-H", "deep_SCAR-H_shield", "deep_sg556",
}, {
    pollInterval = 0.5,
    when = currentProjectileWithMasterKey,
    talentMarkers = { "deep_shotgun_damgage_balance" },
})

local upgradeRifles = {
    "deep_9a91", "deep_AK101", "deep_AK103", "deep_AK201", "deep_AK47", "deep_AK47_gold",
    "deep_AK74", "deep_AK74M", "deep_AK81", "deep_AKM", "deep_arx200", "deep_aug",
    "deep_c7a1", "deep_C8-SFW", "deep_EF88", "deep_FAMAS", "deep_G36C", "deep_g3a3",
    "deep_HK33", "deep_L85A2", "deep_m4", "deep_ots12", "deep_qbz_95", "deep_sg556",
}

local upgradeSmgs = {
    "deep_c1", "deep_mac10", "deep_mp5k", "deep_mp5sd", "deep_p90", "deep_pdw",
    "deep_thompson", "deep_ump45",
}

local upgradePistols = {
    "deep_44Magnum", "deep_FN57", "deep_glock17", "deep_M1911", "deep_pmm", "deep_USP",
}

local upgradeSnipers = {
    "deep_56ban", "deep_98k", "deep_AWM", "deep_fn49", "deep_gew43", "deep_Lee",
    "deep_m1_garand", "deep_m14", "deep_M1903", "deep_M700", "deep_Mosin", "deep_ptrd",
    "deep_R93", "deep_sks", "deep_sr25", "deep_sv98", "deep_type_38", "deep_zhongzheng",
}

local upgradeMachineguns = { "deep_dp28", "deep_m60", "deep_rpk", "deep_rpk16" }
local upgradeShotguns = { "deep_1887", "deep_doublebarrel", "deep_m590", "deep_short_doublebarrel", "deep_supernova" }
local upgradeGrenadeLaunchers = { "deep_gl40", "deep_m79" }

local function addUpgradeEffect(itemIds, statsKey, stats)
    addEffect(itemIds, {
        pollInterval = 0.25,
        when = hasUpgradeTag,
        statsKey = statsKey,
        stats = stats,
    })
end

local commonUpgradeStats = {
    { statType = "RangedAttackMultiplier", value = 0.3 },
    { statType = "RangedAttackSpeed", value = 0.1 },
    { statType = "RangedSpreadReduction", value = 0.5 },
}
addUpgradeEffect(upgradeRifles, "deep_upgrade_rifle", commonUpgradeStats)
addUpgradeEffect(upgradeSmgs, "deep_upgrade_smg", commonUpgradeStats)
addUpgradeEffect(upgradePistols, "deep_upgrade_pistol", commonUpgradeStats)
addUpgradeEffect(upgradeSnipers, "deep_upgrade_sniper", commonUpgradeStats)
addUpgradeEffect(upgradeMachineguns, "deep_upgrade_machinegun", commonUpgradeStats)
addUpgradeEffect(upgradeShotguns, "deep_upgrade_shotgun", {
    { statType = "RangedAttackMultiplier", value = 0.3 },
    { statType = "RangedAttackSpeed", value = 0.1 },
})
addUpgradeEffect(upgradeGrenadeLaunchers, "deep_upgrade_gl", {
    { statType = "RangedAttackMultiplier", value = 0.3 },
})

return items
