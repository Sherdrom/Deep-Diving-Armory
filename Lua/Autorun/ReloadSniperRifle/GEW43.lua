if SERVER then return end

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