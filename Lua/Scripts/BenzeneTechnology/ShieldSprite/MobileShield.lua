if SERVER then return end


Hook.Add("DeepMobileShieldWithDraw", "ShieldWithDraw", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(7,317,78,281)
end)

Hook.Add("DeepMobileShieldExpand", "ShieldExpand", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(7,4,78,281)
end)
