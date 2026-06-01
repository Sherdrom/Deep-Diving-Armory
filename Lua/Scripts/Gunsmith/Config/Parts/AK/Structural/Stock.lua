Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAK.png"

parts.deep_6p20_sb5_ak_stock = {
    type = "stock",
    nameKey = "deep.gunsmith.part.deep_6p20_sb5_ak_stock",
    provides = { "AK_stock" },
    item = { identifier = "deep_6p20_sb5_ak_stock" },
    stats = { Ergonomics = 2 },
    visual = { 
        texture = texture,
        source = { x = 6, y = 7, w = 142, h = 60 },
        attachPoint = { x = 142, y = 14 },
        order = 30,
        scale = 1
    }
}
