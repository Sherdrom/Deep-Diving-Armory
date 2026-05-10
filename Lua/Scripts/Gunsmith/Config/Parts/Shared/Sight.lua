Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local sightTexture = Deep_Lua.Path .. "/weapon/sight/sight_2.png"

-- 通用瞄具。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.deep_holo_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_holo_sight",
    -- small_optic / medium_optic 由导轨或机匣的 optic_mount.accepts 决定。
    provides = { "small_optic" },
    item = { identifier = "holographic_sight" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.30, RangedAttackMultiplier = 0.15, WeaponsSkillBonus = 15, WalkingSpeed = 0.20 },
    visual = { 
        texture = sightTexture,
        source = { x = 5, y = 5, w = 97, h = 62 },
        attachPoint = { x = 48, y = 57 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_red_dot = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_red_dot",
    provides = { "small_optic" },
    item = { identifier = "red_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.15, RangedAttackMultiplier = 0.20, WeaponsSkillBonus = 20, WalkingSpeed = 0.30 },
    visual = { 
        texture = sightTexture,
        source = { x = 106, y = 2, w = 105, h = 66 },
        attachPoint = { x = 52, y = 61 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_thermalgoggles_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_thermalgoggles_sight",
    provides = { "small_optic" },
    item = { identifier = "thermalgoggles_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.30, WeaponsSkillBonus = -15 },
    visual = { 
        texture = sightTexture,
        source = { x = 219, y = 3, w = 90, h = 69 },
        attachPoint = { x = 45, y = 63 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_2x_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_2x_sight",
    provides = { "small_optic" },
    item = { identifier = "2x_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.40, RangedAttackMultiplier = 0.10, WeaponsSkillBonus = 10, WalkingSpeed = 0.15 },
    visual = { 
        texture = sightTexture,
        source = { x = 5, y = 71, w = 129, h = 81 },
        attachPoint = { x = 64, y = 74 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_2x5x_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_2x5x_sight",
    provides = { "small_optic" },
    item = { identifier = "2.5x_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.60, RangedAttackMultiplier = 0.05, WeaponsSkillBonus = 20, WalkingSpeed = 0.10 },
    visual = { 
        texture = sightTexture,
        source = { x = 6, y = 154, w = 219, h = 82 },
        attachPoint = { x = 109, y = 74 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_1_3x_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_1_3x_sight",
    provides = { "small_optic" },
    item = { identifier = "1_3x_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.70, WeaponsSkillBonus = 25 },
    visual = { 
        texture = sightTexture,
        source = { x = 5, y = 236, w = 199, h = 80 },
        attachPoint = { x = 99, y = 75 },
        order = 70,
        scale = 0.55
    }
}

parts.deep_1_6x_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_1_6x_sight",
    provides = { "medium_optic" },
    item = { identifier = "3x_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.80, WeaponsSkillBonus = 30, WalkingSpeed = -0.25 },
    visual = { 
        texture = sightTexture,
        source = { x = 5, y = 537, w = 381, h = 103 },
        attachPoint = { x = 190, y = 97 },
        order = 70,
        scale = 0.45
    }
}

parts.deep_thermalgoggles_sight_6x = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_thermalgoggles_sight_6x",
    provides = { "medium_optic" },
    item = { identifier = "thermalgoggles_sight_6x" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.80, WeaponsSkillBonus = 25, WalkingSpeed = -0.30 },
    visual = { 
        texture = sightTexture,
        source = { x = 401, y = 535, w = 393, h = 103 },
        attachPoint = { x = 196, y = 97 },
        order = 70,
        scale = 0.45
    }
}

parts.deep_8x_sight = { type = "optic_mount",
    nameKey = "deep.gunsmith.part.deep_8x_sight",
    provides = { "large_optic" },
    item = { identifier = "8x_sight" },
    stats = { Ergonomics = -2, RangedSpreadReduction = 0.80, WeaponsSkillBonus = 30, WalkingSpeed = -0.25 },
    visual = { 
        texture = sightTexture,
        source = { x = 5, y = 667, w = 469, h = 106 },
        attachPoint = { x = 234, y = 98 },
        order = 70,
        scale = 0.45
    }
}


