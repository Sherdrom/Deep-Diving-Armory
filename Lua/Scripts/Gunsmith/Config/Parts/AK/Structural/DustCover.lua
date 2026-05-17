Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AK74M_dustcover = {
    type = "dust_cover",
    nameKey = "deep.gunsmith.part.AK74M_dustcover",
    provides = { "AK_dust_cover" },
    item = { identifier = "deep_gunsmith_AK74M_dustcover" },
    stats = { Ergonomics = 2 },
    visual = {
        texture = texture,
        source = { x = 725, y = 193, w = 134, h = 34 },
        attachPoint = { x = 94, y = 15 },
        order = 30,
        scale = 1
    }
}