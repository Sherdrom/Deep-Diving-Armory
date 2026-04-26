Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

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
