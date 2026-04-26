Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local railTexture = Deep_Lua.Path .. "/weapon/part/part.png"

-- 通用导轨附件。这里的配件通常不是根槽默认件，而是由护木等父配件的 mounts 暴露出来。
local function opticMount(anchor)
    return {
        -- 导轨内部的瞄具挂点。anchor 是导轨 source 内部的本地坐标。
        { slot = "optic_mount", name = "瞄具挂点", accepts = { "small_optic", "medium_optic" }, anchor = anchor }
    }
end

parts.AR_rail_short = {
    -- top_rail 是护木 mounts 提供的子槽，不是平台根槽。
    slot = "top_rail",
    name = "短皮卡汀尼导轨",

    -- 提供 picatinny_rail，因此可以安装到 accepts = { "picatinny_rail" } 的挂点。
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_rail_short" },
    stats = { weight = 0.08, ergonomics = -1 },
    visual = {
        texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        -- attachPoint 是导轨自身的本地连接点，会对齐到父护木的本地 mount.anchor。
        attachPoint = { x = 0, y = 0 },
        order = 60,
        scale = 0.22
    },

    -- 导轨安装后继续提供 optic_mount，UI 才会显示“进入该配件挂点”。
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_rail_long = {
    slot = "top_rail",
    name = "长皮卡汀尼导轨",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_rail_long" },
    stats = { weight = 0.14, ergonomics = -2 },
    visual = {
        texture = railTexture,
        source = { x = 631, y = 166, w = 106, h = 112 },
        attachPoint = { x = 0, y = 0 },
        order = 60,
        scale = 0.24
    },
    mounts = opticMount({ x = 14, y = -14 })
}

parts.AR_side_rail = {
    slot = "left_rail",
    name = "侧面导轨",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_side_rail" },
    stats = { weight = 0.08, ergonomics = -1 },
    visual = {
        texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        attachPoint = { x = 0, y = 0 },
        order = 55,
        scale = 0.18
    },
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_right_rail = {
    slot = "right_rail",
    name = "右侧导轨",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_right_rail" },
    stats = { weight = 0.08, ergonomics = -1 },
    visual = {
        texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        attachPoint = { x = 0, y = 0 },
        order = 65,
        scale = 0.18
    },
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_bottom_rail = {
    slot = "bottom_rail",
    name = "下方导轨",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_bottom_rail" },
    stats = { weight = 0.1, ergonomics = -1, recoilControl = 0.01 },
    visual = {
        texture = railTexture,
        source = { x = 631, y = 166, w = 106, h = 112 },
        attachPoint = { x = 0, y = 0 },
        order = 65,
        scale = 0.20
    },
    mounts = opticMount({ x = 14, y = -14 })
}
