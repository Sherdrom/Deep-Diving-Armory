local parts = GunsmithFramework.Config.parts
local weapons = GunsmithFramework.Config.weapons

local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

-- 武器条目把 Barotrauma 物品 identifier 接入 GunSmith。
-- key 必须等于 XML 里的 Item identifier，例如 weapon/rifle/.../m4.xml 中的 deep_m4。
weapons.deep_m4 = { 
    -- 绑定到 Config/Platforms/AR.lua 中定义的平台 key。
    platform = "AR",

    -- 根身份件、视觉接口点和可选 itempos 原点。
    -- 子默认件由 receiver.mounts[].defaultPart 展开。
    roots = {
        receiver = {
            part = "M4_receiver_std",
            socket = { x = 209, y = 160 }
        }
    },

    -- 选填，可注释。UI 预览窗口微调，只影响 GunSmith 窗口里的预览，不影响背包/世界贴图。
    preview = {
        padding = 0,
        scale = 1.0,
        offset = { x = 0, y = 0 }
    },

    -- 只影响物品栏图标。rotation 单位为度，正数为顺时针。
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

-- 枪械主题机匣的 part 挪到这里，和平台、武器配置放在一起，方便对照。
parts.M4_receiver_std = { 
    -- type 是配件自身类型，必须匹配平台根路径或父挂点的 partType。
    type = "receiver",
    nameKey = "deep.gunsmith.part.M4_receiver_std",

    -- provides 是兼容类型。根身份件由 weapon.roots 指定；子配件由挂点 accepts 接受。
    provides = { "M4_receiver" },

    -- 实体配件 item。可安装配件应有 item.identifier；virtual 配件可不消耗物品。
    item = { identifier = "deep_gunsmith_M4_receiver_std" },

    -- 目前只用于 UI 展示，不直接影响武器实际数值。
    stats = { Ergonomics = 0 },

    -- visual 是运行时合成图层。根部件用自己的 attachPoint 对齐当前武器 roots[path].socket。
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
        { path = "barrel", accepts = { "AR_barrel" }, defaultPart = "AR_barrel_145", anchor = { x = 62, y = -3 } },
        { path = "handguard", accepts = { "AR_handguard" }, defaultPart = "AR_handguard_std", anchor = { x = 62, y = -3 } },
        { path = "pistol_grip", accepts = { "AR_pistol_grip" }, defaultPart = "AR_grip_std", anchor = { x = -26, y = 27 } },
        { path = "stock", accepts = { "AR_stock" }, defaultPart = "AR_stock_std", anchor = { x = -68, y = 0 } },
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.M4_receiver_std.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 8, y = -41 } }
    }
}
