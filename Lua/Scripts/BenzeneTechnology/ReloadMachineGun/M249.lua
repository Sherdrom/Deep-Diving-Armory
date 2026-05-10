if SERVER then return end

Hook.Add("M249OriginSprite", "M249Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,3,426,126)
end)

Hook.Add("M249OpenTheLidSprite", "M249OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,142,426,194)
end)

Hook.Add("M249PutOnMagSprite", "M249PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,349,426,202)
end)

Hook.Add("M249PutOnAmmoSprite", "M249PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,561,426,202)
end)

Hook.Add("M249CloseTheLidSprite", "M249CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(17,782,426,126)
end)

