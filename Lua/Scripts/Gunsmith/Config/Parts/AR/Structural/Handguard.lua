Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AR_handguard_std = {
    type = "handguard",
    nameKey = "deep.gunsmith.part.AR_handguard_std",
    provides = { "AR_handguard" },
    item = { identifier = "deep_gunsmith_AR_handguard_std" },
    stats = { weight = 0.48, ergonomics = 2, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 255, y = 502, w = 112, h = 43 },
        attachPoint = { x = 1, y = 21 },
        order = 40,
        scale = 1.0
    },
    -- mounts 声明该配件安装后提供的子挂点。
    -- anchor 相对当前配件 visual.attachPoint，供导轨、瞄具等子配件跟随父配件定位。
    -- 子挂点同样通过 accepts/provides 做兼容检查。
    mounts = {
        { path = "top_rail", accepts = { "picatinny_rail" }, anchor = { x = 39, y = 53 } },
        { path = "bottom_rail", accepts = { "picatinny_rail" }, anchor = { x = 49, y = 99 } },
        { path = "left_rail", accepts = { "picatinny_rail" }, anchor = { x = 37, y = 77 } },
        { path = "right_rail", accepts = { "picatinny_rail" }, anchor = { x = 67, y = 77 } }
    }
}

parts.hk416_handguard_std = {
    type = "handguard",
    nameKey = "deep.gunsmith.part.hk416_handguard_std",
    provides = { "AR_handguard" },
    item = { identifier = "deep_gunsmith_hk416_handguard_std" },
    stats = { weight = 0.55, ergonomics = 4, recoilControl = 0.03 },
    visual = {
        texture = texture,
        source = { x = 13, y = 502, w = 158, h = 44 },
        attachPoint = { x = 0, y = 21 },
        order = 40,
        scale = 1.0
    },
    -- HK416 护木提供和 AR 通用护木相同的四向导轨挂点。
    -- anchor 相对 HK416 护木 visual.attachPoint，让同一批 AR 共享导轨能跟随 HK416 独有护木定位。
    mounts = {
        { path = "top_rail", accepts = { "picatinny_rail" }, anchor = { x = 16, y = 44 } },
        { path = "bottom_rail", accepts = { "picatinny_rail" }, anchor = { x = 32, y = 104 } },
        { path = "left_rail", accepts = { "picatinny_rail" }, anchor = { x = 14, y = 74 } },
        { path = "right_rail", accepts = { "picatinny_rail" }, anchor = { x = 46, y = 74 } },
        { path = "Lower_rail_mount", nameKey = "deep.gunsmith.mount.hk416_handguard_std.Lower_rail_mount", accepts = { "small_grip", "medium_grip" }, anchor = { x = 56, y = 20 } }
    }
}
