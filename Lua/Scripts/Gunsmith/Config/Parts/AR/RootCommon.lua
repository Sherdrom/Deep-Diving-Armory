Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/weapon/rifle/rifle_steel/rifle_steel.png"
local texture2 = Deep_Lua.Path .. "/weapon/rifle/rifle_phy/rifle_phy.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Parts/Weapons/<Weapon>.lua。
parts.AR_receiver_std = {
    -- slot 必须等于平台根槽或父配件 mounts 中声明的子槽。
    slot = "receiver",
    name = "M4 标准机匣",

    -- provides 是兼容类型。平台 rootAccepts 或挂点 accepts 必须接受这个类型才可安装。
    provides = { "AR_receiver" },

    -- 实体配件 item。所有可安装配件都应有 item.identifier；defaults 也会按实体件消耗/返还。
    item = { identifier = "deep_gunsmith_AR_receiver_std" },

    -- 目前只用于 UI 展示，不直接影响武器实际数值。
    stats = { weight = 1.0, ergonomics = 8, recoilControl = 0.02 },

    -- visual 是运行时合成图层。根部件使用 offset，表示放到平台 canvas 上的绝对位置。
    -- 子配件优先使用父挂点 anchor + visual.relativeOffset；没有 relativeOffset 时才回退 offset。
    -- order 越小越早绘制，scale 是单个配件缩放。
    visual = {
        texture = texture,
        source = { x = 144, y = 607, w = 126, h = 36 },
        offset = { x = 115, y = 27 },
        order = 30,
        scale = 1.0
    }
}

parts.AR_receiver_alt = {
    slot = "receiver",
    name = "M4 备用机匣",
    provides = { "AR_receiver" },
    item = { identifier = "deep_gunsmith_AR_receiver_alt" },
    stats = { weight = 0.9, ergonomics = 10, recoilControl = 0.01 },
    visual = {
        texture = texture,
        source = { x = 130, y = 610, w = 165, h = 58 },
        offset = { x = 166, y = 56 },
        order = 30,
        scale = 1.0
    }
}

parts.AR_barrel_145 = {
    slot = "barrel",
    name = "14.5 英寸枪管",
    provides = { "AR_barrel" },
    item = { identifier = "deep_gunsmith_AR_barrel_145" },
    stats = { weight = 0.85, ergonomics = -2, recoilControl = 0.04, spreadReduction = 0.06 },
    visual = {
        texture = texture,
        source = { x = 266, y = 619, w = 214, h = 12 },
        offset = { x = 237, y = 39 },
        order = 20,
        scale = 1.0
    }
}

parts.AR_barrel_short = {
    slot = "barrel",
    name = "短枪管",
    provides = { "AR_barrel" },
    item = { identifier = "deep_gunsmith_AR_barrel_short" },
    stats = { weight = 0.58, ergonomics = 4, recoilControl = -0.02, spreadReduction = -0.03 },
    visual = {
        texture = texture,
        source = { x = 285, y = 612, w = 126, h = 34 },
        offset = { x = 288, y = 66 },
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
        source = { x = 268, y = 585, w = 143, h = 60 },
        offset = { x = 237, y = 5 },
        order = 40,
        scale = 1.0
    },
    -- mounts 声明该配件安装后提供的子挂点。
    -- anchor 是子槽在平台 canvas 上的挂点位置，供导轨、瞄具等子配件跟随父配件定位。
    -- 子挂点同样通过 accepts/provides 做兼容检查。
    mounts = {
        { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" }, anchor = { x = 276, y = 58 } },
        { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" }, anchor = { x = 286, y = 104 } },
        { slot = "left_rail", name = "左导轨", accepts = { "picatinny_rail" }, anchor = { x = 274, y = 82 } },
        { slot = "right_rail", name = "右导轨", accepts = { "picatinny_rail" }, anchor = { x = 304, y = 82 } }
    }
}

parts.AR_handguard_alt = {
    slot = "handguard",
    name = "轻量护木",
    provides = { "AR_handguard" },
    item = { identifier = "deep_gunsmith_AR_handguard_alt" },
    stats = { weight = 0.32, ergonomics = 5, recoilControl = -0.01 },
    visual = {
        texture = texture,
        source = { x = 262, y = 628, w = 92, h = 34 },
        offset = { x = 268, y = 72 },
        order = 40,
        scale = 1.0
    },
    mounts = {
        { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" }, anchor = { x = 282, y = 62 } },
        { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" }, anchor = { x = 294, y = 98 } }
    }
}

parts.AR_grip_std = {
    slot = "pistol_grip",
    name = "A2 握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_AR_grip_std" },
    stats = { weight = 0.12, ergonomics = 3, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 130, y = 644, w = 137, h = 70 },
        offset = { x = 101, y = 64 },
        order = 50,
        scale = 1.0
    }
}

parts.AR_grip_alt = {
    slot = "pistol_grip",
    name = "紧凑握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_AR_grip_alt" },
    stats = { weight = 0.09, ergonomics = 6, recoilControl = -0.01 },
    visual = {
        texture = texture,
        source = { x = 198, y = 652, w = 34, h = 52 },
        offset = { x = 214, y = 90 },
        order = 50,
        scale = 1.0
    }
}

parts.AR_stock_std = {
    slot = "stock",
    name = "卡宾枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_AR_stock_std" },
    stats = { weight = 0.36, ergonomics = 2, recoilControl = 0.05 },
    visual = {
        texture = texture,
        source = { x = 29, y = 607, w = 115, h = 62 },
        offset = { x = 0, y = 27 },
        order = 10,
        scale = 1.0
    }
}

parts.AR_stock_alt = {
    slot = "stock",
    name = "短枪托",
    provides = { "AR_stock" },
    item = { identifier = "deep_gunsmith_AR_stock_alt" },
    stats = { weight = 0.22, ergonomics = 6, recoilControl = -0.03 },
    visual = {
        texture = texture,
        source = { x = 50, y = 614, w = 82, h = 54 },
        offset = { x = 64, y = 66 },
        order = 10,
        scale = 1.0
    }
}
