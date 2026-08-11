-- Compatibility for Affliction identifiers removed by the equipment-stat migration.
-- Profiles are shallow copies of the current config, so balance changes have one source.

local LEGACY_TIMEOUT = 1.25 -- external XML refreshes are 0.9 s

local function copyProfile(source, keepWhen)
    assert(source, "missing current profile for legacy Affliction")
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    copy.timeout = LEGACY_TIMEOUT
    copy.pollInterval = nil
    if not keepWhen then copy.when = nil end
    return copy
end

return function(current)
    local profiles = {}

    local function indexConfig(config)
        for _, effect in ipairs(config.effects or { config }) do
            if effect.statsKey and not profiles[effect.statsKey] then
                profiles[effect.statsKey] = effect
            end
            for _, marker in ipairs(effect.talentMarkers or {}) do
                if not profiles[marker] then profiles[marker] = effect end
            end
        end
    end

    for _, configs in ipairs({ current.subItems, current.weaponAccessories, current.heldWeapons }) do
        for _, config in pairs(configs) do indexConfig(config) end
    end

    local legacy = {}
    local function add(identifier, source, keepWhen)
        assert(not legacy[identifier], "duplicate legacy Affliction: " .. identifier)
        legacy[identifier] = copyProfile(source, keepWhen)
    end
    local function addProfile(identifier, sourceIdentifier, keepWhen)
        add(identifier, profiles[sourceIdentifier or identifier], keepWhen)
    end

    -- Sub-items whose old Affliction name did not become a statsKey or talent marker.
    local subAliases = {
        chip_assistant_1 = "chip_assistant",
        chip_cqb_1 = "chip_cqb",
        chip_doc_1 = "chip_doc",
        chip_electrician_1 = "chip_electrician",
        chip_electrician_2 = "chip_electrician_2",
        chip_ergonomics_1 = "chip_ergonomics",
        chip_learn_1 = "chip_learn",
        chip_learn_2 = "chip_learn_2",
        chip_learn_3 = "chip_learn_3",
        chip_mechanical_1 = "chip_mechanical",
        chip_mechanical_2 = "chip_mechanical_2",
        chip_medic_1 = "chip_medic",
        chip_medic_2 = "chip_medic_2",
        chip_security_1 = "chip_security",
        chip_security_2 = "chip_security_2",
        deep_chip_blaster_equipped = "chip_blaster",
        deep_chip_commando_equipped = "chip_commando",
        deep_chip_cqb_equipped = "chip_cqb",
        deep_chip_frogman_equipped = "chip_frogman",
        deep_chip_heavy_defender_equipped = "chip_heavy_defender",
        deep_chip_machinegunner_equipped = "chip_machinegunner",
        deep_chip_marksman_equipped = "chip_marksman",
        deep_chip_striker_equipped = "chip_striker",
        deep_chip_ten_star_general_assist_upgrading_effect =
            "deep_ten_star_general_assist_upgrading",
        chip_captain_1 = "chip_captain",
        chip_captain_2 = "chip_captain_2",
    }
    for identifier, itemIdentifier in pairs(subAliases) do
        add(identifier, current.subItems[itemIdentifier])
    end

    for _, identifier in ipairs({
        "chip_emergency_defibrillation_detect",
        "chip_frogman_1",
        "deep_chip_heavy_defender",
        "deep_chip_marksman_1",
        "deep_chip_striker",
        "deep_commando_1",
    }) do addProfile(identifier) end

    local plateAliases = {
        deep_plate_ceramic_debuff = "deep_plate_ceramic_4",
        deep_plate_ceramic_arm_debuff = "deep_plate_ceramic_arm_4",
        deep_plate_ceramic_groin_debuff = "deep_plate_ceramic_groin_4",
        deep_plate_composite_debuff = "deep_plate_composite_6",
        deep_plate_composite_arm_debuff = "deep_plate_composite_arm_6",
        deep_plate_composite_groin_debuff = "deep_plate_composite_groin_6",
    }
    for _, family in ipairs({ "", "arm_", "groin_" }) do
        local first = family == "" and 3 or 4
        local last = family == "" and 10 or 9
        for level = first, last do
            local itemIdentifier = "deep_plate_metal_" .. family .. level
            plateAliases[itemIdentifier .. "_debuff"] = itemIdentifier
        end
    end
    for identifier, itemIdentifier in pairs(plateAliases) do
        add(identifier, current.subItems[itemIdentifier])
    end

    -- These three were coordination markers; retaining the identifier is the behavior.
    for _, identifier in ipairs({
        "chip_captain_only_one",
        "chip_captain_talent_decrease",
        "chip_captain_talent_detect",
    }) do add(identifier, {}) end

    -- Final effect identifiers: the old Affliction was already the result of any host check.
    for _, identifier in ipairs({
        "1_3x_sight", "2.5x_sight", "2x_sight", "3x_sight", "8x_sight",
        "chip_first_aid", "chip_headshot_detect", "chip_oc_gun", "chip_rapid_receiver",
        "chip_unstable_gunpowder", "corner_grip", "cqr_grips", "deep_18c_buttstock",
        "deep_Burst", "deep_Semi", "deep_compensator",
        "deep_damage_fall_off_1500_2300_detect", "deep_damage_fall_off_600_1200_detect",
        "deep_fn57_mute", "deep_glock_drum_mag", "deep_glock_long_mag", "deep_laser_1",
        "deep_machinegunner_heavy_detect", "deep_machinegunner_light_detect", "deep_muffler",
        "deep_muzzle_brake", "deep_pistol_mozambique_aff",
        "deep_shotgun_damgage_balance", "deep_shotgun_damgage_balance_12shell",
        "deep_sniper_aim_heavy_damage_reduce_1", "deep_sniper_aim_heavy_damage_reduce_2",
        "deep_sniper_aim_heavy_damage_reduce_3", "deep_stable_shooting",
        "deep_sub_hanging_debuff", "deepgun_inwater_detect_chip", "expansion_mag",
        "extended_barrel", "flash_hider", "friendly_fire", "holographic_sight",
        "improved_barrel", "oblique_grips", "red_sight", "smg",
        "thermalgoggles_sight", "thermalgoggles_sight_6x", "vertical_grip",
        "vertical_grip_short", "vertical_grips_hollow_out",
    }) do addProfile(identifier) end

    local upgradeProfiles = {
        deep_upgrade_tool_steel_tit_confirm_gl = "deep_upgrade_gl",
        deep_upgrade_tool_steel_tit_confirm_machinegun = "deep_upgrade_machinegun",
        deep_upgrade_tool_steel_tit_confirm_pistol = "deep_upgrade_pistol",
        deep_upgrade_tool_steel_tit_confirm_rifle = "deep_upgrade_rifle",
        deep_upgrade_tool_steel_tit_confirm_shotgun = "deep_upgrade_shotgun",
        deep_upgrade_tool_steel_tit_confirm_smg = "deep_upgrade_smg",
        deep_upgrade_tool_steel_tit_confirm_sniper = "deep_upgrade_sniper",
    }
    for identifier, profileIdentifier in pairs(upgradeProfiles) do
        addProfile(identifier, profileIdentifier)
    end

    -- Detector identifiers still own character-only conditions after the migration.
    addProfile("deep_machinegun_crouch", nil, true)
    addProfile("deep_pistol_mozambique_hand", "deep_pistol_mozambique_aff", true)
    addProfile("deep_knife_detect_1", nil, true)
    add("deep_wuchuan_detection", current.heldWeapons.deep_wuchuan, true)
    add("deep_sniper_aim_heavy", {
        effects = {
            copyProfile(profiles.deep_sniper_aim_heavy_damage_reduce_1, true),
            copyProfile(profiles.deep_sniper_aim_heavy_damage_reduce_2, true),
            copyProfile(profiles.deep_sniper_aim_heavy_damage_reduce_3, true),
        },
    })

    local count = 0
    for _ in pairs(legacy) do count = count + 1 end
    assert(count == 122, "legacy Affliction coverage changed: " .. count)
    return legacy
end
