Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local config = Deep_Lua.Gunsmith.Config
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

config.weapons.deep_hk416 = {
    platform = "AR",

    -- 可选：覆盖平台初始装配模板。
    -- HK416 和 M4 共用 AR 平台规则，但初始外观使用自己的独有部件。
    defaults = {
        receiver = "hk416_receiver_std",
        ["receiver/barrel"] = "hk416_barrel_std",
        ["receiver/handguard"] = "hk416_handguard_std",
        ["receiver/pistol_grip"] = "hk416_grip_std",
        ["receiver/stock"] = "hk416_stock_std",
        ["receiver/receiver_top_rail"] = "AR_receiver_top_rail"
    },

    -- HK416 只接受自己的机匣；其他根槽继续沿用 AR 平台通用 accepts。
    rootAccepts = {
        receiver = { "HK416_receiver" }
    },

    rootSockets = {
        receiver = { x = 184, y = 58 }
    },


    -- 以下都为视觉效果参数。
    scale = 1,

    -- preview = {
    --     padding = 0,
    --     zoom = 1.0,
    --     offset = { x = 0, y = 0 }
    -- },

    inventory = {
        scale = 0.35,   -- 库存图标缩放。
        rotation = 45,  -- 库存图标旋转角度，单位是度，正数为顺时针。
        padding = 6     -- 物品栏图标内边距，单位像素。旋转后边缘留白，避免裁切。
    }
}

parts.hk416_receiver_std = {
    slot = "receiver",
    name = "HK416 标准机匣",
    provides = { "HK416_receiver" },
    item = { identifier = "deep_gunsmith_hk416_receiver_std" },
    stats = { weight = 1.08, ergonomics = 9, recoilControl = 0.03 },
    visual = {
        texture = texture,
        source = { x = 13, y = 372, w = 139, h = 89 },
        attachPoint = { x = 71, y = 33 },
        order = 30,
        scale = 1.0
    },

    -- HK416 机匣顶部自带导轨。这里挂一个 virtual part，用它继续提供前/后瞄具挂点。
    -- anchor 相对 receiver.visual.attachPoint。
    mounts = {
        { slot = "receiver_top_rail", name = "顶部导轨", accepts = { "AR_top_rail" }, anchor = { x = 12, y = -23 } },
        { slot = "barrel", name = "枪管", accepts = { "AR_barrel" }, anchor = { x = 250-184, y = 55-58 } },
        { slot = "handguard", name = "护木", accepts = { "AR_handguard" }, anchor = { x = 250-184, y = 55-58 } },
        { slot = "pistol_grip", name = "手枪握把", accepts = { "AR_pistol_grip" }, anchor = { x = 166-184, y = 88-58 } },
        { slot = "stock", name = "枪托", accepts = { "AR_stock" }, anchor = { x = 114-184, y = 59-58 } }
    }
}
