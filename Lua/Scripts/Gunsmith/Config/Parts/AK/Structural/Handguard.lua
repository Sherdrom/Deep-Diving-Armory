Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

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
        source = { x = 17, y = 10, w = 92, h = 46 },
        attachPoint = { x = 28, y = 19 },
        order = 30,
        scale = 1
    }
}