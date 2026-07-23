local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/GasBlock/GasBlock.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_lo_pro_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_lo_pro_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_lo_pro_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 3, y = 3, w = 16, h = 18 },
        attachPoint = { x = 8, y = 9 },
        order = 35,
        scale = 1.0
    },
}

parts.deep_mk12_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_mk12_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_mk12_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 3, y = 25, w = 23, h = 17 },
        attachPoint = { x = 9, y = 9 },
        order = 35,
        scale = 1.0
    },
}

parts.deep_weaponry_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_weaponry_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_weaponry_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 4, y = 46, w = 23, h = 28 },
        attachPoint = { x = 17, y = 20 },
        order = 35,
        scale = 1.0
    },
}

parts.deep_sentry7_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_sentry7_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_sentry7_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 11, y = 78, w = 14, h = 16 },
        attachPoint = { x = 5, y = 9 },
        order = 35,
        scale = 1.0
    },
}

parts.deep_jp_5b_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_jp_5b_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_jp_5b_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 10, y = 100, w = 15, h = 15 },
        attachPoint = { x = 9, y = 9 },
        order = 35,
        scale = 1.0
    },
}

parts.deep_hk416a5_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_hk416a5_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_hk416a5_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 30, y = 3, w = 32, h = 23 },
        attachPoint = { x = 25, y = 10 },
        order = 35,
        scale = 1.0
    },
}
