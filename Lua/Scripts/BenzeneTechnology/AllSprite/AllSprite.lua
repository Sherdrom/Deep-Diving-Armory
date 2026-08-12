if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

local WEAR_CONFIG = {
    Sound = {
            nightSound = {  turnOn = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/HelmetTac/Night/nightOn.ogg"),
                            frequencyMultiplier = 1,
                            gain = 1,
                            range = 500},
            OpenSound = {  sound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/HelmetTac/Mask/MaskOpen.ogg"),
                            frequencyMultiplier = 1,
                            gain = 1,
                            range = 500},
            CloseSound = { sound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/HelmetTac/Mask/MaskClose.ogg"),
                            frequencyMultiplier = 1,
                            gain = 1,
                            range = 500}                
            -- thermalSound = { sound = Game.SoundManager.LoadSound(modPath .. "/jobgear/sound/thermal.ogg"),
            --                 frequencymultiplier = 1,
            --                 gain = 1,
            --                 range = 500},
            -- healthSound = { sound = Game.SoundManager.LoadSound(modPath .. "/jobgear/sound/health.ogg"),
            --                 frequencymultiplier = 1,
            --                 gain = 1,
            --                 range = 500}
    }
}


-- 所有的OnUse Hook应该只执行一次，而不是一直执行
local isExecuted={}
-- 头盔类贴图修改
Hook.Add("SixBFortySeven_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(9,9,98,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("SixBFortySeven_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(14,114,141,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
    isExecuted[item.ID] = {
            SixBFortySeven_Thermal_On = true,
            SixBFortySeven_Thermal_Off = false
        }
end)

Hook.Add("SixBFortySeven_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(178,7,130,121)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            SixBFortySeven_Thermal_On = false,
            SixBFortySeven_Thermal_Off = true
        }
end)

Hook.Add("SixBFortySeven_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(12,219,142,93)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
    isExecuted[item.ID] = {
            SixBFortySeven_Night_On = true,
            SixBFortySeven_Night_Off = false
        }
end)

Hook.Add("SixBFortySeven_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(334,16,153,113)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted[item.ID] = {
            SixBFortySeven_Night_On = false,
            SixBFortySeven_Night_Off = true
        }
end)

Hook.Add("SixBFortySeven_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(9,324,124,94)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.62)
    isExecuted[item.ID] = {
            SixBFortySeven_Health_On = true,
            SixBFortySeven_Health_Off = false
        }
end)

Hook.Add("SixBFortySeven_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].SixBFortySeven_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(177,143,124,112)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            SixBFortySeven_Health_On = false,
            SixBFortySeven_Health_Off = true
        }
end)

Hook.Add("FAST_BLACK_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,8,94,90)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("FAST_BLACK_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,118,136,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
    isExecuted[item.ID] = {
            FAST_BLACK_Thermal_On = true,
            FAST_BLACK_Thermal_Off = false
        }
end)

Hook.Add("FAST_BLACK_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(201,7,123,123)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            FAST_BLACK_Thermal_On = false,
            FAST_BLACK_Thermal_Off = true
        }
end)

Hook.Add("FAST_BLACK_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(18,231,134,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
    isExecuted[item.ID] = {
            FAST_BLACK_Night_On = true,
            FAST_BLACK_Night_Off = false
        }
end)

Hook.Add("FAST_BLACK_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(337,19,146,118)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted[item.ID] = {
            FAST_BLACK_Night_On = false,
            FAST_BLACK_Night_Off = true
        }
end)

Hook.Add("FAST_BLACK_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,330,117,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.62)
    isExecuted[item.ID] = {
            FAST_BLACK_Health_On = true,
            FAST_BLACK_Health_Off = false
        }
end)

Hook.Add("FAST_BLACK_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_BLACK_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(202,136,120,107)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            FAST_BLACK_Health_On = false,
            FAST_BLACK_Health_Off = true
        }
end)

Hook.Add("FAST_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,8,94,90)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("FAST_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,118,136,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
    isExecuted[item.ID] = {
            FAST_Thermal_On = true,
            FAST_Thermal_Off = false
        }
end)

