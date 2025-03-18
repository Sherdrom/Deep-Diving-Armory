if SERVER then return end

Hook.Add("M1903BoltOutSprite", "M1903BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,318,556,106)
end)

Hook.Add("M1903BoltInSprite", "M1903BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(6,211,556,106)
end)