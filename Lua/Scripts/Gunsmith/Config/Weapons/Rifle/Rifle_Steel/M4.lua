Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local config = Deep_Lua.Gunsmith.Config

local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

-- 武器条目把 Barotrauma 物品 identifier 接入 GunSmith。
-- key 必须等于 XML 里的 Item identifier，例如 weapon/rifle/.../m4.xml 中的 deep_m4。
config.weapons.deep_m4 = {
    -- 绑定到 Config/Platforms/AR.lua 中定义的平台 key。
    platform = "AR",

    defaults = {
        receiver = "M4_receiver_std",
        ["receiver/barrel"] = "AR_barrel_145",
        ["receiver/handguard"] = "AR_handguard_std",
        ["receiver/pistol_grip"] = "AR_grip_std",
        ["receiver/stock"] = "AR_stock_std"
    },

    -- 武器级根槽兼容覆盖。机匣是武器独有件，所以 M4 只接受 M4_receiver。
    rootAccepts = {
        receiver = { "M4_receiver" }
    },

    -- 根槽接口点。根部件会用 visual.attachPoint 对齐 rootSockets[slot]。
    rootSockets = {
        receiver = { x = 209, y = 60 }
    },

    -- 以下都为视觉效果参数。
    -- 武器级整体视觉缩放，会和 platform.visualScale、part.visual.scale 相乘。
    scale = 1,

    -- 选填，可注释。UI 预览窗口微调，只影响 GunSmith 窗口里的预览，不影响世界/背包贴图。
    preview = {
        padding = 0,
        zoom = 1.0,
        offset = { x = 0, y = 0 }
    },

    -- 只影响物品栏图标。rotation 单位为度，正数为顺时针。
    inventory = {
        scale = 0.35,   -- 库存图标缩放。
        rotation = 45,  -- 库存图标旋转角度，单位是度，正数为顺时针。
        padding = 6     -- 物品栏图标内边距，单位像素。旋转后边缘留白，避免裁切。
    }
}

-- 枪械主题机匣的part挪到这里，和平台、武器配置放在一起，方便对照。
parts.M4_receiver_std = {
    -- slot 必须等于平台根槽或父配件 mounts 中声明的子槽。
    slot = "receiver",
    name = "M4 标准机匣",

    -- provides 是兼容类型。平台 rootAccepts 或挂点 accepts 必须接受这个类型才可安装。
    provides = { "M4_receiver" },

    -- 实体配件 item。所有可安装配件都应有 item.identifier；defaults 也会按实体件消耗/返还。
    item = { identifier = "deep_gunsmith_M4_receiver_std" },

    -- 目前只用于 UI 展示，不直接影响武器实际数值。
    stats = { weight = 1.0, ergonomics = 8, recoilControl = 0.02 },

    -- visual 是运行时合成图层。根部件用自己的 attachPoint 对齐当前武器 rootSockets[slot]。
    -- attachPoint 是配件 source 内部的本地连接点。
    -- 子配件同理：父配件 mounts.anchor 是父配件本地挂点，子配件 attachPoint 会对齐到该挂点。
    -- order 越小越早绘制，scale 是单个配件缩放。
    visual = {
        texture = texture,
        source = { x = 254, y = 370, w = 135, h = 96 },
        attachPoint = { x = 71, y = 47 },
        order = 30,
        scale = 1.0
    },

    -- V0.9: receiver 是 AR 的结构核心。anchor 相对 receiver.visual.attachPoint。
    mounts = {
        { slot = "barrel", name = "枪管", accepts = { "AR_barrel" }, anchor = { x = 62, y = -3 } },
        { slot = "handguard", name = "护木", accepts = { "AR_handguard" }, anchor = { x = 62, y = -3 } },
        { slot = "pistol_grip", name = "手枪握把", accepts = { "AR_pistol_grip" }, anchor = { x = -26, y = 27 } },
        { slot = "stock", name = "枪托", accepts = { "AR_stock" }, anchor = { x = -68, y = 0 } },
        { slot = "optic_mount", name = "机匣瞄具挂点", accepts = { "small_optic", "medium_optic" }, anchor = { x = 18, y = 24 } }
    }
}
