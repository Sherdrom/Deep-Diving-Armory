Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local basePath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith"

dofile(basePath .. "/Core.lua")
dofile(basePath .. "/Validation.lua")
dofile(basePath .. "/Persistence.lua")
dofile(basePath .. "/Inventory.lua")
dofile(basePath .. "/Stats.lua")
dofile(basePath .. "/QuickMod.lua")
dofile(basePath .. "/UiSpec.lua")
dofile(basePath .. "/Runtime.lua")
dofile(basePath .. "/Hooks.lua")

local function runStartupValidation()
    if Deep_Lua.Gunsmith.Validation and Deep_Lua.Gunsmith.Validation.Run then
        Deep_Lua.Gunsmith.Validation.Run(nil, "Startup")
    end
end

if Timer and Timer.Wait then
    Timer.Wait(runStartupValidation, 1000)
else
    runStartupValidation()
end

if Deep_Lua.Gunsmith.Validation and Deep_Lua.Gunsmith.Validation.RegisterCommands then
    Deep_Lua.Gunsmith.Validation.RegisterCommands()
end

if Deep_Lua.Gunsmith.Hooks and Deep_Lua.Gunsmith.Hooks.Register then
    Deep_Lua.Gunsmith.Hooks.Register()
end
