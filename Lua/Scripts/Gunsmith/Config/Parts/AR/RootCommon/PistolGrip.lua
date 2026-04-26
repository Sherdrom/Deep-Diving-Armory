Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

local texture = Deep_Lua.Path .. "/weapon/gunsmith/gunsmith_test_rifle.png"

parts.AR_grip_std = {
    slot = "pistol_grip",
    name = "M4标准握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_AR_grip_std" },
    stats = { weight = 0.12, ergonomics = 3, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 256, y = 585, w = 57, h = 63 },
        attachPoint = { x = 54, y = 2 },
        order = 50,
        scale = 1.0
    }
}

parts.hk416_grip_std = {
    slot = "pistol_grip",
    name = "HK416 标准握把",
    provides = { "AR_pistol_grip" },
    item = { identifier = "deep_gunsmith_hk416_grip_std" },
    stats = { weight = 0.14, ergonomics = 4, recoilControl = 0.02 },
    visual = {
        texture = texture,
        source = { x = 15, y = 585, w = 55, h = 65 },
        attachPoint = { x = 53, y = 1 },
        order = 50,
        scale = 1.0
    }
}