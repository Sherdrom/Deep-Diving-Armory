if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

local WEAR_CONFIG = {
    Sound = {
        nightsound = Game.SoundManager.LoadSound(... .. "/jobgear/sound/night.ogg"),
        frequencymultiplier = 1,
        gain = 1,
        range = 500
    },
}

Hook.Add("6B47_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(9,9,98,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
end)

Hook.Add("6B47_Thermal_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(14,114,141,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
end)

Hook.Add("6B47_Thermal_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(178,7,130,121)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
end)

Hook.Add("6B47_Night_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    --SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightsound, item.WorldPosition, WEAR_CONFIG.Sound.gain, WEAR_CONFIG.Sound.range, WEAR_CONFIG.Sound.frequencymultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(12,219,142,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
end)

Hook.Add("6B47_Night_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(334,16,153,113)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
end)