Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local config = Deep_Lua.Gunsmith.Config

local texture = Deep_Lua.Path .. "/GunSmith/AK/Main/AK74.png"

-- 武器条目把 Barotrauma 物品 identifier 接入 GunSmith。
-- key 必须等于 XML 里的 Item identifier，例如 weapon/rifle/.../m4.xml 中的 deep_m4。
config.weapons.deep_AK74 = { 
    -- 绑定到 Config/Platforms/AK.lua 中定义的平台 key。
    platform = "AK",

    -- 根身份件、视觉接口点和可选 itempos 原点。
    -- 子默认件由 receiver.mounts[].defaultPart 展开。
    roots = {
        receiver = {
            part = "deep_ak74_receiver",
            socket = { x = 226, y = 116 }
        }
    },

    -- QuickMod slot numbers are weapon XML ItemContainer targetslot indices.
    -- 可选参数itemPosOffset，可以微调槽位实际itemPos，达到调整特效位置的目的，例如激光、手电等。
    quickSlotBindings = {
        -- lower_rail = { slot = 1 },
        -- right_rail = { slot = 2 },
        -- left_rail = { slot = 3 },
        optic = { slot = 4 },
        -- muzzle = { slot = 5 }
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
        offset = { x = 40, y = -5 }
    }
}

-- 枪械主题机匣的 part 挪到这里，和平台、武器配置放在一起，方便对照。
parts.deep_ak74_receiver = { 
    -- type 是配件自身类型，必须匹配平台根路径或父挂点的 partType。
    type = "receiver",
    nameKey = "deep.gunsmith.part.deep_ak74_receiver",

    -- provides 是兼容类型。根身份件由 weapon.roots 指定；子配件由挂点 accepts 接受。
    provides = { "deep_ak74_receiver" },

    -- 实体配件 item。可安装配件应有 item.identifier；virtual 配件可不消耗物品。
    item = { identifier = "deep_ak74_receiver" },

    -- 目前只用于 UI 展示，不直接影响武器实际数值。
    stats = { Ergonomics = 0 },

    -- visual 是运行时合成图层。根部件用自己的 attachPoint 对齐当前武器 roots[path].socket。
    -- attachPoint 是配件 source 内部的本地连接点。
    -- 子配件同理：父配件 mounts.anchor 是父配件本地挂点，子配件 attachPoint 会对齐到该挂点。
    -- order 越小越早绘制，scale 是单个配件缩放。
    visual = {
        texture = texture,
        source = { x = 92, y = 92, w = 344, h = 71 },
        attachPoint = { x = 56, y = 37 },
        order = 10,
        scale = 1
    },

    -- V0.9: receiver 是 AR 的结构核心。anchor 相对 receiver.visual.attachPoint。
    mounts = {
        { path = "dust_cover", accepts = { "AK_dust_cover" }, defaultPart = "deep_6p1_01_ak_dustcover", anchor = { x = 34, y = -22 } },
        { path = "handguard", accepts = { "AK_handguard" }, defaultPart = "deep_6p20_sb6_ak_handguard", anchor = { x = 109, y = -13 } },
        { path = "pistol_grip", accepts = { "AK_pistol_grip" }, defaultPart = "deep_6p4_sb9_ak_pistol_grip", anchor = { x = -17, y = 13 } },
        { path = "stock", accepts = { "AK_stock" }, defaultPart = "deep_6p20_sb5_ak_stock", anchor = { x = -53, y = 1 } }
    }
}
