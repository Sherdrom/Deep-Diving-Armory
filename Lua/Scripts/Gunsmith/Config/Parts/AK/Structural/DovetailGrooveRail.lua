local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AK/DovetailGrooveRail/SharedDovetailGrooveRailAK.png"

parts.deep_b13v_dovetail_groove_rail = {
    type = "dovetail_groove",
    nameKey = "deep.gunsmith.part.deep_b13v_dovetail_groove_rail",
    provides = { "AK_dovetail_groove_rail" },
    item = { identifier = "deep_b13v_dovetail_groove_rail" },
    stats = { Ergonomics = 2 },
    visual = {
        texture = texture,
        source = { x = 9, y = 11, w = 87, h = 44 },
        attachPoint = { x = 43, y = 38 },
        order = 25,
        scale = 1
    },
    mounts = {
        { path = "optic_mount", nameKey = "deep.gunsmith.mount.deep_dovetail_groove_rail.optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = -7, y = -38 }, quick = { key = "optic" } },
    }
}
