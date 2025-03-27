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

Hook.Add("FAST_BLACK_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,8,94,90)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
end)

Hook.Add("FAST_BLACK_Thermal_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,118,136,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
end)

Hook.Add("FAST_BLACK_Thermal_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(201,7,123,123)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
end)

Hook.Add("FAST_BLACK_Night_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    --SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightsound, item.WorldPosition, WEAR_CONFIG.Sound.gain, WEAR_CONFIG.Sound.range, WEAR_CONFIG.Sound.frequencymultiplier) 想给开启夜视仪的时候加个音效，但会循环播放，先搁置
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(18,231,134,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
end)

Hook.Add("FAST_BLACK_Night_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(337,19,146,118)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
end)

Hook.Add("FAST_BLACK_Health_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,330,117,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.62)
end)

Hook.Add("FAST_BLACK_Health_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(202,136,120,107)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
end)