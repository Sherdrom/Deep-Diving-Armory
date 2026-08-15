local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAR.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_ace_arfx_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ace_arfx_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ace_arfx_stock" },
    stats = { Ergonomics = 40, WeaponsSkillBonus = 25, WeaponsSkillGainSpeed = 0.5 },
    visual = { texture = texture,
        source = { x = 314, y = 13, w = 142, h = 62 },
        attachPoint = { x = 139, y = 11 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_viper_pdw_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_viper_pdw_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_viper_pdw_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 310, y = 94, w = 142, h = 55 },
        attachPoint = { x = 136, y = 11 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ums_arey_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ums_arey_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ums_arey_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 322, y = 171, w = 129, h = 83 },
        attachPoint = { x = 121, y = 11 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ums_areb_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ums_areb_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ums_areb_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 322, y = 266, w = 129, h = 80 },
        attachPoint = { x = 121, y = 11 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ace_socom_gen4_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ace_socom_gen4_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ace_socom_gen4_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 158, y = 208, w = 130, h = 79 },
        attachPoint = { x = 120, y = 17 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_m7a1_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_m7a1_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_m7a1_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 16, y = 426, w = 140, h = 56 },
        attachPoint = { x = 133, y = 12 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ravage_b_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ravage_b_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ravage_b_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 482, y = 110, w = 163, h = 79 },
        attachPoint = { x = 132, y = 12 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ravage_r_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ravage_r_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ravage_r_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 477, y = 14, w = 170, h = 80 },
        attachPoint = { x = 139, y = 12 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_f93_pro_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_f93_pro_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_f93_pro_stock" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 157, y = 12, w = 122, h = 75 },
        attachPoint = { x = 115, y = 12 },
        order = 25,
        scale = 1.0
    }
}

parts.deep_ubr_gen2_b_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ubr_gen2_b_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ubr_gen2_b_stock" },
    stats = { Ergonomics = 25, WeaponsSkillBonus = 25, WeaponsSkillGainSpeed = 0.5 },
    visual = { texture = texture,
        source = { x = 161, y = 115, w = 124, h = 66 },
        attachPoint = { x = 119, y = 10 },
        order = 25,
        scale = 1.1
    }
}

parts.deep_ubr_gen2_fde_stock = {
    type = "stock_mount",
    nameKey = "deep.gunsmith.part.deep_ubr_gen2_fde_stock",
    provides = { "AR_buffer_tube_stock" },
    item = { identifier = "deep_ubr_gen2_fde_stock" },
    stats = { Ergonomics = 35, WeaponsSkillBonus = 15, WeaponsSkillGainSpeed = 0.5},
    visual = { texture = texture,
        source = { x = 22, y = 326, w = 123, h = 66 },
        attachPoint = { x = 117, y = 10 },
        order = 25,
        scale = 1.1
    }
}
