Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.AR_barrel_145 = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.AR_barrel_145",
    provides = { "AR_barrel" },
    item = { identifier = "deep_gunsmith_AR_barrel_std" },
    stats = { weight = 0.85, ergonomics = -2, recoilControl = 0.04, spreadReduction = 0.06 },
    visual = {
        texture = texture,
        source = { x = 147, y = 688, w = 214, h = 56 },
        attachPoint = { x = 2, y = 40 },
        order = 20,
        scale = 1.0
    }
}

parts.hk416_barrel_std = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.hk416_barrel_std",
    provides = { "AR_barrel" },
    item = { identifier = "deep_gunsmith_hk416_barrel_std" },
    stats = { weight = 0.9, ergonomics = -1, recoilControl = 0.05, spreadReduction = 0.07 },
    visual = {
        texture = texture,
        source = { x = -143, y = 688, w = 203, h = 54 },
        attachPoint = { x = 1, y = 46 },
        order = 20,
        scale = 1.0
    }
}
