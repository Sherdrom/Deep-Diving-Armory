Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local config = Deep_Lua.Gunsmith.Config

-- 平台 = 一类枪械共用的改装骨架。
-- deep_m4 和 deep_hk416 都挂在 AR 平台上，因此它们共用 receiver-led 结构、兼容规则和槽位显示名。
config.platforms.AR = {
    id = "AR",

    -- 运行时合成贴图的画布尺寸。
    -- 根槽 rootSockets 使用这个平台 canvas 坐标系。
    -- 子配件可以用 visual.attachPoint 对齐父配件本地 mount.anchor。
    canvas = { w = 512, h = 160 },

    -- 平台级缩放。weapon.scale 和 part.visual.scale 会继续叠乘。
    visualScale = 1.0,

    -- 平台缩放的中心点。通常放在画布中心，除非整个平台图层需要偏心缩放。
    visualOrigin = { x = 256, y = 80 },

    -- 根槽。V0.9 起 AR 平台只有 receiver 直接挂在 weapon 上。
    -- 枪管、护木、握把、枪托等结构件由当前 receiver 的 mounts 暴露出来。
    slots = { "receiver" },

    -- true 表示根槽不可拆空；只能换成另一个兼容配件。
    requiredRootSlots = true,

    -- 嵌套结构槽同样不可拆空；只能替换成兼容配件。
    requiredSlots = {
        ["receiver/barrel"] = true,
        ["receiver/handguard"] = true,
        ["receiver/pistol_grip"] = true,
        ["receiver/stock"] = true
    },

    -- receiver 是武器身份件，不作为普通可改项显示；其子槽会提升到 UI 首页。
    hiddenRootSlots = {
        receiver = true
    },

    -- 根槽兼容规则：槽位接受的类型必须和 part.provides 至少命中一个。
    -- receiver 在具体武器里通常会用 weapon.rootAccepts 覆盖成 M4_receiver / HK416_receiver 等独有类型。
    -- 这里的 receiver 规则只作为未覆盖武器的兜底。
    rootAccepts = {
        receiver = { "M4_receiver" }
    },

    -- UI 显示名。没有写在这里的 slot 会直接显示内部 key。
    -- 子挂点 slot 也建议登记在这里，方便路径显示为“枪械 > 护木 > 上导轨”。
    slotNames = {
        receiver = "机匣",
        barrel = "枪管",
        handguard = "护木",
        pistol_grip = "手枪握把",
        stock = "枪托",
        muzzle_device = "枪口装置",
        top_rail = "上导轨",
        bottom_rail = "下导轨",
        left_rail = "左导轨",
        right_rail = "右导轨",
        optic_mount = "瞄具挂点"
    },

    -- 平台默认配件。未声明 weapon.defaults 的武器会从这里初始化。
    -- defaults 只表示初始装配模板；安装/替换时仍按实体 item 消耗和返还。
    defaults = {
        receiver = "M4_receiver_std",
        ["receiver/barrel"] = "AR_barrel_145",
        ["receiver/handguard"] = "AR_handguard_std",
        ["receiver/pistol_grip"] = "AR_grip_std",
        ["receiver/stock"] = "AR_stock_std"
    }
}
