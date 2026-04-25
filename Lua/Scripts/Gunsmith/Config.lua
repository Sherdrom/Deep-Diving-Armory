Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local texture = Deep_Lua.Path .. "/weapon/rifle/rifle_steel/rifle_steel.png"

Deep_Lua.Gunsmith.Config = {
    platforms = {
        ar15 = {
            id = "ar15",
            canvas = { w = 512, h = 160 },
            visualScale = 1.0,
            visualOrigin = { x = 256, y = 80 },
            slots = { "receiver", "barrel", "handguard", "pistol_grip", "stock" },
            requiredRootSlots = true,
            rootAccepts = {
                receiver = { "ar15_receiver" },
                barrel = { "ar15_barrel" },
                handguard = { "ar15_handguard" },
                pistol_grip = { "ar15_pistol_grip" },
                stock = { "ar15_stock" }
            },
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
            platform = "ar15",
            scale = 1,
            preview = {
                padding = 12,
                zoom = 1.0,
                offset = { x = 0, y = 0 }
            }
        }
    },

    parts = {
        m4_receiver_std = {
            slot = "receiver",
            name = "M4 标准机匣",
            provides = { "ar15_receiver" },
            stats = { weight = 1.0, ergonomics = 8, recoilControl = 0.02 },
            visual = {
                texture = texture,
                source = { x = 120, y = 600, w = 185, h = 72 },
                offset = { x = 156, y = 50 },
                order = 30,
                scale = 1.0
            }
        },
        m4_receiver_alt = {
            slot = "receiver",
            name = "M4 备用机匣",
            provides = { "ar15_receiver" },
            item = { virtual = true },
            stats = { weight = 0.9, ergonomics = 10, recoilControl = 0.01 },
            visual = {
                texture = texture,
                source = { x = 130, y = 610, w = 165, h = 58 },
                offset = { x = 166, y = 56 },
                order = 30,
                scale = 1.0
            }
        },

        m4_barrel_145 = {
            slot = "barrel",
            name = "14.5 英寸枪管",
            provides = { "ar15_barrel" },
            stats = { weight = 0.85, ergonomics = -2, recoilControl = 0.04, spreadReduction = 0.06 },
            visual = {
                texture = texture,
                source = { x = 285, y = 612, w = 178, h = 34 },
                offset = { x = 288, y = 66 },
                order = 20,
                scale = 1.0
            }
        },
        m4_barrel_short = {
            slot = "barrel",
            name = "短枪管",
            provides = { "ar15_barrel" },
            item = { virtual = true },
            stats = { weight = 0.58, ergonomics = 4, recoilControl = -0.02, spreadReduction = -0.03 },
            visual = {
                texture = texture,
                source = { x = 285, y = 612, w = 126, h = 34 },
                offset = { x = 288, y = 66 },
                order = 20,
                scale = 1.0
            }
        },

        m4_handguard_std = {
            slot = "handguard",
            name = "M4 标准护木",
            provides = { "ar15_handguard" },
            stats = { weight = 0.48, ergonomics = 2, recoilControl = 0.02 },
            visual = {
                texture = texture,
                source = { x = 260, y = 628, w = 105, h = 45 },
                offset = { x = 260, y = 70 },
                order = 40,
                scale = 1.0
            },
            mounts = {
                { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" } },
                { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" } },
                { slot = "left_rail", name = "左导轨", accepts = { "picatinny_rail" } },
                { slot = "right_rail", name = "右导轨", accepts = { "picatinny_rail" } }
            }
        },
        m4_handguard_alt = {
            slot = "handguard",
            name = "轻量护木",
            provides = { "ar15_handguard" },
            item = { identifier = "deep_gunsmith_m4_handguard_alt" },
            stats = { weight = 0.32, ergonomics = 5, recoilControl = -0.01 },
            visual = {
                texture = texture,
                source = { x = 262, y = 628, w = 92, h = 34 },
                offset = { x = 268, y = 72 },
                order = 40,
                scale = 1.0
            },
            mounts = {
                { slot = "top_rail", name = "上导轨", accepts = { "picatinny_rail" } },
                { slot = "bottom_rail", name = "下导轨", accepts = { "picatinny_rail" } }
            }
        },

        m4_grip_std = {
            slot = "pistol_grip",
            name = "A2 握把",
            provides = { "ar15_pistol_grip" },
            stats = { weight = 0.12, ergonomics = 3, recoilControl = 0.02 },
            visual = {
                texture = texture,
                source = { x = 194, y = 652, w = 42, h = 62 },
                offset = { x = 212, y = 88 },
                order = 50,
                scale = 1.0
            }
        },
        m4_grip_alt = {
            slot = "pistol_grip",
            name = "紧凑握把",
            provides = { "ar15_pistol_grip" },
            item = { virtual = true },
            stats = { weight = 0.09, ergonomics = 6, recoilControl = -0.01 },
            visual = {
                texture = texture,
                source = { x = 198, y = 652, w = 34, h = 52 },
                offset = { x = 214, y = 90 },
                order = 50,
                scale = 1.0
            }
        },

        m4_stock_std = {
            slot = "stock",
            name = "卡宾枪托",
            provides = { "ar15_stock" },
            stats = { weight = 0.36, ergonomics = 2, recoilControl = 0.05 },
            visual = {
                texture = texture,
                source = { x = 30, y = 613, w = 115, h = 62 },
                offset = { x = 36, y = 62 },
                order = 10,
                scale = 1.0
            }
        },
        m4_stock_alt = {
            slot = "stock",
            name = "短枪托",
            provides = { "ar15_stock" },
            item = { virtual = true },
            stats = { weight = 0.22, ergonomics = 6, recoilControl = -0.03 },
            visual = {
                texture = texture,
                source = { x = 50, y = 614, w = 82, h = 54 },
                offset = { x = 64, y = 66 },
                order = 10,
                scale = 1.0
            }
        },

        m4_rail_short = {
            slot = "top_rail",
            name = "短皮卡汀尼导轨",
            provides = { "picatinny_rail" },
            item = { identifier = "deep_gunsmith_m4_rail_short" },
            stats = { weight = 0.08, ergonomics = -1 },
            mounts = {
                { slot = "optic_mount", name = "瞄具挂点", accepts = { "small_optic", "medium_optic" } }
            }
        },
        m4_rail_long = {
            slot = "top_rail",
            name = "长皮卡汀尼导轨",
            provides = { "picatinny_rail" },
            item = { virtual = true },
            stats = { weight = 0.14, ergonomics = -2 },
            mounts = {
                { slot = "optic_mount", name = "瞄具挂点", accepts = { "small_optic", "medium_optic" } }
            }
        },
        m4_side_rail = {
            slot = "left_rail",
            name = "侧面导轨",
            provides = { "picatinny_rail" },
            item = { virtual = true },
            stats = { weight = 0.08, ergonomics = -1 }
        },
        m4_right_rail = {
            slot = "right_rail",
            name = "右侧导轨",
            provides = { "picatinny_rail" },
            item = { virtual = true },
            stats = { weight = 0.08, ergonomics = -1 }
        },
        m4_bottom_rail = {
            slot = "bottom_rail",
            name = "下方导轨",
            provides = { "picatinny_rail" },
            item = { virtual = true },
            stats = { weight = 0.1, ergonomics = -1, recoilControl = 0.01 }
        },
        m4_red_dot = {
            slot = "optic_mount",
            name = "红点瞄准镜",
            provides = { "small_optic" },
            item = { identifier = "deep_gunsmith_m4_red_dot" },
            stats = { weight = 0.18, ergonomics = -1, spreadReduction = 0.03 }
        },
        m4_holo_sight = {
            slot = "optic_mount",
            name = "全息瞄准镜",
            provides = { "medium_optic" },
            item = { virtual = true },
            stats = { weight = 0.25, ergonomics = -2, spreadReduction = 0.04 }
        }
    }
}
