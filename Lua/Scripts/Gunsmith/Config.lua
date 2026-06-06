GunsmithFramework.Config = GunsmithFramework.Config or {
    -- 平台定义：一类枪共用的根槽、兼容类型、默认配件和 UI 名称。
    platforms = {},

    -- 武器定义：把具体 Item identifier 绑定到平台，可覆盖平台默认配件和预览参数。
    weapons = {},

    -- 配件定义：所有可安装部件。part id 必须在整个 GunSmith 配置中唯一。
    parts = {},

    -- NPC preset definitions selected by item XML gunsmithpreset attributes.
    npcPresets = {
        profiles = {}
    }
}

GunsmithFramework.Config.platforms = GunsmithFramework.Config.platforms or {}
GunsmithFramework.Config.weapons = GunsmithFramework.Config.weapons or {}
GunsmithFramework.Config.parts = GunsmithFramework.Config.parts or {}
GunsmithFramework.Config.npcPresets = GunsmithFramework.Config.npcPresets or { profiles = {} }
GunsmithFramework.Config.npcPresets.profiles = GunsmithFramework.Config.npcPresets.profiles or {}

local configPath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith/Config"

-- 顶层只加载大类入口，具体文件清单放到各自目录的入口文件里维护。
dofile(configPath .. "/Platforms/AR.lua")
dofile(configPath .. "/Platforms/AK.lua")
dofile(configPath .. "/Weapons/Weapons.lua")
dofile(configPath .. "/Parts/Parts.lua")
dofile(configPath .. "/NPC/NpcPresets.lua")
