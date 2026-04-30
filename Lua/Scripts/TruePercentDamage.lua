local DEADLY_IDENTIFIERS = {
    Identifier("deep_headshot_deadly"),
    Identifier("deep_headshot_deadly_irresistible")
}

local function hasDeadlyAffliction(charHealth)
    for _, id in ipairs(DEADLY_IDENTIFIERS) do
        if charHealth:GetAffliction(id) ~= nil then
            return true
        end
    end
    return false
end

local function isHealing(affliction, charHealth)
    if charHealth == nil then return false end
    return affliction:GetVitalityDecrease(charHealth) < 0
end

Hook.Add("afflictionUpdate", "VCE_TruePercentDamage_Update", function(affliction, characterHealth, limb)
    if characterHealth == nil then return end
    if not hasDeadlyAffliction(characterHealth) then return end
    if not isHealing(affliction, characterHealth) then return end

    if affliction.Strength > 0 then
        affliction.Strength = 0
    end
end)

Hook.Add("character.applyAffliction", "VCE_TruePercentDamage_Block", function(charHealth, limbHealth, newAffliction, allowStacking)
    if charHealth == nil then return end
    if not hasDeadlyAffliction(charHealth) then return end
    if not isHealing(newAffliction, charHealth) then return end

    return true
end)
