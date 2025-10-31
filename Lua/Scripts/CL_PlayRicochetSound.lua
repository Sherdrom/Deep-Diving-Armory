local RicochetSound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/jobgear/sound/ricochet.ogg")


Networking.Receive("PlayRicochetSound", function(message)
        local x = message.ReadDouble()
        local y = message.ReadDouble()
        SoundPlayer.PlaySound(RicochetSound, Vector2(x, y), 1, 5000, 1)
    end)