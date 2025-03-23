if SERVER then return end

Hook.Add("LEEBoltOutSprite", "LEEBoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,534,576,120)
end)

Hook.Add("LEEBoltInSprite", "LEEBoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,429,576,108)
end)