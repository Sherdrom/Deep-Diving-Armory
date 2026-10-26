local function isInside(character)
    return character and character.CurrentHull ~= nil
end

local function hostIsReloading(_, host)
    return host and host.Condition < 1
end

return {
    ["vertical_grip"] = {
        blockedByEnemyResistance = true,
        statsKey = "vertical_grip",
        stats = {
            { statType = "FlowResistance", value = 1 },
            { statType = "WeaponsSkillBonus", value = 5 },
            { statType = "WalkingSpeed", value = -0.1 },
        },
        resistances = { { id = "stun", multiplier = 0.7, source = "vertical_grip" } },
    },

    ["vertical_grips_short"] = {
        blockedByEnemyResistance = true,
        statsKey = "vertical_grip_short",
        stats = {
            { statType = "FlowResistance", value = 0.5 },
            { statType = "WeaponsSkillBonus", value = 10 },
        },
        resistances = { { id = "stun", multiplier = 0.8, source = "vertical_grip_short" } },
    },

    ["vertical_grips_hollow_out"] = {
        blockedByEnemyResistance = true,
        statsKey = "vertical_grips_hollow_out",
        stats = {
            { statType = "WeaponsSkillGainSpeed", value = 1 },
            { statType = "WeaponsSkillBonus", value = 15 },
            { statType = "ExperienceGainMultiplier", value = 0.3 },
        },
        resistances = { { id = "stun", multiplier = 0.9, source = "vertical_grips_hollow_out" } },
    },

    ["cqr_grips"] = {
        blockedByEnemyResistance = true,
        pollInterval = 0.9,
        when = isInside,
        statsKey = "cqr_grips",
        stats = {
            { statType = "WalkingSpeed", value = 0.1 },
            { statType = "WeaponsSkillBonus", value = 10 },
        },
        resistances = { { id = "stun", multiplier = 0.2, source = "cqr_grips" } },
    },

    ["oblique_grips"] = {
        blockedByEnemyResistance = true,
        pollInterval = 0.9,
        when = hostIsReloading,
        statsKey = "oblique_grips",
        stats = { { statType = "WalkingSpeed", value = 0.2 } },
        resistances = { { id = "stun", multiplier = 0.5, source = "oblique_grips" } },
    },

    ["corner_grip"] = {
        blockedByEnemyResistance = true,
        statsKey = "corner_grip",
        stats = {
            { statType = "WalkingSpeed", value = 0.15 },
            { statType = "WeaponsSkillBonus", value = 25 },
        },
    },

    ["deep_18c_buttstock"] = {
        statsKey = "deep_18c_buttstock",
        stats = {
            { statType = "WalkingSpeed", value = -0.1 },
            { statType = "RangedSpreadReduction", value = 0.2 },
            { statType = "WeaponsSkillBonus", value = 10 },
        },
    },
}
