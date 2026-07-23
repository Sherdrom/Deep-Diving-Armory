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
        source = { x = 7, y = 8, w = 152, h = 43 },
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

parts.deep_hk416_9mlok_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_hk416_9mlok_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_hk416_9mlok_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 8, y = 61, w = 155, h = 44 },
        attachPoint = { x = -1, y = 23 },
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

parts.deep_hk416_13mlok_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_hk416_13mlok_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_hk416_13mlok_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 8, y = 115, w = 220, h = 43 },
        attachPoint = { x = 2, y = 22 },
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

parts.deep_hk416_14mrs_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_hk416_14mrs_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_hk416_14mrs_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 8, y = 169, w = 234, h = 42 },
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

parts.deep_hk416_15mlok_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_hk416_15mlok_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_hk416_15mlok_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 8, y = 221, w = 250, h = 42 },
        attachPoint = { x = 2, y = 22 },
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

parts.deep_nl545_10_5mlok_fde_handguard = { type = "handguard",
    nameKey = "deep.gunsmith.part.deep_nl545_10_5mlok_fde_handguard",
    provides = { "AR_handguard" },
    item = { identifier = "deep_nl545_10_5mlok_fde_handguard" },
    stats = { Ergonomics = 4 },
    visual = { 
        texture = texture,
        source = { x = 8, y = 277, w = 198, h = 48 },
        attachPoint = { x = 2, y = 22 },
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
