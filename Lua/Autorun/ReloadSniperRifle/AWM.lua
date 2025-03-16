if SERVER then return end

Hook.Add("AWMBoltOutSprite", "AWMBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(22,148,737,132)
end)

Hook.Add("AWMBoltInSprite", "AWMBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(22,-9,737,132)
end)