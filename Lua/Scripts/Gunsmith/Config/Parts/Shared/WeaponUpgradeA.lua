local parts = GunsmithFramework.Config.parts
local UpgradeTexture = Deep_Lua.Path .. "/weapon/sight/accessory.png"

parts.chip_friendly_fire_a = {
    type = "weapon_upgrade_a",
    nameKey = "deep.gunsmith.part.chip_friendly_fire",
    excludes = { "chip_friendly_fire_b" },
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


