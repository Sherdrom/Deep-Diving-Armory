if SERVER then return end

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