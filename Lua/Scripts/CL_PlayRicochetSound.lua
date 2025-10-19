local RicochetSound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/jobgear/sound/ricochet.ogg")


Networking.Receive("PlayRicochetSound", function(message)
        SoundPlayer.PlaySound(RicochetSound, item.WorldPosition, 1, 100, 1)
    end)