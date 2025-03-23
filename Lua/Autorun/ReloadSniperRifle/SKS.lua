if SERVER then return end

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