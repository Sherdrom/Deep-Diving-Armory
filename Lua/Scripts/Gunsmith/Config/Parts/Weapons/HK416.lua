Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local texture = Deep_Lua.Path .. "/weapon/rifle/rifle_phy/rifle_phy.png"

-- HK416 独有外观件。
-- 这些 part 仍然 provides AR_* 兼容类型，所以它们可以装进 AR 平台根槽；
-- 但它们主要由 Weapons/AR.lua 中的 deep_hk416.defaults 作为初始装配使用。
parts.hk416_stock_std = {
    slot = "stock",
    name = "HK416 标准枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_hk416_stock_std" },
    stats = { weight = 0.42, ergonomics = 3, recoilControl = 0.06 },
    visual = {
        texture = texture,
        source = { x = 815, y = 13, w = 122, h = 145 },
        offset = { x = 22, y = 8 },
        order = 10,
        scale = 1.0
    }
}

parts.hk416_receiver_std = {
    slot = "receiver",
    name = "HK416 标准机匣",
    provides = { "AR_receiver" },
    item = { identifier = "deep_gunsmith_hk416_receiver_std" },
    stats = { weight = 1.08, ergonomics = 9, recoilControl = 0.03 },
    visual = {
        texture = texture,
        source = { x = 937, y = 13, w = 137, h = 145 },
        offset = { x = 144, y = 8 },
        order = 30,
        scale = 1.0
    }
}

parts.hk416_grip_std = {
    slot = "pistol_grip",
    name = "HK416 标准握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_hk416_grip_std" },
    stats = { weight = 0.14, ergonomics = 4, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 1074, y = 13, w = 55, h = 145 },
        offset = { x = 281, y = 8 },
        order = 50,
        scale = 1.0
    }
}

parts.hk416_handguard_std = {
    slot = "handguard",
    name = "HK416 标准护木",
    provides = { "AR_handguard" },
    item = { identifier = "deep_gunsmith_hk416_handguard_std" },
    stats = { weight = 0.55, ergonomics = 4, recoilControl = 0.03 },
    visual = {
        texture = texture,
        source = { x = 1129, y = 13, w = 105, h = 145 },
        offset = { x = 336, y = 8 },
        order = 40,
        scale = 1.0
    },
    -- HK416 护木提供和 AR 通用护木相同的四向导轨挂点。
    -- anchor 使用平台 canvas 坐标，让同一批 AR 共享导轨能跟随 HK416 独有护木定位。
    mounts = {
        { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" }, anchor = { x = 352, y = 52 } },
        { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" }, anchor = { x = 368, y = 112 } },
        { slot = "left_rail", name = "左导轨", accepts = { "picatinny_rail" }, anchor = { x = 350, y = 82 } },
        { slot = "right_rail", name = "右导轨", accepts = { "picatinny_rail" }, anchor = { x = 382, y = 82 } }
    }
}

parts.hk416_barrel_std = {
    slot = "barrel",
    name = "HK416 标准枪管",
    provides = { "AR_barrel" },
    item = { identifier = "deep_gunsmith_hk416_barrel_std" },
    stats = { weight = 0.9, ergonomics = -1, recoilControl = 0.05, spreadReduction = 0.07 },
    visual = {
        texture = texture,
        source = { x = 1234, y = 13, w = 48, h = 145 },
        offset = { x = 441, y = 8 },
        order = 20,
        scale = 1.0
    }
}
