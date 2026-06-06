local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAR.png"

parts.deep_ctr_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ctr_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ctr_fde_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 14, y = 110, w = 104, h = 76 },
        attachPoint = { x = 103, y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_m4ss_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_m4ss_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_m4ss_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 16, y = 12, w = 112, h = 84 },
        attachPoint = { x = 110, y = 13 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_f93_pro_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_f93_pro_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_f93_pro_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 157, y = 12, w = 122, h = 75 },
        attachPoint = { x = 120, y = 13 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_dde_black_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_dde_black_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_dde_black_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 800, y = 450, w = 95, h = 76 },
        attachPoint = { x = 95 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}
