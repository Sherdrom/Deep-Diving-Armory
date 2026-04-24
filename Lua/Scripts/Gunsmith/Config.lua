Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local texture = Deep_Lua.Path .. "/weapon/rifle/rifle_steel/rifle_steel.png"

Deep_Lua.Gunsmith.Config = {
    platforms = {
        ar15 = {
            id = "ar15",
            canvas = { w = 512, h = 160 },
            slots = { "receiver", "barrel", "handguard", "pistol_grip", "stock" },
            requiredRootSlots = true,
            slotNames = {
                receiver = "机匣",
                barrel = "枪管",
                handguard = "护木",
                pistol_grip = "握把",
                stock = "枪托",
                top_rail = "上导轨",
                bottom_rail = "下导轨",
                left_rail = "左导轨",
                right_rail = "右导轨",
                optic_mount = "瞄具挂点"
            },
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
            name = "M4 标准机匣",
            texture = texture,
            source = { x = 120, y = 600, w = 185, h = 72 },
            offset = { x = 156, y = 50 },
            order = 30
        },
        m4_receiver_alt = {
            slot = "receiver",
            name = "M4 备用机匣",
            texture = texture,
            source = { x = 130, y = 610, w = 165, h = 58 },
            offset = { x = 166, y = 56 },
            order = 30
        },

        m4_barrel_145 = {
            slot = "barrel",
            name = "14.5 英寸枪管",
            texture = texture,
            source = { x = 285, y = 612, w = 178, h = 34 },
            offset = { x = 288, y = 66 },
            order = 20
        },
        m4_barrel_short = {
            slot = "barrel",
            name = "短枪管",
            texture = texture,
            source = { x = 285, y = 612, w = 126, h = 34 },
            offset = { x = 288, y = 66 },
            order = 20
        },

        m4_handguard_std = {
            slot = "handguard",
            name = "M4 标准护木",
            texture = texture,
            source = { x = 260, y = 628, w = 105, h = 45 },
            offset = { x = 260, y = 70 },
            order = 40,
            mounts = {
                { slot = "top_rail", name = "上导轨" },
                { slot = "bottom_rail", name = "下导轨" },
                { slot = "left_rail", name = "左导轨" },
                { slot = "right_rail", name = "右导轨" }
            }
        },
        m4_handguard_alt = {
            slot = "handguard",
            name = "轻量护木",
            itemIdentifier = "deep_gunsmith_m4_handguard_alt",
            texture = texture,
            source = { x = 262, y = 628, w = 92, h = 34 },
            offset = { x = 268, y = 72 },
            order = 40,
            mounts = {
                { slot = "top_rail", name = "上导轨" },
                { slot = "bottom_rail", name = "下导轨" }
            }
        },

        m4_grip_std = {
            slot = "pistol_grip",
            name = "A2 握把",
            texture = texture,
            source = { x = 194, y = 652, w = 42, h = 62 },
            offset = { x = 212, y = 88 },
            order = 50
        },
        m4_grip_alt = {
            slot = "pistol_grip",
            name = "紧凑握把",
            texture = texture,
            source = { x = 198, y = 652, w = 34, h = 52 },
            offset = { x = 214, y = 90 },
            order = 50
        },

        m4_stock_std = {
            slot = "stock",
            name = "卡宾枪托",
            texture = texture,
            source = { x = 30, y = 613, w = 115, h = 62 },
            offset = { x = 36, y = 62 },
            order = 10
        },
        m4_stock_alt = {
            slot = "stock",
            name = "短枪托",
            texture = texture,
            source = { x = 50, y = 614, w = 82, h = 54 },
            offset = { x = 64, y = 66 },
            order = 10
        },

        m4_rail_short = {
            slot = "top_rail",
            name = "短皮卡汀尼导轨",
            itemIdentifier = "deep_gunsmith_m4_rail_short",
            order = 60,
            mounts = {
                { slot = "optic_mount", name = "瞄具挂点" }
            }
        },
        m4_rail_long = {
            slot = "top_rail",
            name = "长皮卡汀尼导轨",
            order = 60,
            mounts = {
                { slot = "optic_mount", name = "瞄具挂点" }
            }
        },
        m4_side_rail = {
            slot = "left_rail",
            name = "侧面导轨",
            order = 60
        },
        m4_right_rail = {
            slot = "right_rail",
            name = "右侧导轨",
            order = 60
        },
        m4_bottom_rail = {
            slot = "bottom_rail",
            name = "下方导轨",
            order = 60
        },
        m4_red_dot = {
            slot = "optic_mount",
            name = "红点瞄准镜",
            itemIdentifier = "deep_gunsmith_m4_red_dot",
            order = 70
        },
        m4_holo_sight = {
            slot = "optic_mount",
            name = "全息瞄准镜",
            order = 70
        }
    }
}
