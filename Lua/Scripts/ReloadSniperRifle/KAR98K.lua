if SERVER then return end

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