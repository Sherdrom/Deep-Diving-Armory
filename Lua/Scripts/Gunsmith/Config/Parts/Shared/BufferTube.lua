local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/BufferTube/SharedBufferTube.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_hket_buffer_tube = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_hket_buffer_tube",
    provides = { "AR_buffer_tube" },
    item = { identifier = "deep_hket_buffer_tube" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 12, y = 5, w = 102, h = 22 },
        attachPoint = { x = 100, y = 11 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "stock", accepts = { "AR_stock" }, defaultPart = "deep_ctr_fde_stock", anchor = { x = -16, y = -1 } },
    }
}

parts.deep_advanced_buffer_tube = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_advanced_buffer_tube",
    provides = { "AR_buffer_tube" },
    item = { identifier = "deep_advanced_buffer_tube" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 8, y = 82, w = 109, h = 24 },
        attachPoint = { x = 106, y = 12 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "stock", accepts = { "AR_stock" }, defaultPart = "deep_ctr_fde_stock", anchor = { x = -16, y = -1 } },
    }
}