Hook.Add("FAST_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(201,7,123,123)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            FAST_Thermal_On = false,
            FAST_Thermal_Off = true
        }
end)

Hook.Add("FAST_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(18,231,134,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.62)
    isExecuted[item.ID] = {
            FAST_Night_On = true,
            FAST_Night_Off = false
        }
end)

Hook.Add("FAST_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(337,19,146,118)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted[item.ID] = {
            FAST_Night_On = false,
            FAST_Night_Off = true
        }
end)

Hook.Add("FAST_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(16,330,117,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.62)
    isExecuted[item.ID] = {
            FAST_Health_On = true,
            FAST_Health_Off = false
        }
end)

Hook.Add("FAST_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(202,136,120,107)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            FAST_Health_On = false,
            FAST_Health_Off = true
        }
end)

Hook.Add("FAST_Ranger_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(13,10,99,91)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.51,0.58)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("FAST_Ranger_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(13,127,137,91)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.37,0.58)
    isExecuted[item.ID] = {
            FAST_Thermal_On = true,
            FAST_Thermal_Off = false
        }
end)

Hook.Add("FAST_Ranger_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(206,3,125,124)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.41,0.69)
    isExecuted[item.ID] = {
            FAST_Thermal_On = false,
            FAST_Thermal_Off = true
        }
end)

Hook.Add("FAST_Ranger_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(18,231,134,89)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.35,0.71)
    isExecuted[item.ID] = {
            FAST_Night_On = true,
            FAST_Night_Off = false
        }
end)

Hook.Add("FAST_Ranger_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(362,10,144,117)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.36,0.68)
    isExecuted[item.ID] = {
            FAST_Night_On = false,
            FAST_Night_Off = true
        }
end)

Hook.Add("FAST_Ranger_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(13,357,114,91)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.58)
    isExecuted[item.ID] = {
            FAST_Health_On = true,
            FAST_Health_Off = false
        }
end)

Hook.Add("FAST_Ranger_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(206,175,124,100)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.4,0.62)
    isExecuted[item.ID] = {
            FAST_Health_On = false,
            FAST_Health_Off = true
        }
end)

Hook.Add("FAST_Heavy_Trooper_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(10,11,98,104)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.52,0.55)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("FAST_Heavy_Trooper_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(10,130,150,105)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.35,0.56)
    isExecuted[item.ID] = {
            FAST_Thermal_On = true,
            FAST_Thermal_Off = false
        }
end)

Hook.Add("FAST_Heavy_Trooper_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(199,37,131,130)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.4,0.64)
    isExecuted[item.ID] = {
            FAST_Thermal_On = false,
            FAST_Thermal_Off = true
        }
end)

Hook.Add("FAST_Heavy_Trooper_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(10,250,141,105)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.37,0.58)
    isExecuted[item.ID] = {
            FAST_Night_On = true,
            FAST_Night_Off = false
        }
end)

Hook.Add("FAST_Heavy_Trooper_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(354,44,151,123)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.34,0.62)
    isExecuted[item.ID] = {
            FAST_Night_On = false,
            FAST_Night_Off = true
        }
end)

Hook.Add("FAST_Heavy_Trooper_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(10,370,121,105)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.43,0.56)
    isExecuted[item.ID] = {
            FAST_Health_On = true,
            FAST_Health_Off = false
        }
end)

Hook.Add("FAST_Heavy_Trooper_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(199,208,126,108)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.41,0.57)
    isExecuted[item.ID] = {
            FAST_Health_On = false,
            FAST_Health_Off = true
        }
end)

Hook.Add("FAST_Sledge_Hammer_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(3,4,106,107)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.62)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("FAST_Sledge_Hammer_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(2,255,164,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.37,0.58)
    isExecuted[item.ID] = {
            FAST_Thermal_On = true,
            FAST_Thermal_Off = false
        }
end)

Hook.Add("FAST_Sledge_Hammer_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(192,112,133,133)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.69)
    isExecuted[item.ID] = {
            FAST_Thermal_On = false,
            FAST_Thermal_Off = true
        }
end)

