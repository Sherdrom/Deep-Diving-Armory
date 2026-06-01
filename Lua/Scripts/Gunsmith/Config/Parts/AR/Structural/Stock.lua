Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAR.png"

parts.deep_ctr_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ctr_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ctr_fde_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 4, y = 103, w = 104, h = 76 },
        attachPoint = { x = 103, y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}
