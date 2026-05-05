Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts
local railTexture = Deep_Lua.Path .. "/weapon/part/part.png"

-- 通用导轨附件。这里的配件通常不是根槽默认件，而是由护木等父配件的 mounts 暴露出来。
local function opticMount(anchor)
    return { -- 导轨内部的瞄具挂点。anchor 是导轨 source 内部的本地坐标。
        { path = "optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = anchor }
    }
end

parts.AR_rail_short = { -- top_rail 是护木 mounts 提供的子路径，不是平台根路径。
    type = "top_rail",
    nameKey = "deep.gunsmith.part.AR_rail_short",

    -- 提供 picatinny_rail，因此可以安装到 accepts = { "picatinny_rail" } 的挂点。
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_rail_short" },
    stats = { Ergonomics = -1 },
    visual = { texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        -- attachPoint 是导轨自身的本地连接点，会对齐到父护木的本地 mount.anchor。
        attachPoint = { x = 0, y = 0 },
        order = 60,
        scale = 0.22
    },

    -- 导轨安装后继续提供 optic_mount，UI 才会显示“进入该配件挂点”。
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_rail_long = { type = "top_rail",
    nameKey = "deep.gunsmith.part.AR_rail_long",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_rail_long" },
    stats = { Ergonomics = -2 },
    visual = { texture = railTexture,
        source = { x = 631, y = 166, w = 106, h = 112 },
        attachPoint = { x = 0, y = 0 },
        order = 60,
        scale = 0.24
    },
    mounts = opticMount({ x = 14, y = -14 })
}

parts.AR_left_rail = { type = "left_rail",
    nameKey = "deep.gunsmith.part.AR_left_rail",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_left_rail" },
    stats = { Ergonomics = -1 },
    visual = { texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        attachPoint = { x = 0, y = 0 },
        order = 55,
        scale = 0.18
    },
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_right_rail = { type = "right_rail",
    nameKey = "deep.gunsmith.part.AR_right_rail",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_right_rail" },
    stats = { Ergonomics = -1 },
    visual = { texture = railTexture,
        source = { x = 635, y = 44, w = 100, h = 108 },
        attachPoint = { x = 0, y = 0 },
        order = 65,
        scale = 0.18
    },
    mounts = opticMount({ x = 12, y = -14 })
}

parts.AR_bottom_rail = { type = "bottom_rail",
    nameKey = "deep.gunsmith.part.AR_bottom_rail",
    provides = { "picatinny_rail" },
    item = { identifier = "deep_gunsmith_AR_bottom_rail" },
    stats = { Ergonomics = -1 },
    visual = { texture = railTexture,
        source = { x = 631, y = 166, w = 106, h = 112 },
        attachPoint = { x = 0, y = 0 },
        order = 65,
        scale = 0.20
    },
    mounts = opticMount({ x = 14, y = -14 })
}
