local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/HandGuard/HK416.png"

parts.deep_hk416_four_rail_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_hk416_four_rail_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_hk416_four_rail_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 4, y = 5, w = 152, h = 43 },
        attachPoint = { x = 1, y = 22 },
        order = 40,
        scale = 1.0
    },
    -- HK416 护木提供和 AR 通用护木相同的四向导轨挂点。
    -- anchor 相对 HK416 护木 visual.attachPoint，让同一批 AR 共享导轨能跟随 HK416 独有护木定位。
    mounts = { 
        { path = "Left_rail_mount", partType = "accessory_mount", nameKey = "deep.gunsmith.mount.handguard_mount.Left_rail_mount", accepts = { "accessory" }, anchor = { x = 72, y = 0 } , visualOrder = 5, quick = { key = "left_rail" }},
        { path = "Right_rail_mount", partType = "accessory_mount", nameKey = "deep.gunsmith.mount.handguard_mount.Right_rail_mount", accepts = { "accessory" }, anchor = { x = 72, y = 0 }, quick = { key = "right_rail" } },
        { path = "Lower_rail_mount", nameKey = "deep.gunsmith.mount.handguard_mount.Lower_rail_mount", accepts = { "small_grip", "medium_grip", "AR_sub_hanging_gl", "sub_hanging_shotgun"}, anchor = { x = 74, y = 18 }, quick = { key = "lower_rail", showWhenContained = { "deep_sub_hanging_m203", "deep_sub_hanging_master_key" } } },
    }
}
