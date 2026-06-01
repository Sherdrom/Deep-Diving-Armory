Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local config = Deep_Lua.Gunsmith.Config

-- 平台 = 一类枪械共用的改装骨架。
-- deep_m4 和 deep_hk416 都挂在 AR 平台上，因此它们共用 receiver-led 结构、兼容规则和槽位显示名。
config.platforms.AR = {
    id = "AR",

    -- 运行时合成贴图的画布尺寸。
    -- 根槽 roots[].socket 使用这个平台 canvas 坐标系。
    -- 子配件可以用 visual.attachPoint 对齐父配件本地 mount.anchor。
    canvas = { w = 640, h = 260 },

    -- 平台根路径。V0.9.2 起平台只描述结构规则，不再声明默认枪型。
    -- receiver 是武器身份件，隐藏在普通改装列表外；其子路径会提升到 UI 首页。
    rootSlots = { { path = "receiver", hidden = true } },

    -- 相对平台本体 receiver 的必填配件列表。
    -- 不在这里的挂点都是可选项，例如 optic_mount、top_rail。
    requiredSlots = { 
        "barrel",
        "upper_receiver",
        "buffer_tube",
        "gas_block",
    },

    -- UI 显示文本只写本地化 key，实际文本放在 text/chinese.xml 等语言文件。
    -- 子挂点 path 也建议登记在这里，方便路径显示为“枪械 > 护木 > 上导轨”。
    pathNameKeys = {
        receiver = "deep.gunsmith.path.receiver",
        upper_receiver = "deep.gunsmith.path.upper_receiver",
        buffer_tube = "deep.gunsmith.path.buffer_tube",
        barrel = "deep.gunsmith.path.barrel",
        gas_block = "deep.gunsmith.path.gas_block",
        handguard = "deep.gunsmith.path.handguard",
        pistol_grip = "deep.gunsmith.path.pistol_grip",
        stock = "deep.gunsmith.path.stock",
        muzzle_device = "deep.gunsmith.path.muzzle_device",
        top_rail = "deep.gunsmith.path.top_rail",
        bottom_rail = "deep.gunsmith.path.bottom_rail",
        left_rail = "deep.gunsmith.path.left_rail",
        right_rail = "deep.gunsmith.path.right_rail",
        receiver_top_rail = "deep.gunsmith.path.receiver_top_rail",
        optic_mount = "deep.gunsmith.path.optic_mount"
    }
}
