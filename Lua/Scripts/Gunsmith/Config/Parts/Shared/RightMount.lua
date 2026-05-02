Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local sightTexture = Deep_Lua.Path .. "/weapon/sight/accessory.png"
local laserTexture = Deep_Lua.Path .. "/weapon/sight/accessory_new.png"

-- 通用右挂。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.focusingflashlight = {
    type = "Right_rail_mount",
    nameKey = "deep.gunsmith.part.focusingflashlight",
    -- right_rail_mount 由护木的 optic_mount.accepts 决定。
    provides = { "right_rail_mount" },
    item = { identifier = "focusingflashlight" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = sightTexture,
        source = { x = 451, y = 340, w = 188, h = 51 },
        attachPoint = { x = 94, y = 25 },
        order = 70,
        scale = 0.5
    }
}

parts.spreadflashlight = {
    type = "Right_rail_mount",
    nameKey = "deep.gunsmith.part.spreadflashlight",
    -- right_rail_mount 由护木的 optic_mount.accepts 决定。
    provides = { "right_rail_mount" },
    item = { identifier = "spreadflashlight" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = sightTexture,
        source = { x = 451, y = 422, w = 162, h = 81 },
        attachPoint = { x = 80, y = 42 },
        order = 70,
        scale = 0.45
    }
}

parts.deep_laser = {
    type = "Right_rail_mount",
    nameKey = "deep.gunsmith.part.deep_laser",
    -- right_rail_mount 由护木的 optic_mount.accepts 决定。
    provides = { "right_rail_mount" },
    item = { identifier = "deep_laser" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = laserTexture,
        source = { x = 21, y = 9, w = 976, h = 93 },
        attachPoint = { x = 68, y = 47 },
        order = 70,
        scale = 0.45
    }
}




