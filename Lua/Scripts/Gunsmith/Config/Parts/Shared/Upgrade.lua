local parts = GunsmithFramework.Config.parts
local UpgradeTexture = Deep_Lua.Path .. "/GunSmith/SharedParts/Upgrade/Upgrade.png"

-- 通用下挂。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.deep_upgrade_rifle_tit = {
    type = "upgrade_rifle",
    nameKey = "deep.gunsmith.part.deep_upgrade_rifle_tit",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "sub_hanging_shotgun" },
    item = { identifier = "deep_upgrade_rifle_tit" },
    stats = { Ergonomics = -1, MovementSpeed = -0.20, WeaponsSkillBonus = -20 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 4, y = 10, w = 337, h = 174 },
        attachPoint = { x = 73, y = 5 },
        order = 70,
        scale = 0
    },
}


