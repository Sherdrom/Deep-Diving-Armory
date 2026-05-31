Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/UpperReceiver/HK416.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_hk416a5_upper_receiver = {
    type = "upperreceiver",
    nameKey = "deep.gunsmith.part.deep_hk416a5_upper_receiver",
    provides = { "AR_upperreceiver" },
    item = { identifier = "deep_hk416a5_upper_receiver" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 5, y = 6, w = 161, h = 43 },
        attachPoint = { x = 60, y = 24 },
        order = 35,
        scale = 1.0
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.upper_receiver.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 14, y = -22 }, quick = { key = "optic" } },
    }
}
