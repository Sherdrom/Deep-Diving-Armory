-- Legacy weapon Affliction identifiers kept for third-party XML compatibility.
-- These entries are ordinary AdjustEquipment effects.  The runtime owns the
-- lifetime and removes the effect when the marker is not refreshed in time.

local LEGACY_TIMEOUT = 1.25 -- external XML refreshes are 0.9 s

local COMMON_TALENT = Identifier("deep_talent_all")

local function hasCommonTalent(character)
    return character and character:HasTalent(COMMON_TALENT)
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

local function commonCrouched(character)
    return hasCommonTalent(character) and isCrouched(character)
end

local function commonBelow80(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.8)
end

local function commonBelow50(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.5)
end

local function commonBelow20(character)
    return hasCommonTalent(character) and vitalityAtMost(character, 0.2)
end

local function withTimeout(effect)
    effect.timeout = LEGACY_TIMEOUT
    return effect
end

local commonUpgradeStats = {
    { statType = "RangedAttackMultiplier", value = 0.3 },
    { statType = "RangedAttackSpeed", value = 0.1 },
    { statType = "RangedSpreadReduction", value = 0.5 },
}

return {
    -- Fire mode markers already encode their mode in the weapon XML.
    ["deep_Semi"] = withTimeout({
        statsKey = "deep_Semi",
        statGroup = "deep_Semi",
        stats = {
            { statType = "RangedAttackMultiplier", value = 0.3 },
            { statType = "RangedSpreadReduction", value = 0.7 },
        },
    }),
    ["deep_Burst"] = withTimeout({
        statsKey = "deep_Burst",
        blocksStatGroups = { "deep_Semi" },
        stats = {
            { statType = "RangedAttackMultiplier", value = 0.1 },
            { statType = "RangedSpreadReduction", value = 0.5 },
        },
    }),

    -- The old shotgun marker is consumed by talents; it carries no numeric buff.
    ["deep_shotgun_damgage_balance"] = withTimeout({
        talentMarkers = { "deep_shotgun_damgage_balance" },
    }),

    -- The old upgrade identifiers encode the weapon class in their identifier.
    ["deep_upgrade_tool_steel_tit_confirm_rifle"] = withTimeout({
        statsKey = "deep_upgrade_rifle",
        stats = commonUpgradeStats,
    }),
    ["deep_upgrade_tool_steel_tit_confirm_smg"] = withTimeout({
        statsKey = "deep_upgrade_smg",
        stats = commonUpgradeStats,
    }),
    ["deep_upgrade_tool_steel_tit_confirm_pistol"] = withTimeout({
        statsKey = "deep_upgrade_pistol",
        stats = commonUpgradeStats,
    }),
    ["deep_upgrade_tool_steel_tit_confirm_sniper"] = withTimeout({
        statsKey = "deep_upgrade_sniper",
        stats = commonUpgradeStats,
    }),
    ["deep_upgrade_tool_steel_tit_confirm_shotgun"] = withTimeout({
        statsKey = "deep_upgrade_shotgun",
        stats = {
            { statType = "RangedAttackMultiplier", value = 0.3 },
            { statType = "RangedAttackSpeed", value = 0.1 },
        },
    }),
    ["deep_upgrade_tool_steel_tit_confirm_machinegun"] = withTimeout({
        statsKey = "deep_upgrade_machinegun",
        stats = commonUpgradeStats,
    }),
    ["deep_upgrade_tool_steel_tit_confirm_gl"] = withTimeout({
        statsKey = "deep_upgrade_gl",
        stats = { { statType = "RangedAttackMultiplier", value = 0.3 } },
    }),

    -- Dynamic held-weapon effects have no host in this compatibility path.
    ["deep_machinegun_crouch"] = withTimeout({
        blockedByEnemyResistance = true,
        when = commonCrouched,
        statsKey = "deep_machinegun_crouch",
        stats = { { statType = "RangedSpreadReduction", value = 0.7 } },
    }),
    ["deep_sniper_aim_heavy"] = withTimeout({
        effects = {
            {
                blockedByEnemyResistance = true,
                when = commonBelow80,
                statsKey = "deep_sniper_aim_heavy_damage_reduce_1",
                stats = {
                    { statType = "AttackMultiplier", value = -0.1 },
                    { statType = "RangedSpreadReduction", value = -0.3 },
                },
            },
            {
                blockedByEnemyResistance = true,
                when = commonBelow50,
                statsKey = "deep_sniper_aim_heavy_damage_reduce_2",
                stats = {
                    { statType = "AttackMultiplier", value = -0.1 },
                    { statType = "RangedSpreadReduction", value = -0.3 },
                },
            },
            {
                blockedByEnemyResistance = true,
                when = commonBelow20,
                statsKey = "deep_sniper_aim_heavy_damage_reduce_3",
                stats = {
                    { statType = "AttackMultiplier", value = -0.1 },
                    { statType = "RangedSpreadReduction", value = -0.3 },
                },
            },
        },
    }),

    ["deep_machinegunner_light_detect"] = withTimeout({
        talentMarkers = { "deep_machinegunner_light_detect" },
    }),
    ["deep_compensator"] = withTimeout({
        blockedByEnemyResistance = true,
        statsKey = "deep_compensator",
        stats = {
            { statType = "MaximumHealthMultiplier", value = 0.25 },
            { statType = "RangedSpreadReduction", value = 0.1 },
            { statType = "RangedAttackMultiplier", value = 0.1 },
            { statType = "WeaponsSkillBonus", value = 10 },
        },
    }),
    ["deep_muffler"] = withTimeout({
        blockedByEnemyResistance = true,
        statsKey = "deep_muffler",
        stats = {
            { statType = "SoundRangeMultiplier", value = -0.8 },
            { statType = "RangedSpreadReduction", value = 0.2 },
            { statType = "WeaponsSkillBonus", value = -15 },
        },
        talentMarkers = { "deep_muffler" },
    }),
    ["extended_barrel"] = withTimeout({
        blockedByEnemyResistance = true,
        statsKey = "extended_barrel",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.3 },
            { statType = "RangedAttackMultiplier", value = 0.2 },
            { statType = "RangedAttackSpeed", value = -0.15 },
            { statType = "WeaponsSkillBonus", value = -15 },
        },
    }),
    ["2x_sight"] = withTimeout({
        blockedByEnemyResistance = true,
        statsKey = "2x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.4 },
            { statType = "WeaponsSkillBonus", value = 10 },
            { statType = "RangedAttackMultiplier", value = 0.1 },
            { statType = "WalkingSpeed", value = 0.15 },
        },
    }),
    ["8x_sight"] = withTimeout({
        blockedByEnemyResistance = true,
        statsKey = "8x_sight",
        stats = {
            { statType = "RangedSpreadReduction", value = 0.9 },
            { statType = "WeaponsSkillBonus", value = 30 },
            { statType = "RangedAttackMultiplier", value = 0.3 },
            { statType = "RangedAttackSpeed", value = -0.2 },
            { statType = "WalkingSpeed", value = -0.3 },
        },
    }),
}
