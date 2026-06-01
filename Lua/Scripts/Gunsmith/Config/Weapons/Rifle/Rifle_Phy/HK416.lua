Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local config = Deep_Lua.Gunsmith.Config
local texture = Deep_Lua.Path .. "/GunSmith/AR/Main/HK416.png"

config.weapons.deep_hk416 = {

    platform = "AR",

    roots = {
        receiver = {
            part = "deep_hk416_receiver_main",
            socket = { x = 247, y = 130 }
        }
    },

    -- QuickMod slot numbers are weapon XML ItemContainer targetslot indices.
    -- 可选参数itemPosOffset，可以微调槽位实际itemPos，达到调整特效位置的目的，例如激光、手电等。
    quickSlotBindings = {
        lower_rail = { slot = 1 },
        right_rail = { slot = 2 },
        left_rail = { slot = 3 },
        optic = { slot = 4 },
        muzzle = { slot = 5 }
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
        offset = { x = 20, y = -7 }
    }
}

parts.deep_hk416_receiver_main = {
    type = "receiver",
    nameKey = "deep.gunsmith.part.deep_hk416_receiver_main",
    provides = { "HK416_receiver" },
    item = { identifier = "deep_hk416_receiver_main" },
    stats = { Ergonomics = 200 },
    visual = {
        texture = texture,
        source = { x = 63, y = 28, w = 129, h = 72 },
        attachPoint = { x = 65, y = 36 },
        order = 30,
        scale = 1.0
    },

    -- HK416 机匣顶部自带导轨。这里挂一个 virtual part，用它继续提供前/后瞄具挂点。
    -- anchor 相对 receiver.visual.attachPoint。
    mounts = {
        { path = "upper_receiver", accepts = { "AR_upper_receiver" }, defaultPart = "deep_hk416a5_upper_receiver", anchor = { x = 13, y = -24 } },
        { path = "pistol_grip", accepts = { "AR_pistol_grip" }, defaultPart = "deep_miad_pistol_grip", anchor = { x = -26, y = 12 } },
        { path = "buffer_tube", accepts = { "AR_buffer_tube" }, defaultPart = "deep_hket_buffer_tube", anchor = { x = -60, y = -20 } }
        -- 例子：receiver_top_rail 是个 virtual part，不提供 item，也不占用实际挂点；它的 mounts 定义了前/后瞄具挂点。
        -- { path = "receiver_top_rail", nameKey = "deep.gunsmith.path.receiver_top_rail", accepts = { "AR_top_rail" }, defaultPart = "AR_receiver_top_rail", anchor = { x = 12, y = -23 } },
    }
}
