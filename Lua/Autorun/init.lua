DDA_AAS = {}
DDA_AAS.Path = ...

if SERVER or not Game.IsMultiplayer then

    dofile(DDA_AAS.Path .. "/Lua/Scripts/armorconfigs.lua")
    dofile(DDA_AAS.Path .. "/Lua/Scripts/armorMain.lua")

end
dofile(DDA_AAS.Path .. "/Lua/Scripts/AirBurst.lua")