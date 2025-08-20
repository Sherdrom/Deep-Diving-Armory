if SERVER then return end

Hook.Add("M700BoltOutSprite", "M700BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,710,602,121)
end)

Hook.Add("M700BoltInSprite", "M700BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,587,602,121)
end)