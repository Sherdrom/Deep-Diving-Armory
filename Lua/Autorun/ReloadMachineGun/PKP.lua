if SERVER then return end

Hook.Add("PKPOriginSprite", "PKPOrigin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,6,492,94)
end)

Hook.Add("PKPOpenTheLidSprite", "PKPOpenTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,115,492,204)
end)

Hook.Add("PKPPutOnMagSprite", "PKPPutOnMag", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(10,329,492,226)
end)

Hook.Add("PKPPutOnAmmoSprite", "PKPPutOnAmmo", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,588,492,227)
end)

Hook.Add("PKPCloseTheLidSprite", "PKPCloseTheLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(20,874,492,94)
end)