Hook.Add("FAST_Sledge_Hammer_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(2,140,161,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.37,0.6)
    isExecuted[item.ID] = {
            FAST_Night_On = true,
            FAST_Night_Off = false
        }
end)

Hook.Add("FAST_Sledge_Hammer_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(343,104,135,141)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.43,0.71)
    isExecuted[item.ID] = {
            FAST_Night_On = false,
            FAST_Night_Off = true
        }
end)

Hook.Add("FAST_Sledge_Hammer_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(2,370,144,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.41,0.58)
    isExecuted[item.ID] = {
            FAST_Health_On = true,
            FAST_Health_Off = false
        }
end)

Hook.Add("FAST_Sledge_Hammer_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].FAST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(192,276,128,131)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.46,0.69)
    isExecuted[item.ID] = {
            FAST_Health_On = false,
            FAST_Health_Off = true
        }
end)

Hook.Add("GHOST_Origin", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(5,4,107,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.67)
    -- 移除战术设备时只清空当前头盔的执行状态
    isExecuted[item.ID] = nil
end)

Hook.Add("GHOST_Thermal_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Thermal_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(4,112,143,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.63)
    isExecuted[item.ID] = {
            GHOST_Thermal_On = true,
            GHOST_Thermal_Off = false
        }
end)

Hook.Add("GHOST_Thermal_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Thermal_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(180,8,136,125)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            GHOST_Thermal_On = false,
            GHOST_Thermal_Off = true
        }
end)

Hook.Add("GHOST_Night_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Night_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.nightSound.turnOn, item.WorldPosition, WEAR_CONFIG.Sound.nightSound.gain, WEAR_CONFIG.Sound.nightSound.range, WEAR_CONFIG.Sound.nightSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(6,229,140,99)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.42,0.66)
    isExecuted[item.ID] = {
            GHOST_Night_On = true,
            GHOST_Night_Off = false
        }
end)

Hook.Add("GHOST_Night_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Night_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(334,18,161,115)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.38,0.7)
    isExecuted[item.ID] = {
            GHOST_Night_On = false,
            GHOST_Night_Off = true
        }
end)

Hook.Add("GHOST_Health_On", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Health_On then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(12,343,127,98)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.5,0.65)
    isExecuted[item.ID] = {
            GHOST_Health_On = true,
            GHOST_Health_Off = false
        }
end)

Hook.Add("GHOST_Health_Off", function(_, _, item)
    if isExecuted[item.ID] and isExecuted[item.ID].GHOST_Health_Off then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(179,154,135,111)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.45,0.7)
    isExecuted[item.ID] = {
            GHOST_Health_On = false,
            GHOST_Health_Off = true
        }
end)

Hook.Add("ALTYN_Origin_Lua", function(_, _, item)
    if not isExecuted[item.ID] then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
        SoundPlayer.PlaySound(WEAR_CONFIG.Sound.CloseSound.sound, item.WorldPosition, WEAR_CONFIG.Sound.CloseSound.gain, WEAR_CONFIG.Sound.CloseSound.range, WEAR_CONFIG.Sound.CloseSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(9,6,128,108)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.52,0.59)
    isExecuted[item.ID] = false
end)

Hook.Add("ALTYN_Open_Lua", function(_, _, item)
    if isExecuted[item.ID] then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.OpenSound.sound, item.WorldPosition, WEAR_CONFIG.Sound.OpenSound.gain, WEAR_CONFIG.Sound.OpenSound.range, WEAR_CONFIG.Sound.OpenSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(9,118,140,121)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.52,0.63)
    isExecuted[item.ID] = true
end)

Hook.Add("MASKA_Origin_Lua", function(_, _, item)
    if not isExecuted[item.ID] then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
        SoundPlayer.PlaySound(WEAR_CONFIG.Sound.CloseSound.sound, item.WorldPosition, WEAR_CONFIG.Sound.CloseSound.gain, WEAR_CONFIG.Sound.CloseSound.range, WEAR_CONFIG.Sound.CloseSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(6,4,101,111)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.55,0.59)
    isExecuted[item.ID] = false
end)

