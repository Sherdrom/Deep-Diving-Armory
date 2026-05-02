Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local subhangingTexture = Deep_Lua.Path .. "/weapon/sight/sub_hanging.png"

-- 通用下挂。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.deep_sub_hanging_master_key = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_sub_hanging_master_key",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "sub_hanging_shotgun" },
    item = { identifier = "deep_sub_hanging_master_key" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = subhangingTexture,
        source = { x = 4, y = 10, w = 337, h = 174 },
        attachPoint = { x = 73, y = 5 },
        order = 70,
        scale = 0.5
    }
}

parts.deep_sub_hanging_m203 = {
    type = "Lower_rail_mount",
    nameKey = "deep.gunsmith.part.deep_sub_hanging_m203",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "AR_sub_hanging_gl" },
    item = { identifier = "deep_sub_hanging_m203" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = subhangingTexture,
        source = { x = 3, y = 356, w = 399, h = 98 },
        attachPoint = { x = 123, y = 8 },
        order = 70,
        scale = 0.5
    }
}


