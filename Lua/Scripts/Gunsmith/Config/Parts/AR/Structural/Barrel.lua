local parts = GunsmithFramework.Config.parts

-- 强烈建议这里的配件放到一个png里
local texture = Deep_Lua.Path .. "/GunSmith/AR/Barrel/Barrel.png"

-- AR 平台通用根部件。
-- 命名约定：
--   Lua part id: AR_<部位>_<变体>
--   XML item id: deep_gunsmith + AR + 部位 + 变体
-- 如果某个部件只属于特定武器外观，请放到 Config/Weapons/<分类>/<武器>.lua。
parts.deep_556_45_260mm_barrel = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.deep_556_45_260mm_barrel",
    provides = { "AR_barrel" },
    -- excludes = { "deep_hk416_four_rail_handguard" },
    item = { identifier = "deep_556_45_260mm_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 6, y = 4, w = 160, h = 24 },
        attachPoint = { x = 0, y = 15 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "muzzle_mount", nameKey = "deep.gunsmith.mount.barrel.muzzle_mount", accepts = { "muzzle_mount" }, anchor = { x = 149, y = -1 }, quick = { key = "muzzle" } },
        { path = "gas_block", accepts = { "AR_gas_block" }, defaultPart = "deep_mk12_gas_block", anchor = { x = 120, y = -4 } },
    }
}

parts.deep_556_45_348mm_barrel = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.deep_556_45_348mm_barrel",
    provides = { "AR_barrel" },
    -- excludes = { "deep_hk416_four_rail_handguard" },
    item = { identifier = "deep_556_45_348mm_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 6, y = 40, w = 194, h = 22 },
        attachPoint = { x = 2, y = 13 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "muzzle_mount", nameKey = "deep.gunsmith.mount.barrel.muzzle_mount", accepts = { "muzzle_mount" }, anchor = { x = 181, y = -1 }, quick = { key = "muzzle" } },
        { path = "gas_block", accepts = { "AR_gas_block" }, defaultPart = "deep_mk12_gas_block", anchor = { x = 111, y = -3 } },
    }
}

parts.deep_556_45_370mm_barrel = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.deep_556_45_370mm_barrel",
    provides = { "AR_barrel" },
    -- excludes = { "deep_hk416_four_rail_handguard" },
    item = { identifier = "deep_556_45_370mm_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 5, y = 76, w = 222, h = 23 },
        attachPoint = { x = 1, y = 14 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "muzzle_mount", nameKey = "deep.gunsmith.mount.barrel.muzzle_mount", accepts = { "muzzle_mount" }, anchor = { x = 210, y = 0 }, quick = { key = "muzzle" } },
        { path = "gas_block", accepts = { "AR_gas_block" }, defaultPart = "deep_mk12_gas_block", anchor = { x = 120, y = -2 } },
    }
}

parts.deep_556_45_457mm_barrel = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.deep_556_45_457mm_barrel",
    provides = { "AR_barrel" },
    -- excludes = { "deep_hk416_four_rail_handguard" },
    item = { identifier = "deep_556_45_457mm_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 7, y = 120, w = 247, h = 19 },
        attachPoint = { x = 1, y = 13 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "muzzle_mount", nameKey = "deep.gunsmith.mount.barrel.muzzle_mount", accepts = { "muzzle_mount" }, anchor = { x = 237, y = -1 }, quick = { key = "muzzle" } },
        { path = "gas_block", accepts = { "AR_gas_block" }, defaultPart = "deep_mk12_gas_block", anchor = { x = 161, y = -2 } },
    }
}

parts.deep_556_45_508mm_barrel = {
    type = "barrel",
    nameKey = "deep.gunsmith.part.deep_556_45_508mm_barrel",
    provides = { "AR_barrel" },
    item = { identifier = "deep_556_45_508mm_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.07 },
    visual = { texture = texture,
        source = { x = 6, y = 156, w = 275, h = 19 },
        attachPoint = { x = 1, y = 11 },
        order = 30,
        scale = 1.0
    },
    mounts = {
        { path = "muzzle_mount", nameKey = "deep.gunsmith.mount.barrel.muzzle_mount", accepts = { "muzzle_mount" }, anchor = { x = 263, y = 0 }, quick = { key = "muzzle" } },
        { path = "gas_block", accepts = { "AR_gas_block" }, defaultPart = "deep_mk12_gas_block", anchor = { x = 178, y = -1 } },
    }
}
