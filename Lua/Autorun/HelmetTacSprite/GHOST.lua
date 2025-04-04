if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

local WEAR_CONFIG = {
    Sound = {
            nightSound = {  turnOn = Game.SoundManager.LoadSound(... .. "/Sound/HelmetTac/Night/nightOn.ogg"),
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

Hook.Add("GHOST_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(5,4,107,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.67)
    -- 移除战术设备时应当清空所有的执行状态
    for k, _ in pairs(isExecuted) do
        isExecuted[k] = false
    end
end)

Hook.Add("GHOST_Thermal_On", function(_, _, item)
    if isExecuted.GHOST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(4,112,143,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.63)
    isExecuted.GHOST_Thermal_On = true
    isExecuted.GHOST_Thermal_Off = false
end)

Hook.Add("GHOST_Thermal_Off", function(_, _, item)
    if isExecuted.GHOST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(180,8,136,125)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted.GHOST_Thermal_Off = true
    isExecuted.GHOST_Thermal_On = false
end)

Hook.Add("GHOST_Night_On", function(_, _, item)
    if isExecuted.GHOST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(6,229,140,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.66)
    isExecuted.GHOST_Night_On = true
    isExecuted.GHOST_Night_Off = false
end)

Hook.Add("GHOST_Night_Off", function(_, _, item)
    if isExecuted.GHOST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(334,18,161,115)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted.GHOST_Night_Off = true
    isExecuted.GHOST_Night_On = false
end)

Hook.Add("GHOST_Health_On", function(_, _, item)
    if isExecuted.GHOST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(12,343,127,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.5,0.65)
    isExecuted.GHOST_Health_On = true
    isExecuted.GHOST_Health_Off = false
end)

Hook.Add("GHOST_Health_Off", function(_, _, item)
    if isExecuted.GHOST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(179,154,135,111)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted.GHOST_Health_Off = true
    isExecuted.GHOST_Health_On = false
end)