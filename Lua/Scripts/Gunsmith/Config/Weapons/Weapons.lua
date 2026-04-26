Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local weaponsPath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith/Config/Weapons"

-- 武器加载顺序只在这里维护；路径按资源分类目录走。
local files = {
    "Rifle/Rifle_Steel/M4.lua",
    "Rifle/Rifle_Phy/HK416.lua"
}

for _, file in ipairs(files) do
    dofile(weaponsPath .. "/" .. file)
end
