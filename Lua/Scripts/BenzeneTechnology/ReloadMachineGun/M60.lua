if SERVER then return end

Hook.Add("M60OriginSprite", "M60Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,4,460,136)
end)

Hook.Add("M60OpenTheLidSprite", "M60OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(510,21,460,223)
end)

Hook.Add("M60PutOnMagSprite", "M60PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,171,460,223)
end)

Hook.Add("M60PutOnAmmoSprite", "M60PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,419,460,223)
end)

Hook.Add("M60CloseTheLidSprite", "M60CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(8,657,460,136)
end)

