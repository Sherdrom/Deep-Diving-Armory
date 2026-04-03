if SERVER then return end

Hook.Add("MOSINBoltOutSprite", "MOSINBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,100,576,96)
end)

Hook.Add("MOSINBoltInSprite", "MOSINBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,11,576,87)
end)