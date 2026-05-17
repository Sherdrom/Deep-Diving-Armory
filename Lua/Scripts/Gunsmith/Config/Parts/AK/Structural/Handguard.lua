Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AK74M_handguard = {
    type = "handguard",
    nameKey = "deep.gunsmith.part.AK74M_handguard",
    provides = { "AK_handguard" },
    item = { identifier = "deep_gunsmith_AK74M_handguard" },
    stats = { Ergonomics = 4 },
    visual = {
        texture = texture,
        source = { x = 872, y = 201, w = 92, h = 46 },
        attachPoint = { x = 28, y = 19 },
        order = 30,
        scale = 1
    }
}