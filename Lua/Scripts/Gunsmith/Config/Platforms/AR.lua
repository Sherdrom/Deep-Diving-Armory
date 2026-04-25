Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local config = Deep_Lua.Gunsmith.Config

-- 平台 = 一类枪械共用的改装骨架。
-- deep_m4 和 deep_hk416 都挂在 AR 平台上，因此它们共用根槽、兼容规则和槽位显示名。
config.platforms.AR = {
    id = "AR",

    -- 运行时合成贴图的画布尺寸。
    -- 根部件 visual.offset 和挂点 anchor 都使用这个平台 canvas 坐标系。
    -- 子配件可以用 visual.relativeOffset 相对父挂点定位。
    canvas = { w = 512, h = 160 },

    -- 平台级缩放。weapon.scale 和 part.visual.scale 会继续叠乘。
    visualScale = 1.0,

    -- 平台缩放的中心点。通常放在画布中心，除非整个平台图层需要偏心缩放。
    visualOrigin = { x = 256, y = 80 },

    -- 根槽。这里的顺序会影响 UI 左侧根层级按钮顺序。
    slots = { "receiver", "barrel", "handguard", "pistol_grip", "stock" },

    -- true 表示根槽不可拆空；只能换成另一个兼容配件。
    requiredRootSlots = true,

    -- 根槽兼容规则：槽位接受的类型必须和 part.provides 至少命中一个。
    -- 例：receiver 接受 AR_receiver，所以 provides = { "AR_receiver" } 的配件才能装进 receiver。
    rootAccepts = {
        receiver = { "AR_receiver" },
        barrel = { "AR_barrel" },
        handguard = { "AR_handguard" },
        pistol_grip = { "AR_pistol_grip" },
        stock = { "AR_stock" }
    },

    -- UI 显示名。没有写在这里的 slot 会直接显示内部 key。
    -- 子挂点 slot 也建议登记在这里，方便路径显示为“枪械 > 护木 > 上导轨”。
    slotNames = {
        receiver = "机匣",
        barrel = "枪管",
        handguard = "护木",
        pistol_grip = "手枪握把",
        stock = "枪托",
        top_rail = "上导轨",
        bottom_rail = "下导轨",
        left_rail = "左导轨",
        right_rail = "右导轨",
        optic_mount = "瞄具挂点"
    },

    -- 平台默认配件。未声明 weapon.defaults 的武器会从这里初始化。
    -- defaults 只表示初始装配模板；安装/替换时仍按实体 item 消耗和返还。
    defaults = {
        receiver = "AR_receiver_std",
        barrel = "AR_barrel_145",
        handguard = "AR_handguard_std",
        pistol_grip = "AR_grip_std",
        stock = "AR_stock_std"
    }
}
