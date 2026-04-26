Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

-- HK416 独有外观件。
-- 机匣 provides HK416_receiver，并由 Weapons/AR.lua 里的 deep_hk416.rootAccepts 限定为 HK416 专用。
-- 枪管、护木、握把、枪托等仍可继续使用 AR_* 兼容类型，作为平台共享件或武器专属视觉件。
parts.hk416_receiver_std = {
    slot = "receiver",
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
    }
}
