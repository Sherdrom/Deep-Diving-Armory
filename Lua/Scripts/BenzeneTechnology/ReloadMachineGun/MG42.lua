if SERVER then return end

Hook.Add("MG42OriginSprite", "MG42Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,3,471,90)
end)

Hook.Add("MG42OpenTheLidSprite", "MG42OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,104,471,189)
end)

Hook.Add("MG42PutOnMagSprite", "MG42PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,301,471,199)
end)

Hook.Add("MG42PutOnAmmoSprite", "MG42PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,511,471,199)
end)

Hook.Add("MG42CloseTheLidSprite", "MG42CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,729,471,90)
end)

