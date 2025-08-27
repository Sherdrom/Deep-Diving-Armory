Deep_Lua = {}
Deep_Lua.Path = ...

dofile(Deep_Lua.Path .. "/Lua/Scripts/HelpFunctions.lua")--Help Functions

if SERVER or not Game.IsMultiplayer then

    dofile(Deep_Lua.Path .. "/Lua/Scripts/armorconfigs.lua")--Armor configs
    dofile(Deep_Lua.Path .. "/Lua/Scripts/armorMain.lua")--Armor Main
    dofile(Deep_Lua.Path .. "/Lua/Scripts/deployables.lua")--Deployables
    dofile(Deep_Lua.Path .. "/Lua/Scripts/APSList.lua")--APSList
    dofile(Deep_Lua.Path .. "/Lua/Scripts/CorpseRemover.lua")--CR
    dofile(Deep_Lua.Path .. "/Lua/Scripts/missileconfigs.lua")--Missile configs, will load before missileframework
    dofile(Deep_Lua.Path .. "/Lua/Scripts/missileframework.lua")--Missile Main, will be override if Framework is already exist
    dofile(Deep_Lua.Path .. "/Lua/Scripts/LockFix.lua")--Locked Item Fixer
    
end

dofile(Deep_Lua.Path .. "/Lua/Scripts/Airburst.lua")--Airburst stuff, work both side