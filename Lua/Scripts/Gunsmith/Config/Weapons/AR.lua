Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local config = Deep_Lua.Gunsmith.Config

-- 武器条目把 Barotrauma 物品 identifier 接入 GunSmith。
-- key 必须等于 XML 里的 Item identifier，例如 weapon/rifle/.../m4.xml 中的 deep_m4。
config.weapons.deep_m4 = {
    -- 绑定到 Config/Platforms/AR.lua 中定义的平台 key。
    platform = "AR",

    defaults = {
        receiver = "M4_receiver_std",
        barrel = "AR_barrel_145",
        handguard = "AR_handguard_std",
        pistol_grip = "AR_grip_std",
        stock = "AR_stock_std"
    },

    -- 武器级根槽兼容覆盖。机匣是武器独有件，所以 M4 只接受 M4_receiver。
    rootAccepts = {
        receiver = { "M4_receiver" }
    },

    -- 根槽接口点。根部件会用 visual.attachPoint 对齐 rootSockets[slot]。
    rootSockets = {
        receiver = { x = 209, y = 60 },
        barrel = { x = 271, y = 57 },
        handguard = { x = 271, y = 57 },
        pistol_grip = { x = 183, y = 87 },
        stock = { x = 141, y = 60 }
    },

    -- 武器级整体视觉缩放，会和 platform.visualScale、part.visual.scale 相乘。
    scale = 1,

    -- UI 预览窗口微调，只影响 GunSmith 窗口里的预览，不影响世界/背包贴图。
    preview = {
        padding = 12,
        zoom = 1.0,
        offset = { x = 0, y = 0 }
    }
}

config.weapons.deep_hk416 = {
    platform = "AR",

    -- 可选：覆盖平台初始装配模板。
    -- HK416 和 M4 共用 AR 平台规则，但初始外观使用自己的独有部件。
    defaults = {
        receiver = "hk416_receiver_std",
        barrel = "hk416_barrel_std",
        handguard = "hk416_handguard_std",
        pistol_grip = "hk416_grip_std",
        stock = "hk416_stock_std"
    },

    -- HK416 只接受自己的机匣；其他根槽继续沿用 AR 平台通用 accepts。
    rootAccepts = {
        receiver = { "HK416_receiver" }
    },

    rootSockets = {
        receiver = { x = 184, y = 58 },
        barrel = { x = 250, y = 57 },
        handguard = { x = 250, y = 55 },
        pistol_grip = { x = 166, y = 88 },
        stock = { x = 114, y = 59 }
    },
    
    scale = 1,
    
    preview = {
        padding = 10,
        zoom = 1.0,
        offset = { x = 0, y = 0 }
    }
}
