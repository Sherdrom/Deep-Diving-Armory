local parts = GunsmithFramework.Config.parts
local UpgradeTexture = Deep_Lua.Path .. "/weapon/sight/accessory.png"

parts.chip_friendly_fire_b = {
    type = "weapon_upgrade_b",
    nameKey = "deep.gunsmith.part.chip_friendly_fire",
    provides = { "weapon_upgrade" },
    item = { identifier = "chip_friendly_fire" },
    stats = { TeamAttackMultiplier = -1 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 0, y = 0, w = 0, h = 0 },
        attachPoint = { x = 0, y = 0 },
        order = 0,
        scale = 0.01
    },
}

parts.chip_rapid_receiver_b = {
    type = "weapon_upgrade_b",
    nameKey = "deep.gunsmith.part.chip_rapid_receiver",
    provides = { "weapon_upgrade" },
    item = { identifier = "chip_rapid_receiver" },
    stats = { RangedAttackSpeed = 0.15, RangedSpreadReduction = -0.3 },
    visual = { 
        texture = UpgradeTexture,
        source = { x = 0, y = 0, w = 0, h = 0 },
        attachPoint = { x = 0, y = 0 },
        order = 0,
        scale = 0.01
    },
}


