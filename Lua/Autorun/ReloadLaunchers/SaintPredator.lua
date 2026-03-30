if SERVER then return end

Hook.Add("SaintOriginSprite", "SaintOrigin", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(28,13,499,151)
end)

Hook.Add("SaintOpenLidSprite", "SaintOpenLid", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(42,201,486,179)
end)

Hook.Add("SaintReloadSprite", "SaintReload", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(27,432,558,179)
end)