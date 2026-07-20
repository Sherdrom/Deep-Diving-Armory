local partsPath = Deep_Lua.Path .. "/Lua/Scripts/Gunsmith/Config/Parts"

-- 配件加载顺序只在这里维护。
-- 结构件先加载，附件后加载；目前都是数据定义，顺序主要用于排查时更直观。
local files = { "AR/Structural/Barrel.lua",
    "AR/Structural/Handguard.lua",
    "AR/Structural/PistolGrip.lua",
    "AR/Structural/Stock.lua",
    "AR/Structural/BufferTubeStock.lua",
    "AR/Structural/UpperReceiver.lua",
    "AR/Structural/GasBlock.lua",
    "AK/Structural/Handguard.lua",
    "AK/Structural/PistolGrip.lua",
    "AK/Structural/Stock.lua",
    "AK/Structural/DustCover.lua",
    "AK/Structural/DovetailGrooveRail.lua",
    "Shared/Sight.lua",
    "Shared/Grip.lua",
    "Shared/SubHanging.lua",
    "Shared/Accessory.lua",
    "Shared/Muzzle.lua",
    "Shared/BufferTube.lua",
    "Shared/RearSight.lua",
    "Shared/FrontSight.lua",
}

for _, file in ipairs(files) do
    dofile(partsPath .. "/" .. file)
end
