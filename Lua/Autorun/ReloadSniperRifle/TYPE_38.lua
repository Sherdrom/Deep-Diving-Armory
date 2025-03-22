if SERVER then return end

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