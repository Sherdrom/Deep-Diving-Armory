if SERVER then return end

Hook.Add("R93BoltOutSprite", "R93BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(777,171,632,129)
end)

Hook.Add("R93BoltInSprite", "R93BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(777,17,632,129)
end)