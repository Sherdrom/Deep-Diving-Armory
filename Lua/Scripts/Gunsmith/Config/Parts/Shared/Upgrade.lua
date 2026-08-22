local parts = GunsmithFramework.Config.parts
local UpgradeTexture = Deep_Lua.Path .. "/GunSmith/SharedParts/Upgrade/Upgrade.png"

parts.deep_upgrade_rifle_tit = {
    type = "upgrade_rifle",
    nameKey = "deep.gunsmith.part.deep_upgrade_rifle_tit",
    provides = { "AR_upgrade_rifle" },
    item = { identifier = "deep_upgrade_rifle_tit" },
    stats = { Ergonomics = 30, RangedAttackMultiplier = 0.3, RangedSpreadReduction = 0.3 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 0, y = 0, w = 0, h = 0 },
        attachPoint = { x = 0, y = 0 },
        order = 0,
        scale = 0.01
    },
}

parts.deep_upgrade_rifle_phy = {
    type = "upgrade_rifle",
    nameKey = "deep.gunsmith.part.deep_upgrade_rifle_phy",
    provides = { "AR_upgrade_rifle" },
    item = { identifier = "deep_upgrade_rifle_phy" },
    stats = { Ergonomics = 40, RangedAttackMultiplier = 0.45, RangedSpreadReduction = 0.5 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 0, y = 0, w = 0, h = 0 },
        attachPoint = { x = 0, y = 0 },
        order = 0,
        scale = 0.01
    },
}

parts.deep_upgrade_rifle_tun_phy = {
    type = "upgrade_rifle",
    nameKey = "deep.gunsmith.part.deep_upgrade_rifle_tun_phy",
    provides = { "AR_upgrade_rifle" },
    item = { identifier = "deep_upgrade_rifle_tun_phy" },
    stats = { Ergonomics = 50, RangedAttackMultiplier = 0.6, RangedSpreadReduction = 0.7 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 0, y = 0, w = 0, h = 0 },
        attachPoint = { x = 0, y = 0 },
        order = 0,
        scale = 0.01
    },
}


