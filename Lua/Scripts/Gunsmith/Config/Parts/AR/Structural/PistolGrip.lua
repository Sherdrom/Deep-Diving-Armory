local parts = GunsmithFramework.Config.parts

local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/PistolGrip/SharedGripAR.png"

parts.deep_miad_pistol_grip = { type = "pistol_grip",
    nameKey = "deep.gunsmith.part.deep_miad_pistol_grip",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_miad_pistol_grip" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 5, y = 74, w = 53, h = 63 },
        attachPoint = { x = 52, y = 2 },
        order = 50,
        scale = 1.0
    }
}

parts.deep_colta2_pistol_grip = { type = "pistol_grip",
    nameKey = "deep.gunsmith.part.deep_colta2_pistol_grip",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_colta2_pistol_grip" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 6, y = 5, w = 55, h = 60 },
        attachPoint = { x = 53, y = 2 },
        order = 50,
        scale = 1.0
    }
}

parts.deep_tac_hollowedout_pistol_grip = { type = "pistol_grip",
    nameKey = "deep.gunsmith.part.deep_tac_hollowedout_pistol_grip",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_tac_hollowedout_pistol_grip" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 70, y = 7, w = 55, h = 60 },
        attachPoint = { x = 53, y = 2 },
        order = 50,
        scale = 1.0
    }
}

parts.deep_stark_black_pistol_grip = { type = "pistol_grip",
    nameKey = "deep.gunsmith.part.deep_stark_black_pistol_grip",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_stark_black_pistol_grip" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 402, y = 7, w = 52, h = 79 },
        attachPoint = { x = 49, y = 16 },
        order = 50,
        scale = 1.0
    }
}
