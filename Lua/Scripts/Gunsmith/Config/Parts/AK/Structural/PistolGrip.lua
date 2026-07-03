local parts = GunsmithFramework.Config.parts

local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/PistolGrip/SharedGripAK.png"

parts.deep_6p4_sb9_ak_pistol_grip = {
    type = "pistol_grip",
    nameKey = "deep.gunsmith.part.deep_6p4_sb9_ak_pistol_grip",
    provides = { "AK_pistol_grip" },
    item = { identifier = "deep_6p4_sb9_ak_pistol_grip" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 3, y = 4, w = 42, h = 58 },
        attachPoint = { x = 41, y = 1 },
        order = 50,
        scale = 1
    }
}