Hook.Add("MASKA_Open_Lua", function(_, _, item)
    if isExecuted[item.ID] then return end
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    SoundPlayer.PlaySound(WEAR_CONFIG.Sound.OpenSound.sound, item.WorldPosition, WEAR_CONFIG.Sound.OpenSound.gain, WEAR_CONFIG.Sound.OpenSound.range, WEAR_CONFIG.Sound.OpenSound.frequencyMultiplier)
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(6,129,112,115)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.52,0.63)
    isExecuted[item.ID] = true
end)


-- 武器类贴图修改
Hook.Add("SaintOriginSprite", "SaintOrigin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(28,13,499,151)
end)

Hook.Add("SaintOpenLidSprite", "SaintOpenLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(42,201,486,179)
end)

Hook.Add("SaintReloadSprite", "SaintReload", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(27,432,558,179)
end)

Hook.Add("6P41OriginSprite", "6P41Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,9,607,160)
end)

Hook.Add("6P41OpenTheLidSprite", "6P41OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,192,607,242)
end)

Hook.Add("6P41PutOnMagSprite", "6P41PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,458,607,281)
end)

Hook.Add("6P41PutOnAmmoSprite", "6P41PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,775,607,281)
end)

Hook.Add("6P41CloseTheLidSprite", "6P41CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,1126,607,153)
end)

Hook.Add("M60OriginSprite", "M60Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,4,460,136)
end)

Hook.Add("M60OpenTheLidSprite", "M60OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(510,21,460,223)
end)

Hook.Add("M60PutOnMagSprite", "M60PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,171,460,223)
end)

Hook.Add("M60PutOnAmmoSprite", "M60PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,419,460,223)
end)

Hook.Add("M60CloseTheLidSprite", "M60CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,657,460,136)
end)

Hook.Add("M249OriginSprite", "M249Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,3,426,126)
end)

Hook.Add("M249OpenTheLidSprite", "M249OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,142,426,194)
end)

Hook.Add("M249PutOnMagSprite", "M249PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,349,426,202)
end)

Hook.Add("M249PutOnAmmoSprite", "M249PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,561,426,202)
end)

Hook.Add("M249CloseTheLidSprite", "M249CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,782,426,126)
end)

Hook.Add("MG42OriginSprite", "MG42Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,3,471,90)
end)

Hook.Add("MG42OpenTheLidSprite", "MG42OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,104,471,189)
end)

Hook.Add("MG42PutOnMagSprite", "MG42PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,301,471,199)
end)

Hook.Add("MG42PutOnAmmoSprite", "MG42PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,511,471,199)
end)

Hook.Add("MG42CloseTheLidSprite", "MG42CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,729,471,90)
end)

Hook.Add("PKPOriginSprite", "PKPOrigin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,6,492,94)
end)

Hook.Add("PKPOpenTheLidSprite", "PKPOpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,115,492,204)
end)

Hook.Add("PKPPutOnMagSprite", "PKPPutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,329,492,226)
end)

Hook.Add("PKPPutOnAmmoSprite", "PKPPutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,588,492,227)
end)

Hook.Add("PKPCloseTheLidSprite", "PKPCloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,874,492,94)
end)

Hook.Add("RM338OriginSprite", "RM338Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,7,674,126)
end)

Hook.Add("RM338OpenTheLidSprite", "RM338OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,144,674,223)
end)

Hook.Add("RM338PutOnMagSprite", "RM338PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,380,674,232)
end)

Hook.Add("RM338PutOnAmmoSprite", "RM338PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,616,674,232)
end)

Hook.Add("RM338CloseTheLidSprite", "RM338CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,874,674,126)
end)

Hook.Add("56BANBoltOutSprite", "56BANBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(703,817,464,84)
end)

Hook.Add("56BANBoltInSprite", "56BANBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(703,717,464,84)
end)

Hook.Add("56BANBrokenIcon", "56BANBrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("AWMBoltOutSprite", "AWMBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(22,148,737,132)
end)

