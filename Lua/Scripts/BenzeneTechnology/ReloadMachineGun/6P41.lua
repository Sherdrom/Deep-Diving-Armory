if SERVER then return end

Hook.Add("6P41OriginSprite", "6P41Origin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,9,607,160)
end)

Hook.Add("6P41OpenTheLidSprite", "6P41OpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,192,607,242)
end)

Hook.Add("6P41PutOnMagSprite", "6P41PutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,458,607,281)
end)

Hook.Add("6P41PutOnAmmoSprite", "6P41PutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,775,607,281)
end)

Hook.Add("6P41CloseTheLidSprite", "6P41CloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(18,1126,607,153)
end)

