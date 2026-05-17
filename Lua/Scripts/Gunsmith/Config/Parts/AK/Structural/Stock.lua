Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AK74M_stock = {
    type = "stock",
    nameKey = "deep.gunsmith.part.AK74M_stock",
    provides = { "AK_stock" },
    item = { identifier = "deep_gunsmith_AK74M_stock" },
    stats = { Ergonomics = 2 },
    visual = { 
        texture = texture,
        source = { x = 537, y = 199, w = 150, h = 67 },
        attachPoint = { x = 146, y = 17 },
        order = 30,
        scale = 1
    }
}
