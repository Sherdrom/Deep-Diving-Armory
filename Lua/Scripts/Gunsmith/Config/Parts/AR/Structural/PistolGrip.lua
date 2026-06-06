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
