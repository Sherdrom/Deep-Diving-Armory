local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/FrontSight/SharedFrontSight.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_ar15_front_sight = {
    type = "front_sight_mount",
    nameKey = "deep.gunsmith.part.deep_ar15_front_sight",
    provides = { "AR_front_sight" },
    item = { identifier = "deep_ar15_front_sight" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 10, y = 6, w = 27, h = 22 },
        attachPoint = { x = 14, y = 21 },
        order = 40,
        scale = 1.0
    },
}
