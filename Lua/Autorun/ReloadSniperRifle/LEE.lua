if SERVER then return end

Hook.Add("LEEBoltOutSprite", "LEEBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,534,576,120)
end)

Hook.Add("LEEBoltInSprite", "LEEBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,429,576,108)
end)

Hook.Add("LEEBrokenIcon", "LEEBrokenIcon", function(_, _, item)
    item.Prefab.InventoryIcon.SourceRect = Rectangle(558,76,25,70)
    item.Prefab.InventoryIcon.Depth = 0.65
end)