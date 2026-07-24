Deep_Lua = Deep_Lua or {}
Deep_Lua.Path = ...

--爱丽丝科技
dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/HelpFunctions.lua")--Help Functions
dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/armorconfigs.lua")--Armor configs

dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/deployables.lua")--Deployables
dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/APSList.lua")--APS List

dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/Airburst.lua")--Airburst stuff, work both side

if SERVER or not Game.IsMultiplayer then
    dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/CorpseRemover.lua")--CR
    dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/missileconfigs.lua")--Missile configs, will load before missileframework
    dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/missileframework.lua")--Missile Main, will be override if Framework is already exist
    dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/LockFix.lua")--Locked Item Fixer
    dofile(Deep_Lua.Path .. "/Lua/Scripts/AliceTechnology/RefreshTool.lua")--Item Refresh Tool
end
--爱丽丝科技

--苯科技
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/zoom.lua")--瞄具视野
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/reloadPatch.lua")--换弹自动填充
--所有贴图修改（减少卡顿）
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/AllSprite/AllSprite.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/6B47.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/ALTYN.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/FAST.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/FAST_BLACK.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/GHOST.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/HelmetTacSprite/MASKA.lua")

-- 物品栏贴图修改（有加载类性能问题，巡回加载时间逐渐增加：9s  19s  35s）
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/MosinMagIcon.lua")

--枪械改装系统
--if GunsmithFramework and GunsmithFramework.RegisterPackage then
--    GunsmithFramework.RegisterPackage({
--        modDir = Deep_Lua.Path,
--        entry = "Lua/Scripts/Gunsmith/Config.lua"
--    })
--else
--    print("[Deep-Diving-Armory] GunsmithFramework is required for Gunsmith configuration. Load GunsmithFramework before Deep-Diving-Armory.")
--end

--GL特殊换弹
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadGrenadeLauncher/M32.lua")
--霰弹枪特殊换弹
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/M4_super90.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/M590.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/M870.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/M1887.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/ServerSync.lua")
dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadShotGun/supernova.lua")
--火箭筒贴图修改
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadLaunchers/SaintPredator.lua")
--机枪贴图修改
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/6P41.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/M60.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/M249.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/MG42.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/PKP.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadMachineGun/RM338.lua")
--狙击枪贴图修改
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/56BAN.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/AWM.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/FN49.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/GEW43.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/KAR98K.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/LEE.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/M700.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/M1903.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/MK22.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/MOSIN.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/MosinMagIcon.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/R93.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/SKS.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/SV98.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/TYPE_38.lua")
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ReloadSniperRifle/ZHONGZHENG.lua")
--盾牌贴图修改
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/ShieldSprite/MobileShield.lua")
--衣服贴图修改
--dofile(Deep_Lua.Path .. "/Lua/Scripts/BenzeneTechnology/SuitSprite/MarkSuit.lua")
--苯科技

--桃子科技
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/HelperFunctions.lua")--工具函数
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/DeepHitmarker.lua")--命中反馈
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/KillNotification.lua")--击杀通知
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/IgnoreArmLimbs.lua")--60%概率子弹无视手臂
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/NoCollisionHoldable.lua")--盾牌不推人
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/NoInjuryShaking.lua")--止痛药，受伤手臂不会乱晃
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/HeadShotOnly.lua")--致命爆头only
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/DamageFallOffAll.lua")--伤害衰减
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/EnemyBattleBehavior.lua")--敌人脑子修改
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/NoFriendlyDamage.lua")--友谊芯片强制伤害为0
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/GiveTalents.lua")--给予天赋
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/ResistanceLimit.lua")--抗性限制
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/HeadShotMultiplier.lua")--爆头倍率
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/SpawnBlindBox.lua")--随机生成
dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/AIRandomWeapon.lua")--AI随机切换武器

--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/ShieldBlock.lua")--多层盾牌(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/FriendlyFireProjectile.lua")--可调整的友军子弹穿透(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/TruePercentDamage.lua")--致命爆头无视虚血（有character性能问题）(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/HumanAiIgnoreEnemyAi.lua")--使IgnoredByEnemyAI对人类敌人ai生效(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/ImmuneToImpact.lua")--冲击力修改(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua")--装备属性调整（配置文件）(暂时用不到)
--dofile(Deep_Lua.Path .. "/Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue.lua")--装备属性调整（本体代码）(暂时用不到)
--桃子科技
