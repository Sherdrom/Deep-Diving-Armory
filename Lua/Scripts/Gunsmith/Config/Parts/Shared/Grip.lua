Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local gripTexture = Deep_Lua.Path .. "/weapon/sight/grip.png"

-- 通用握把。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.deep_vertical_grip = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_vertical_grip",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "vertical_grip" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 27, y = 13, w = 64, h = 123 },
        attachPoint = { x = 32, y = 3 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_vertical_grips_short = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_vertical_grips_short",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "vertical_grips_short" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 126, y = 15, w = 59, h = 99 },
        attachPoint = { x = 26, y = 3 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_vertical_grips_hollow_out = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_vertical_grips_hollow_out",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "vertical_grips_hollow_out" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 225, y = 13, w = 54, h = 119 },
        attachPoint = { x = 27, y = 6 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_cqr_grips = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_cqr_grips",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "cqr_grips" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 37, y = 176, w = 200, h = 122 },
        attachPoint = { x = 100, y = 4 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_oblique_grips = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_oblique_grips",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "oblique_grips" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 309, y = 11, w = 66, h = 115 },
        attachPoint = { x = 33, y = 4 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_corner_grip = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_corner_grip",
    -- small_grip / medium_grip 由护木的 optic_mount.accepts 决定。
    provides = { "small_grip" },
    item = { identifier = "corner_grip" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = gripTexture,
        source = { x = 260, y = 180, w = 234, h = 89 },
        attachPoint = { x = 90, y = 4 },
        order = 70,
        scale = 0.5
    }
}


