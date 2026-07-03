local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAR.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_ace_arfx_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ace_arfx_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ace_arfx_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 314, y = 13, w = 142, h = 62 },
        attachPoint = { x = 139, y = 11 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_viper_pdw_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_viper_pdw_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_viper_pdw_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 310, y = 94, w = 142, h = 55 },
        attachPoint = { x = 136, y = 11 },
        order = 25,
        scale = 1.0
    }
}
