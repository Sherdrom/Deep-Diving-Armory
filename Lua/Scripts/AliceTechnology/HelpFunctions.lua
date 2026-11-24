Deep_Lua.HF = {
    clamp =  function(input,min,max)
        if input <= min then return min end
        if input >= max then return max end
        return input
    end,

    DoChance = function(probability)
        local probability = Deep_Lua.HF.clamp(probability,0,1) * 100
        if probability - math.random(1,100) >= 0 then return true end
        return false
    end,

    IsVirtualMagazine = function(item)
        return item.HasTag("deep_virtualmagazine") or item.HasTag("VCE_VirtualizedMagazine")
    end,

    Vector2Dir = function(vector)
	    return math.atan2(vector.Y, vector.X)
    end

}

-- Only the legacy press needs direct access to the VCE component.
if CSActive and (SERVER or not Game.IsMultiplayer) then
    local typeName = "VCE_VirtualizedMagazine.VirtualizedMagazine"
    if pcall(LuaUserData.RegisterType, typeName) then
        Deep_Lua.HF.VirtualMagazineType = typeName
    end
end
