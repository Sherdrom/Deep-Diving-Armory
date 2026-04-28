Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local config = Deep_Lua.Gunsmith.Config

-- 平台 = 一类枪械共用的改装骨架。
-- deep_m4 和 deep_hk416 都挂在 AR 平台上，因此它们共用 receiver-led 结构、兼容规则和槽位显示名。
config.platforms.AR = {
    id = "AR",

    -- 运行时合成贴图的画布尺寸。
    -- 根槽 rootSockets 使用这个平台 canvas 坐标系。
    -- 子配件可以用 visual.attachPoint 对齐父配件本地 mount.anchor。
    canvas = { w = 512, h = 260 },

    -- 平台级合成基础缩放。单配件图层缩放写在 part.visual.scale。
    visualScale = 1.0,

    -- 平台缩放的中心点。通常放在画布中心，除非整个平台图层需要偏心缩放。
    visualOrigin = { x = 256, y = 130 },

    -- 平台根路径。V0.9.2 起平台只描述结构规则，不再声明默认枪型。
    -- receiver 是武器身份件，隐藏在普通改装列表外；其子路径会提升到 UI 首页。
    rootSlots = {
        { path = "receiver", hidden = true }
    },

    -- 相对平台本体 receiver 的必填配件列表。
    -- 不在这里的挂点都是可选项，例如 optic_mount、top_rail。
    requiredSlots = {
        "barrel",
        "handguard",
        "pistol_grip",
        "stock"
    },

    -- UI 显示名。没有写在这里的 path 会直接显示内部 key。
    -- 子挂点 path 也建议登记在这里，方便路径显示为“枪械 > 护木 > 上导轨”。
    pathNames = {
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
        receiver_top_rail = "机匣顶部导轨",
        optic_mount = "瞄具挂点"
    }
}
