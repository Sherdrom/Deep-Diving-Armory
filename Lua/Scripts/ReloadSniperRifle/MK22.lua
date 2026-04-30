if SERVER then return end

Hook.Add("MK22BoltOutSprite", "MK22BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(13,187,689,113)
end)

Hook.Add("MK22BoltInSprite", "MK22BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(13,6,689,113)
end)