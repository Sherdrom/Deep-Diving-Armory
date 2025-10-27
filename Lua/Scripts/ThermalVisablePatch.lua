Hook.Add("character.created", "Deep_TV", function(character)
    if not character then return end
    if not character.Inventory.FindItemByIdentifier("deep_thermal_interference",false) then return end
    character.Params.HideInThermalGoggles = true
end)