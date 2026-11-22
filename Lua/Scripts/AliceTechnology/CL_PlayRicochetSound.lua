-- 移植自 VCE Legacy(Lua/Scripts/CL_PlayRicochetSound.lua)。
-- 默认跳弹音效改为深潜自带资源 Sound/BRUH.ogg; 各插板可用配置里的
-- RicochetSoundPath 覆盖(armorconfigs.lua 当前指向 jobgear/sound/ricochet.ogg)。
-- 仅在 CLIENT 或单机加载(见 init.lua), 服务器上 VCE.LoadedSounds 不存在。

VCE.LoadedSounds = {
    DefaultSound = Game.SoundManager.LoadSound(VCE.Path .. "/Sound/BRUH.ogg"),
}

Networking.Receive("PlayRicochetSound", function(message)
    local id = message.ReadString().Value
    if VCE.ArmorConfigs[id] == nil then return end
    if VCE.ArmorConfigs[id].PlaySound ~= true then return end
    local RicochetSound = VCE.LoadedSounds[id] or VCE.LoadedSounds.DefaultSound
    local Range = VCE.ArmorConfigs[id].SoundRange or 1000
    local x = message.ReadDouble()
    local y = message.ReadDouble()
    SoundPlayer.PlaySound(RicochetSound, Vector2(x, y), 1, Range, 1)
end)
