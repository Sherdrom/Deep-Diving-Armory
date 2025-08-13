if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

-- 所有的OnUse Hook应该只执行一次，而不是一直执行
local isExecuted={}

Hook.Add("MarkSuit_MaskOn", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(422,2,81,88)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.62,0.5)
    -- 移除战术设备时应当清空所有的执行状态
    for _ , executed in pairs(isExecuted) do
        for i, _ in pairs(executed) do
            executed[i] = false
        end
    end
end)

Hook.Add("MarkSuit_MaskOff", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    if itemComponent.wearableSprites[1].Sprite == nil then return end
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(422,94,81,88)
    itemComponent.wearableSprites[1].Sprite.RelativeOrigin=Vector2(0.59,0.5)
    -- 移除战术设备时应当清空所有的执行状态
    for _ , executed in pairs(isExecuted) do
        for i, _ in pairs(executed) do
            executed[i] = false
        end
    end
end)