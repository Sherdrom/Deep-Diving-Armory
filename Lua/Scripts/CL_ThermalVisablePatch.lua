Hook.Add("roundStart", "Deep_TV", function()
    for character in Character.CharacterList do
        if not character.Inventory.FindItemByIdentifier("deep_thermal_interference",false) then return end
        character.Params.HideInThermalGoggles = true
    end
end)