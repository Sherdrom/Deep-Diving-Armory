Hook.Add("Deep_NotLuaMissing", "Deep_NotLuaMissing",
    function(effect, deltaTime, item, targets, worldPosition)
        Timer.Wait(function()
            local Character = targets[1]
            local CharacterHealth = Character.CharacterHealth
            if CharacterHealth.GetAfflictionStrengthByIdentifier("deep_missing_Lua", true) > 0 then
                CharacterHealth.ReduceAfflictionOnAllLimbs("deep_missing_Lua", 1, nil, nil)
            end
        end, 50)
    end
)