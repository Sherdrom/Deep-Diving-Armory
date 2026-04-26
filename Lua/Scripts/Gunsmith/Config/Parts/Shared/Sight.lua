Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local sightTexture = Deep_Lua.Path .. "/weapon/sight/sight.png"

-- 通用瞄具。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.AR_red_dot = {
    type = "optic_mount",
    name = "全息瞄具",
    -- small_optic / medium_optic 由导轨或机匣的 optic_mount.accepts 决定。
    provides = { "small_optic" },
    item = { identifier = "holographic_sight" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = sightTexture,
        source = { x = 15, y = 7, w = 73, h = 59 },
        attachPoint = { x = 48-15, y = 58-7 },
        order = 20,
        scale = 0.5
    }
}

parts.AR_holo_sight = {
    type = "optic_mount",
    name = "红点瞄具",
    provides = { "small_optic" },
    item = { identifier = "red_sight" },
    stats = { weight = 0.25, ergonomics = -2, spreadReduction = 0.04 },
    visual = {
        texture = sightTexture,
        source = { x = 101, y = 9, w = 71, h = 55 },
        attachPoint = { x = 138-101, y = 58-9 },
        order = 20,
        scale = 0.5
    }
}
