if SERVER then return end

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