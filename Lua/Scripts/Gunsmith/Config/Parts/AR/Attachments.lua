Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local railTexture = Deep_Lua.Path .. "/weapon/part/part.png"
local sightTexture = Deep_Lua.Path .. "/weapon/sight/sight.png"

-- AR 平台挂载件和通用附件。
-- 这里的配件通常不是根槽默认件，而是由护木、导轨等父配件的 mounts 暴露出来。
local function opticMount(anchor)
    return {
        -- 导轨内部的瞄具挂点。anchor 以该导轨的参考 offset 为基准；
        -- 当导轨通过父挂点移动到不同武器或不同护木位置时，Runtime 会把这个 anchor 一起平移。
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
        -- offset 是该共享件在 AR 参考画布中的基准位置；实际安装到子槽时优先使用 relativeOffset。
        offset = { x = 276, y = 58 },
        relativeOffset = { x = 0, y = 0 },
        order = 60,
        scale = 0.22
    },

    -- 导轨安装后继续提供 optic_mount，UI 才会显示“进入该配件挂点”。
    mounts = opticMount({ x = 288, y = 44 })
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
        offset = { x = 276, y = 56 },
        relativeOffset = { x = 0, y = 0 },
        order = 60,
        scale = 0.24
    },
    mounts = opticMount({ x = 290, y = 42 })
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
        offset = { x = 274, y = 82 },
        relativeOffset = { x = 0, y = 0 },
        order = 55,
        scale = 0.18
    },
    mounts = opticMount({ x = 286, y = 68 })
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
        offset = { x = 304, y = 82 },
        relativeOffset = { x = 0, y = 0 },
        order = 65,
        scale = 0.18
    },
    mounts = opticMount({ x = 316, y = 68 })
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
        offset = { x = 286, y = 104 },
        relativeOffset = { x = 0, y = 0 },
        order = 65,
        scale = 0.20
    },
    mounts = opticMount({ x = 300, y = 90 })
}

parts.AR_red_dot = {
    slot = "optic_mount",
    name = "红点瞄准镜",

    -- small_optic / medium_optic 由导轨的 optic_mount.accepts 决定。
    provides = { "small_optic" },
    item = { identifier = "deep_gunsmith_AR_red_dot" },
    stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 },
    visual = {
        texture = sightTexture,
        source = { x = 15, y = 7, w = 73, h = 59 },
        relativeOffset = { x = 0, y = 0 },
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
        relativeOffset = { x = -2, y = -2 },
        order = 80,
        scale = 0.34
    }
}
