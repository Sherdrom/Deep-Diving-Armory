local config = GunsmithFramework.Config
config.npcPresets = config.npcPresets or { profiles = {} }
config.npcPresets.profiles = config.npcPresets.profiles or {}

local profiles = config.npcPresets.profiles

profiles.ghost_hk416_soldier = {
    weapon = "deep_hk416",
    parts = {
        ["receiver"] = "hk416_receiver_std",
        ["receiver/barrel"] = "hk416_barrel_std",
        ["receiver/handguard"] = "hk416_handguard_std",
        ["receiver/optic_mount"] = "deep_2x5x_sight",
        ["receiver/handguard/Lower_rail_mount"] = "deep_vertical_grip",
    }
}
