Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local config = Deep_Lua.Gunsmith.Config
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

config.weapons.deep_hk416 = {
    platform = "AR",

    -- 具体武器只声明根身份件；子默认件由 receiver.mounts[].defaultPart 展开。
    rootParts = {
        receiver = "hk416_receiver_std"
    },

    rootSockets = {
        receiver = { x = 184, y = 158 }
    },

    -- 选填，可注释。UI 预览窗口微调，只影响 GunSmith 窗口里的预览，不影响背包/世界贴图。
    preview = {
        padding = 0,
        scale = 1.0,
        offset = { x = 0, y = 0 }
    },

    inventory = {
        scale = 0.35,   -- 库存图标缩放。
        rotation = 45,  -- 库存图标旋转角度，单位是度，正数为顺时针。
        padding = 6     -- 物品栏图标内边距，单位像素。旋转后边缘留白，避免裁切。
    },

    -- 只影响手持/掉落世界图。offset 是烘焙贴图内的视觉偏移，不移动物品物理位置。
    world = {
        scale = 1.0,
        rotation = 0.0,
        padding = 0,
        offset = { x = 0, y = 0 }
    }
}

parts.hk416_receiver_std = {
    type = "receiver",
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
        { path = "barrel", name = "枪管", accepts = { "AR_barrel" }, defaultPart = "hk416_barrel_std", anchor = { x = 250-184, y = 55-58 } },
        { path = "handguard", name = "护木", accepts = { "AR_handguard" }, defaultPart = "hk416_handguard_std", anchor = { x = 250-184, y = 55-58 } },
        { path = "pistol_grip", name = "手枪握把", accepts = { "AR_pistol_grip" }, defaultPart = "hk416_grip_std", anchor = { x = 166-184, y = 88-58 } },
        { path = "stock", name = "枪托", accepts = { "AR_stock" }, defaultPart = "hk416_stock_std", anchor = { x = 114-184, y = 59-58 } },
        { path = "optic_mount", name = "机匣瞄具挂点", accepts = { "small_optic", "medium_optic" }, anchor = { x = 226-184, y = 35-58 } }
        -- 例子：receiver_top_rail 是个 virtual part，不提供 item，也不占用实际挂点；它的 mounts 定义了前/后瞄具挂点。
        -- { path = "receiver_top_rail", name = "顶部导轨", accepts = { "AR_top_rail" }, defaultPart = "AR_receiver_top_rail", anchor = { x = 12, y = -23 } },
    }
}
