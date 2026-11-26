-- 移植自 VCE Legacy(Lua/Scripts/configmisc.lua)。
-- 第三方/内部配置注册接口: armorconfigs.lua 末尾 Timer.Wait 经此注册 Deep_Lua.Armors。
-- WARN: YOU SHOULD MAKE SURE YOUR CONFIG IS CORRECT BEFORE LOADING INTO MAIN CONFIG!
---@param configtable table
---@return void
VCE.ArmorSystem.AddtoMain = function(configtable)
    if configtable == nil then return end
    for id,config in pairs(configtable) do
        if VCE.ArmorConfigs[id] == nil then goto goodend end
        if config.override ~= true then
            print("‖color:gui.yellow‖Warning: Config for " .. id .. " already exists. Please use override control parameter.‖end‖")
            goto loopend
        elseif VCE.ArmorConfigs[id].protected == true and config.forceoverride ~= true then
            print("‖color:gui.yellow‖Warning: Config for " .. id .. " is protected. Skipping...‖end‖")
            goto loopend
        end
        ::goodend::                     --Green Light. All clear to go. NO VALIDATION CHECK.
        VCE.ArmorConfigs[id] = config
        if CLIENT and config.PlaySound then
            VCE.LoadedSounds[id] = Game.SoundManager.LoadSound(config.RicochetSoundPath)
        end
        ::loopend::                     --Red Light. Next.
    end
end
