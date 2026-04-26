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
    },

    -- HK416 暂只提供主结构接口；anchor 相对 receiver.visual.attachPoint。184,58
    -- receiver 顶部瞄具挂点留给后续版本细调。
    mounts = {
        { slot = "barrel", name = "枪管", accepts = { "AR_barrel" }, anchor = { x = 250-184, y = 55-58 } },
        { slot = "handguard", name = "护木", accepts = { "AR_handguard" }, anchor = { x = 250-184, y = 55-58 } },
        { slot = "pistol_grip", name = "手枪握把", accepts = { "AR_pistol_grip" }, anchor = { x = 166-184, y = 88-58 } },
        { slot = "stock", name = "枪托", accepts = { "AR_stock" }, anchor = { x = 114-184, y = 59-58 } }
    }
}
