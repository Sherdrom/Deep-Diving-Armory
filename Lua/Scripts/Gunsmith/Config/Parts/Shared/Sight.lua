Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local sightTexture = Deep_Lua.Path .. "/weapon/sight/sight.png"

-- 通用瞄具。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.AR_red_dot = {
    slot = "optic_mount",
    name = "红点瞄准镜",

    -- small_optic / medium_optic 由导轨或机匣的 optic_mount.accepts 决定。
    provides = { "small_optic" },
    item = { identifier = "deep_gunsmith_AR_red_dot" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = sightTexture,
        source = { x = 15, y = 7, w = 73, h = 59 },
        attachPoint = { x = 0, y = 0 },
        order = 80,
        scale = 0.36
    }
}

parts.AR_holo_sight = {
    slot = "optic_mount",
    name = "全息瞄准镜",
    provides = { "medium_optic" },
    item = { identifier = "deep_gunsmith_AR_holo_sight" },
    stats = { weight = 0.25, ergonomics = -2, spreadReduction = 0.04 },
    visual = {
        texture = sightTexture,
        source = { x = 108, y = 5, w = 87, h = 66 },
        attachPoint = { x = 2, y = 2 },
        order = 80,
        scale = 0.34
    }
}
