Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AR_stock_std = {
    type = "stock",
    name = "M4标准枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_AR_stock_std" },
    stats = { weight = 0.36, ergonomics = 2, recoilControl = 0.05 },
    visual = {
        texture = texture,
        source = { x = 256, y = 271, w = 113, h = 84 },
        attachPoint = { x = 111, y = 15 },
        order = 10,
        scale = 1.0
    }
}

parts.hk416_stock_std = {
    type = "stock",
    name = "HK416 标准枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_hk416_stock_std" },
    stats = { weight = 0.42, ergonomics = 3, recoilControl = 0.06 },
    visual = {
        texture = texture,
        source = { x = 12, y = 271, w = 104, h = 75 },
        attachPoint = { x = 102, y = 14 },  -- 挂载点位相对source的位置
        order = 10,
        scale = 1.0
    }
}
