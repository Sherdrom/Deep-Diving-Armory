local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AK/HandGuard/SharedHandGuardAK.png"

parts.deep_6p20_sb6_ak_handguard = {
    type = "handguard",
    nameKey = "deep.gunsmith.part.deep_6p20_sb6_ak_handguard",
    provides = { "AK_handguard" },
    item = { identifier = "deep_6p20_sb6_ak_handguard" },
    stats = { Ergonomics = 4 },
    visual = {
        texture = texture,
        source = { x = 4, y = 5, w = 90, h = 42 },
        attachPoint = { x = 27, y = 8 },
        order = 30,
        scale = 1
    }
}