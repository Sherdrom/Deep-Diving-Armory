Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Parts/Weapons/<Weapon>.lua。
parts.AR_barrel_145 = {
    slot = "barrel",
    name = "M4标准枪管",
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

parts.AR_handguard_std = {
    slot = "handguard",
    name = "M4 标准护木",
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
    -- anchor 是子槽在平台 canvas 上的挂点位置，供导轨、瞄具等子配件跟随父配件定位。
    -- 子挂点同样通过 accepts/provides 做兼容检查。
    mounts = {
        { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" }, anchor = { x = 39, y = 53 } },
        { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" }, anchor = { x = 49, y = 99 } },
        { slot = "left_rail", name = "左导轨", accepts = { "picatinny_rail" }, anchor = { x = 37, y = 77 } },
        { slot = "right_rail", name = "右导轨", accepts = { "picatinny_rail" }, anchor = { x = 67, y = 77 } }
    }
}

parts.AR_grip_std = {
    slot = "pistol_grip",
    name = "M4标准握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_AR_grip_std" },
    stats = { weight = 0.12, ergonomics = 3, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 256, y = 585, w = 57, h = 63 },
        attachPoint = { x = 54, y = 2 },
        order = 50,
        scale = 1.0
    }
}

parts.AR_stock_std = {
    slot = "stock",
    name = "M4标准枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_AR_stock_std" },
    stats = { weight = 0.36, ergonomics = 2, recoilControl = 0.05 },
    visual = {
        texture = texture,
        source = { x = 256, y = 271, w = 113, h = 84 },
        attachPoint = { x = 111, y = 15 },
        order = 10,
        scale = 1.0
    }
}

parts.hk416_stock_std = {
    slot = "stock",
    name = "HK416 标准枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_hk416_stock_std" },
    stats = { weight = 0.42, ergonomics = 3, recoilControl = 0.06 },
    visual = {
        texture = texture,
        source = { x = 12, y = 271, w = 104, h = 75 },
        attachPoint = { x = 102, y = 14 },  -- 挂载点位相对source的位置
        order = 10,
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
        source = { x = 15, y = 585, w = 55, h = 65 },
        attachPoint = { x = 53, y = 1 },
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
        source = { x = 13, y = 502, w = 158, h = 44 },
        attachPoint = { x = 0, y = 21 },
        order = 40,
        scale = 1.0
    },
    -- HK416 护木提供和 AR 通用护木相同的四向导轨挂点。
    -- anchor 使用平台 canvas 坐标，让同一批 AR 共享导轨能跟随 HK416 独有护木定位。
    mounts = {
        { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" }, anchor = { x = 16, y = 44 } },
        { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" }, anchor = { x = 32, y = 104 } },
        { slot = "left_rail", name = "左导轨", accepts = { "picatinny_rail" }, anchor = { x = 14, y = 74 } },
        { slot = "right_rail", name = "右导轨", accepts = { "picatinny_rail" }, anchor = { x = 46, y = 74 } }
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
        source = { x = -143, y = 688, w = 203, h = 54 },
        attachPoint = { x = 1, y = 46 },
        order = 20,
        scale = 1.0
    }
}
