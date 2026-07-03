local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/GasBlock/GasBlock.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_mk12_gas_block = {
    type = "gas_block",
    nameKey = "deep.gunsmith.part.deep_mk12_gas_block",
    provides = { "AR_gas_block" },
    item = { identifier = "deep_mk12_gas_block" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 3, y = 3, w = 16, h = 18 },
        attachPoint = { x = 8, y = 9 },
        order = 35,
        scale = 1.0
    },
}
