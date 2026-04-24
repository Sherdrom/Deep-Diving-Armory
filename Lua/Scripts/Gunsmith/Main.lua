Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local basePath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith"

dofile(basePath .. "/Core.lua")
dofile(basePath .. "/Persistence.lua")
dofile(basePath .. "/UiSpec.lua")
dofile(basePath .. "/Runtime.lua")
dofile(basePath .. "/Hooks.lua")

if Deep_Lua.Gunsmith.Hooks and Deep_Lua.Gunsmith.Hooks.Register then
    Deep_Lua.Gunsmith.Hooks.Register()
end
