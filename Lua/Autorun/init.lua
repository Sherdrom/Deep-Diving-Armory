Deep_Lua = {}
Deep_Lua.Path = ...

dofile(Deep_Lua.Path .. "/Lua/Scripts/HelpFunctions.lua")--Help Functions
dofile(Deep_Lua.Path .. "/Lua/Scripts/armorconfigs.lua")--Armor configs

dofile(Deep_Lua.Path .. "/Lua/Scripts/deployables.lua")--Deployables
dofile(Deep_Lua.Path .. "/Lua/Scripts/APSList.lua")--APS List

if SERVER or not Game.IsMultiplayer then
    dofile(Deep_Lua.Path .. "/Lua/Scripts/CorpseRemover.lua")--CR
    dofile(Deep_Lua.Path .. "/Lua/Scripts/missileconfigs.lua")--Missile configs, will load before missileframework
    dofile(Deep_Lua.Path .. "/Lua/Scripts/missileframework.lua")--Missile Main, will be override if Framework is already exist
    dofile(Deep_Lua.Path .. "/Lua/Scripts/LockFix.lua")--Locked Item Fixer
    dofile(Deep_Lua.Path .. "/Lua/Scripts/RefreshTool.lua")--Item Refresh Tool
end

dofile(Deep_Lua.Path .. "/Lua/Scripts/Airburst.lua")--Airburst stuff, work both side


dofile(Deep_Lua.Path .. "/Lua/Scripts/zoom.lua")--瞄具视野
dofile(Deep_Lua.Path .. "/Lua/Scripts/NoInjuryShaking.lua")--止痛药
dofile(Deep_Lua.Path .. "/Lua/Scripts/reloadPatch.lua")--换弹自动填充

--敌人脑子修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/Enemy/EnemyBattleBehavior.lua")
--伤害衰减
dofile(Deep_Lua.Path .. "/Lua/Scripts/DamageFallOff/DamageFallOff.lua")

--头盔贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/6B47.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/ALTYN.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/FAST.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/FAST_BLACK.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/GHOST.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/HelmetTacSprite/MASKA.lua")

--GL贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadGrenadeLauncher/M32.lua")

--火箭发射器贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadLaunchers/SaintPredator.lua")

--机枪贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/6P41.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/M60.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/M249.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/MG42.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/PKP.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadMachineGun/RM338.lua")

--霰弹枪贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/M4_super90.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/M590.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/M870.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/M1887.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/ServerSync.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadShotGun/supernova.lua")

--狙击枪贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/56BAN.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/AWM.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/FN49.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/GEW43.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/KAR98K.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/LEE.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/M700.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/M1903.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/MK22.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/MOSIN.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/R93.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/SKS.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/SV98.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/TYPE_38.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/ReloadSniperRifle/ZHONGZHENG.lua")

--盾牌贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/ShieldSprite/MobileShield.lua")

--衣服贴图修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/SuitSprite/MarkSuit.lua")

