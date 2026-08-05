local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/SharedParts/Stock/SharedStockAR.png"

parts.deep_ctr_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ctr_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ctr_fde_stock" },
    stats = { Ergonomics = 25, RangedSpreadReduction = 0.1 ,WeaponsSkillBonus = 5 },
    visual = { 
        texture = texture,
        source = { x = 14, y = 110, w = 104, h = 76 },
        attachPoint = { x = 103, y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_m4ss_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_m4ss_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_m4ss_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 16, y = 12, w = 112, h = 84 },
        attachPoint = { x = 110, y = 13 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_dde_black_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_dde_black_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_dde_black_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 800, y = 450, w = 95, h = 76 },
        attachPoint = { x = 95 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_lmt_sopmod_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_lmt_sopmod_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_lmt_sopmod_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 169, y = 315, w = 119, h = 77 },
        attachPoint = { x = 117 , y = 12 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_hk_e1_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_hk_e1_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_hk_e1_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 319, y = 355, w = 114, h = 74 },
        attachPoint = { x = 113 , y = 16 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_ak12_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ak12_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ak12_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 675, y = 279, w = 103, h = 74 },
        attachPoint = { x = 102 , y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_vltor_emod_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_vltor_emod_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_vltor_emod_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 173, y = 413, w = 116, h = 83 },
        attachPoint = { x = 112 , y = 16 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_ds150b_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ds150b_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ds150b_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 677, y = 195, w = 101, h = 72 },
        attachPoint = { x = 100 , y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_gl_core_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_gl_core_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_gl_core_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 328, y = 444, w = 106, h = 75 },
        attachPoint = { x = 104 , y = 12 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_mft_bus_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_mft_bus_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_mft_bus_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 487, y = 203, w = 109, h = 70 },
        attachPoint = { x = 107 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_colt_n1_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_colt_n1_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_colt_n1_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 494, y = 296, w = 102, h = 68 },
        attachPoint = { x = 100 , y = 16 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_b5_systems_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_b5_systems_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_b5_systems_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 489, y = 375, w = 138, h = 71 },
        attachPoint = { x = 137 , y = 15 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 0.9
    }
}

parts.deep_cmmg_rig_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_cmmg_rig_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_cmmg_rig_stock" },
    stats = { Ergonomics = 40, RangedSpreadReduction = 0.05 , MovementSpeed = 0.05},
    visual = { 
        texture = texture,
        source = { x = 666, y = 13, w = 102, h = 72 },
        attachPoint = { x = 101 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_tactical_sba3_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_tactical_sba3_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_tactical_sba3_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 671, y = 101, w = 87, h = 76 },
        attachPoint = { x = 84 , y = 12 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_prs_gen3_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_prs_gen3_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_prs_gen3_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 494, y = 459, w = 145, h = 67 },
        attachPoint = { x = 143 , y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 0.9
    }
}

parts.deep_acs_b_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_acs_b_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_acs_b_stock" },
    stats = { Ergonomics = 10, RangedSpreadReduction = 0.2 , WalkingSpeed = -0.05 },
    visual = { 
        texture = texture,
        source = { x = 676, y = 369, w = 101, h = 65 },
        attachPoint = { x = 100 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_gl_shock_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_gl_shock_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_gl_shock_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 786, y = 12, w = 104, h = 73 },
        attachPoint = { x = 103 , y = 13 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_ds150_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ds150_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ds150_fde_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 793, y = 192, w = 99, h = 70 },
        attachPoint = { x = 98 , y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_ctr_b_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_ctr_b_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_ctr_b_stock" },
    stats = { Ergonomics = 25, RangedSpreadReduction = 0.1 ,WeaponsSkillBonus = 5 },
    visual = { 
        texture = texture,
        source = { x = 674, y = 450, w = 103, h = 76 },
        attachPoint = { x = 102 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_moe_slk_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_moe_slk_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_moe_slk_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 787, y = 100, w = 106, h = 67 },
        attachPoint = { x = 104 , y = 11 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_acs_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_acs_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_acs_fde_stock" },
    stats = { Ergonomics = 10, RangedSpreadReduction = 0.2 , WalkingSpeed = -0.05 },
    visual = { 
        texture = texture,
        source = { x = 793, y = 280, w = 102, h = 65 },
        attachPoint = { x = 100 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_viper_mod1_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_viper_mod1_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_viper_mod1_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 791, y = 368, w = 104, h = 61 },
        attachPoint = { x = 102 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_dde_fde_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_dde_fde_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_dde_fde_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 915, y = 12, w = 92, h = 77 },
        attachPoint = { x = 91 , y = 12 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}

parts.deep_hk_slim_line_stock = { type = "stock",
    nameKey = "deep.gunsmith.part.deep_hk_slim_line_stock",
    provides = { "AR_stock" },
    item = { identifier = "deep_hk_slim_line_stock" },
    stats = { Ergonomics = 3 },
    visual = { 
        texture = texture,
        source = { x = 15, y = 211, w = 116, h = 75 },
        attachPoint = { x = 114 , y = 10 },  -- 挂载点位相对source的位置
        order = 30,
        scale = 1.0
    }
}
