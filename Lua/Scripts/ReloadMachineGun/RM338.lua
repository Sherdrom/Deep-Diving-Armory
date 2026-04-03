if SERVER then return end

Hook.Add("RM338OriginSprite", "RM338Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,7,674,126)
end)

Hook.Add("RM338OpenTheLidSprite", "RM338OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,144,674,223)
end)

Hook.Add("RM338PutOnMagSprite", "RM338PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,380,674,232)
end)

Hook.Add("RM338PutOnAmmoSprite", "RM338PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,616,674,232)
end)

Hook.Add("RM338CloseTheLidSprite", "RM338CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(9,874,674,126)
end)

