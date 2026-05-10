if SERVER then return end

Hook.Add("SV98BoltOutSprite", "SV98BoltOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(21,463,639,124)
end)

Hook.Add("SV98BoltInSprite", "SV98BoltIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(21,325,639,124)
end)