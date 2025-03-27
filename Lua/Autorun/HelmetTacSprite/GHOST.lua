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

Hook.Add("GHOST_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(5,4,107,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.67)
end)

Hook.Add("GHOST_Thermal_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(4,112,143,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.63)
end)

Hook.Add("GHOST_Thermal_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(180,8,136,125)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
end)

Hook.Add("GHOST_Night_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    --SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightsound, item.WorldPosition, WEAR_CONFIG.Sound.gain, WEAR_CONFIG.Sound.range, WEAR_CONFIG.Sound.frequencymultiplier) 想给开启夜视仪的时候加个音效，但会循环播放，先搁置
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(6,229,140,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.66)
end)

Hook.Add("GHOST_Night_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(334,18,161,115)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
end)

Hook.Add("GHOST_Health_On", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(12,343,127,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.5,0.65)
end)

Hook.Add("GHOST_Health_Off", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(179,154,135,111)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
end)