Hook.Add("AWMBoltInSprite", "AWMBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(22,-9,737,132)
end)

Hook.Add("FN49BoltOutSprite", "FN49BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(1207,207,550,94)
end)

Hook.Add("FN49BoltInSprite", "FN49BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(1207,106,550,94)
end)

Hook.Add("FN49BrokenIcon", "FN49BrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("GEW43BoltOutSprite", "GEW43BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(1209,407,599,90)
end)

Hook.Add("GEW43BoltInSprite", "GEW43BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(1209,316,599,90)
end)

Hook.Add("GEW43BrokenIcon", "GEW43BrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("KAR98KBoltOutSprite", "KAR98KBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(636,101,525,90)
end)

Hook.Add("KAR98KBoltInSprite", "KAR98KBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(636,10,525,84)
end)

Hook.Add("KAR98KBrokenIcon", "KAR98KBrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("LEEBoltOutSprite", "LEEBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,534,576,120)
end)

Hook.Add("LEEBoltInSprite", "LEEBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,429,576,108)
end)

Hook.Add("M700BoltOutSprite", "M700BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,710,602,121)
end)

Hook.Add("M700BoltInSprite", "M700BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,587,602,121)
end)

Hook.Add("M1903BoltOutSprite", "M1903BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,318,556,106)
end)

Hook.Add("M1903BoltInSprite", "M1903BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,211,556,106)
end)

Hook.Add("MK22BoltOutSprite", "MK22BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(13,187,689,113)
end)

Hook.Add("MK22BoltInSprite", "MK22BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(13,6,689,113)
end)

Hook.Add("MOSINBoltOutSprite", "MOSINBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,100,576,96)
end)

Hook.Add("MOSINBoltInSprite", "MOSINBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,11,576,87)
end)

Hook.Add("R93BoltOutSprite", "R93BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(777,171,632,129)
end)

Hook.Add("R93BoltInSprite", "R93BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(777,17,632,129)
end)

Hook.Add("SKSBoltOutSprite", "SKSBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(693,610,469,70)
end)

Hook.Add("SKSBoltInSprite", "SKSBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(642,517,469,70)
end)

Hook.Add("SKSBrokenIcon", "SKSBrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("SV98BoltOutSprite", "SV98BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(21,463,639,124)
end)

Hook.Add("SV98BoltInSprite", "SV98BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(21,325,639,124)
end)

Hook.Add("TYPE_38BoltOutSprite", "TYPE_38BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(15,772,649,118)
end)

Hook.Add("TYPE_38BoltInSprite", "TYPE_38BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(15,664,649,92)
end)

Hook.Add("TYPE_38BrokenIcon", "TYPE_38BrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)

Hook.Add("ZHONGZHENGBoltOutSprite", "ZHONGZHENGBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(635,307,525,93)
end)

Hook.Add("ZHONGZHENGBoltInSprite", "ZHONGZHENGBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(635,206,525,87)
end)

Hook.Add("ZHONGZHENGBrokenIcon", "ZHONGZHENGBrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(561,160,19,68)
    item.Prefab.InventoryIcon.Depth = 0.65
end)
-- 盾牌类贴图修改
Hook.Add("DeepMobileShieldWithDraw", "ShieldWithDraw", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(7,317,78,281)
end)

Hook.Add("DeepMobileShieldExpand", "ShieldExpand", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(7,4,78,281)
end)
-- 衣服类贴图修改
Hook.Add("MarkSuit_MaskOn", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(422,2,81,88)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.62,0.55)
    -- 移除战术设备时应当清空所有的执行状态
    for _ , executed in pairs(isExecuted) do
        if type(executed) == "table" then
            for i, _ in pairs(executed) do
                executed[i] = false
            end
        end
    end
end)

Hook.Add("MarkSuit_MaskOff", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(422,94,81,88)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.59,0.55)
    -- 移除战术设备时应当清空所有的执行状态
    for _ , executed in pairs(isExecuted) do
        if type(executed) == "table" then
            for i, _ in pairs(executed) do
                executed[i] = false
            end
        end
    end
end)
