local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAK.png"

parts.deep_6p20_sb5_ak_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_6p20_sb5_ak_stock",
    provides = { "AK_stock" },
    item = { identifier = "deep_6p20_sb5_ak_stock" },
    stats = { Ergonomics = 2 },
    visual = { 
        texture = texture,
        source = { x = 7, y = 6, w = 141, h = 60 },
        attachPoint = { x = 140, y = 13 },
        order = 35,
        scale = 1
    }
}
