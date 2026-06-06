Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

Deep_Lua.Gunsmith.Config = Deep_Lua.Gunsmith.Config or {
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

Deep_Lua.Gunsmith.Config.platforms = Deep_Lua.Gunsmith.Config.platforms or {}
Deep_Lua.Gunsmith.Config.weapons = Deep_Lua.Gunsmith.Config.weapons or {}
Deep_Lua.Gunsmith.Config.parts = Deep_Lua.Gunsmith.Config.parts or {}
Deep_Lua.Gunsmith.Config.npcPresets = Deep_Lua.Gunsmith.Config.npcPresets or { profiles = {} }
Deep_Lua.Gunsmith.Config.npcPresets.profiles = Deep_Lua.Gunsmith.Config.npcPresets.profiles or {}

local configPath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith/Config"

-- 顶层只加载大类入口，具体文件清单放到各自目录的入口文件里维护。
dofile(configPath .. "/Platforms/AR.lua")
dofile(configPath .. "/Platforms/AK.lua")
dofile(configPath .. "/Weapons/Weapons.lua")
dofile(configPath .. "/Parts/Parts.lua")
dofile(configPath .. "/NPC/NpcPresets.lua")
