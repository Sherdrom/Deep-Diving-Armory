if SERVER then return end

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