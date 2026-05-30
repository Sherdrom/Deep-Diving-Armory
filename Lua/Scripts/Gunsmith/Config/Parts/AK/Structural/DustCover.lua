Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AK/DustCover/SharedDustCoverAK.png"

parts.deep_6p1_01_ak_dustcover = {
    type = "dust_cover",
    nameKey = "deep.gunsmith.part.deep_6p1_01_ak_dustcover",
    provides = { "AK_dust_cover" },
    item = { identifier = "deep_6p1_01_ak_dustcover" },
    stats = { Ergonomics = 2 },
    visual = {
        texture = texture,
        source = { x = 14, y = 9, w = 129, h = 21 },
        attachPoint = { x = 90, y = 8 },
        order = 30,
        scale = 1
    }
}

parts.deep_pdc_ak_dustcover = {
    type = "dust_cover",
    nameKey = "deep.gunsmith.part.deep_pdc_ak_dustcover",
    provides = { "AK_dust_cover" },
    item = { identifier = "deep_pdc_ak_dustcover" },
    stats = { Ergonomics = 2 },
    visual = {
        texture = texture,
        source = { x = 11, y = 37, w = 132, h = 23 },
        attachPoint = { x = 93, y = 10 },
        order = 30,
        scale = 1
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.deep_pdc_ak_dustcover.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = -25, y = -10 }, quick = { key = "optic" } },
    }
}
