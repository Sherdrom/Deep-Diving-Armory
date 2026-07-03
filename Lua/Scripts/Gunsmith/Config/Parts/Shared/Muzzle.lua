local parts = GunsmithFramework.Config.parts
local muzzleTexture = Deep_Lua.Path .. "/weapon/sight/accessory_new.png"

-- 通用枪口挂点。能否安装由父挂点 accepts 和这里的 provides 共同决定。
parts.extended_barrel = { type = "muzzle_mount",
    nameKey = "deep.gunsmith.part.extended_barrel",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "muzzle_mount" },
    item = { identifier = "extended_barrel" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.30, RangedAttackMultiplier = 0.20, RangedAttackSpeed = -0.15, WeaponsSkillBonus = -15 },
    visual = { 
        texture = muzzleTexture,
        source = { x = 127, y = 221, w = 207, h = 29 },
        attachPoint = { x = 0, y = 14 },
        order = 70,
        scale = 0.5
    },
    quickAttachmentTransform = {
        muzzleOutletOffset = { x = 90, y = 0 }
    }
}

parts.deep_muzzle_brake = { type = "muzzle_mount",
    nameKey = "deep.gunsmith.part.deep_muzzle_brake",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "muzzle_mount" },
    item = { identifier = "deep_muzzle_brake" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.30, WeaponsSkillBonus = 20 },
    visual = { 
        texture = muzzleTexture,
        source = { x = 22, y = 214, w = 78, h = 43 },
        attachPoint = { x = 3, y = 22 },
        order = 70,
        scale = 0.5
    },
    quickAttachmentTransform = {
        muzzleOutletOffset = { x = 30, y = 0 }
    }
}

parts.deep_compensator = { type = "muzzle_mount",
    nameKey = "deep.gunsmith.part.deep_compensator",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "muzzle_mount" },
    item = { identifier = "deep_compensator" },
    stats = { Ergonomics = -1, MaximumHealthMultiplier = 0.25, RangedSpreadReduction = 0.10, RangedAttackMultiplier = 0.10, WeaponsSkillBonus = 10 },
    visual = { 
        texture = muzzleTexture,
        source = { x = 25, y = 263, w = 89, h = 37 },
        attachPoint = { x = 3, y = 19 },
        order = 70,
        scale = 0.5
    },
    quickAttachmentTransform = {
        muzzleOutletOffset = { x = 30, y = 0 }
    }
}

parts.deep_flash_hider = { type = "muzzle_mount",
    nameKey = "deep.gunsmith.part.deep_flash_hider",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "muzzle_mount" },
    item = { identifier = "deep_flash_hider" },
    stats = { Ergonomics = -1, RangedSpreadReduction = 0.10, RangedAttackMultiplier = 0.20, WeaponsSkillBonus = 10 },
    visual = { 
        texture = muzzleTexture,
        source = { x = 19, y = 170, w = 85, h = 41 },
        attachPoint = { x = 5, y = 21 },
        order = 70,
        scale = 0.5
    },
    quickAttachmentTransform = {
        muzzleOutletOffset = { x = 30, y = 0 }
    }
}

parts.deep_muffler = { type = "muzzle_mount",
    nameKey = "deep.gunsmith.part.deep_muffler",
    -- AR_sub_hanging_gl 由护木的 optic_mount.accepts 决定。
    provides = { "muzzle_mount" },
    item = { identifier = "deep_muffler" },
    stats = { Ergonomics = -1, SoundRangeMultiplier = -0.80, RangedSpreadReduction = 0.20, WeaponsSkillBonus = -15 },
    visual = { 
        texture = muzzleTexture,
        source = { x = 129, y = 260, w = 201, h = 46 },
        attachPoint = { x = 1, y = 23 },
        order = 70,
        scale = 0.5
    },
    quickAttachmentTransform = {
        muzzleOutletOffset = { x = 90, y = 0 }
    }
}



