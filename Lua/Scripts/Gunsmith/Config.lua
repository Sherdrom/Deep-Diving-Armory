Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local texture = Deep_Lua.Path .. "/weapon/rifle/rifle_steel/rifle_steel.png"

Deep_Lua.Gunsmith.Config = {
    platforms = {
        ar15 = {
            id = "ar15",
            canvas = { w = 512, h = 160 },
            slots = { "receiver", "barrel", "handguard", "pistol_grip", "stock" },
            defaults = {
                receiver = "m4_receiver_std",
                barrel = "m4_barrel_145",
                handguard = "m4_handguard_std",
                pistol_grip = "m4_grip_std",
                stock = "m4_stock_std"
            }
        }
    },

    weapons = {
        deep_m4 = {
            platform = "ar15"
        }
    },

    parts = {
        m4_receiver_std = {
            slot = "receiver",
            name = "M4 Receiver",
            texture = texture,
            source = { x = 120, y = 600, w = 185, h = 72 },
            offset = { x = 156, y = 50 },
            order = 30
        },
        m4_receiver_alt = {
            slot = "receiver",
            name = "M4 Receiver Alt",
            texture = texture,
            source = { x = 130, y = 610, w = 165, h = 58 },
            offset = { x = 166, y = 56 },
            order = 30
        },

        m4_barrel_145 = {
            slot = "barrel",
            name = "14.5 Barrel",
            texture = texture,
            source = { x = 285, y = 612, w = 178, h = 34 },
            offset = { x = 288, y = 66 },
            order = 20
        },
        m4_barrel_short = {
            slot = "barrel",
            name = "Short Barrel",
            texture = texture,
            source = { x = 285, y = 612, w = 126, h = 34 },
            offset = { x = 288, y = 66 },
            order = 20
        },

        m4_handguard_std = {
            slot = "handguard",
            name = "M4 Handguard",
            texture = texture,
            source = { x = 260, y = 628, w = 105, h = 45 },
            offset = { x = 260, y = 70 },
            order = 40
        },
        m4_handguard_alt = {
            slot = "handguard",
            name = "Slim Handguard",
            texture = texture,
            source = { x = 262, y = 628, w = 92, h = 34 },
            offset = { x = 268, y = 72 },
            order = 40
        },

        m4_grip_std = {
            slot = "pistol_grip",
            name = "A2 Grip",
            texture = texture,
            source = { x = 194, y = 652, w = 42, h = 62 },
            offset = { x = 212, y = 88 },
            order = 50
        },
        m4_grip_alt = {
            slot = "pistol_grip",
            name = "Compact Grip",
            texture = texture,
            source = { x = 198, y = 652, w = 34, h = 52 },
            offset = { x = 214, y = 90 },
            order = 50
        },

        m4_stock_std = {
            slot = "stock",
            name = "Carbine Stock",
            texture = texture,
            source = { x = 30, y = 613, w = 115, h = 62 },
            offset = { x = 36, y = 62 },
            order = 10
        },
        m4_stock_alt = {
            slot = "stock",
            name = "Short Stock",
            texture = texture,
            source = { x = 50, y = 614, w = 82, h = 54 },
            offset = { x = 64, y = 66 },
            order = 10
        }
    }
}
