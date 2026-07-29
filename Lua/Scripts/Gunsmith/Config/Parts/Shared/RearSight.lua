local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/RearSight/SharedRearSight.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_ar15_rear_sight = {
    type = "rear_sight_mount",
    nameKey = "deep.gunsmith.part.deep_ar15_rear_sight",
    provides = { "AR_rear_sight" },
    item = { identifier = "deep_ar15_rear_sight" },
    stats = { Ergonomics = 0 },
    visual = { texture = texture,
        source = { x = 5, y = 4, w = 31, h = 23 },
        attachPoint = { x = 15, y = 22 },
        order = 40,
        scale = 1.0
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.upper_receiver.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 37, y = -2 }, quick = { key = "optic" } },
    }
}

parts.deep_ar15_handle_rear_sight = {
    type = "rear_sight_mount",
    nameKey = "deep.gunsmith.part.deep_ar15_handle_rear_sight",
    provides = { "AR_rear_sight" },
    item = { identifier = "deep_ar15_handle_rear_sight" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 5, y = 42, w = 114, h = 30 },
        attachPoint = { x = 24, y = 28 },
        order = 40,
        scale = 1.0
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.ar15_handle_rear_sight.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 19, y = -22 }, quick = { key = "optic" }, visualOrder = 35 },
    }
}

parts.deep_ar15_no_rear_sight = {
    uiOrder = -100,
    type = "rear_sight_mount",
    nameKey = "deep.gunsmith.part.deep_ar15_no_rear_sight",
    provides = { "AR_rear_sight" },
    item = { virtual = true },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.upper_receiver.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 37, y = -2 }, quick = { key = "optic" } },
    }
}

