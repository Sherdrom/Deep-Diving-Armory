Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AK74M_grip = {
    type = "pistol_grip",
    nameKey = "deep.gunsmith.part.AK74M_grip",
    provides = { "AK_pistol_grip" },
    item = { identifier = "deep_gunsmith_AK74M_grip" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 584, y = 589, w = 46, h = 62 },
        attachPoint = { x = 43, y = 2 },
        order = 30,
        scale = 1
    }
}
