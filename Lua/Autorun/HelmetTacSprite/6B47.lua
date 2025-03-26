if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Wearable"], "wearableSprites")

Hook.Add("6b47_thermal", function(_, _, item)
    local itemComponent = item.GetComponentString("Wearable")
    itemComponent.wearableSprites[1].Sprite.SourceRect=Rectangle(109,166,102,101)
end)
