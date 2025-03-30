if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

local WEAR_CONFIG = {
    Sound = {
            nightSound = {  turnOn = Game.SoundManager.LoadSound(... .. "/Sound/HelmetTac/Night/nightOn.Ogg"),
                            frequencyMultiplier = 1,
                            gain = 1,
                            range = 500},
            -- thermalSound = { sound = Game.SoundManager.LoadSound(... .. "/jobgear/sound/thermal.ogg"),
            --                 frequencymultiplier = 1,
            --                 gain = 1,
            --                 range = 500},
            -- healthSound = { sound = Game.SoundManager.LoadSound(... .. "/jobgear/sound/health.ogg"),
            --                 frequencymultiplier = 1,
            --                 gain = 1,
            --                 range = 500}
    }
}

-- 所有的OnUse Hook应该只执行一次，而不是一直执行
local isExecuted={}

Hook.Add("FAST_BLACK_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,8,94,90)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
    -- 移除战术设备时应当清空所有的执行状态
    for k, _ in pairs(isExecuted) do
        isExecuted[k] = false
    end
end)

Hook.Add("FAST_BLACK_Thermal_On", function(_, _, item)
    if isExecuted.FAST_BLACK_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,118,136,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
    isExecuted.FAST_BLACK_Thermal_On = true
    isExecuted.FAST_BLACK_Thermal_Off = false
end)

Hook.Add("FAST_BLACK_Thermal_Off", function(_, _, item)
    if isExecuted.FAST_BLACK_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(201,7,123,123)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted.FAST_BLACK_Thermal_Off = true
    isExecuted.FAST_BLACK_Thermal_On = false
end)

Hook.Add("FAST_BLACK_Night_On", function(_, _, item)
    if isExecuted.FAST_BLACK_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(18,231,134,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
    isExecuted.FAST_BLACK_Night_On = true
    isExecuted.FAST_BLACK_Night_Off = false
end)

Hook.Add("FAST_BLACK_Night_Off", function(_, _, item)
    if isExecuted.FAST_BLACK_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(337,19,146,118)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted.FAST_BLACK_Night_Off = true
    isExecuted.FAST_BLACK_Night_On = false
end)

Hook.Add("FAST_BLACK_Health_On", function(_, _, item)
    if isExecuted.FAST_BLACK_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,330,117,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.62)
    isExecuted.FAST_BLACK_Health_On = true
    isExecuted.FAST_BLACK_Health_Off = false
end)

Hook.Add("FAST_BLACK_Health_Off", function(_, _, item)
    if isExecuted.FAST_BLACK_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(202,136,120,107)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted.FAST_BLACK_Health_Off = true
    isExecuted.FAST_BLACK_Health_On = false
end)