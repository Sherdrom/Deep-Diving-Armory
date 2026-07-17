local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/UpperReceiver/HK416.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_hk416a5_upper_receiver = {
    type = "upper_receiver",
    nameKey = "deep.gunsmith.part.deep_hk416a5_upper_receiver",
    provides = { "AR_upper_receiver" },
    item = { identifier = "deep_hk416a5_upper_receiver" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 8, y = 5, w = 161, h = 43 },
        attachPoint = { x = 80, y = 22 },
        order = 35,
        scale = 1.0
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.upper_receiver.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 1, y = -20 }, quick = { key = "optic" } },
        { path = "barrel", accepts = { "AR_barrel" }, defaultPart = "deep_556_45_370mm_barrel", anchor = { x = 47, y = 1 } },
        { path = "handguard", accepts = { "AR_handguard" }, defaultPart = "deep_hk416_four_rail_handguard", anchor = { x = 47, y = 1 } },
        { path = "rear_sight_mount", accepts = { "AR_rear_sight" }, defaultPart = "deep_ar15_rear_sight", anchor = { x = -36, y = -18 } },
    }
}
