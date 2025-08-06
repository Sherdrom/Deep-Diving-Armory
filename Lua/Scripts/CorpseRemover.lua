local forceremove = false

Game.AddCommand("EnableForceCorpseRemove", "Force ALL characters to remove after death in 5s.", function()
    forceremove = true
end, nil, false)
Game.AddCommand("DisableForceCorpseRemove", "Only Human will remove after death in 5s", function()
    forceremove = false
end, nil, false)
Game.AddCommand("RemoveAllCorpses", "Force remove all corpses immediately", function()
    for __,character in pairs(Character.CharacterList) do
        if character.isDead then character.DespawnNow(true) end
    end
end, nil, false)


Hook.Add("character.death", "Deep_CR_AddtoList", function(character)
    if (not character.IsHuman) and (not forceremove) then return end
    Timer.Wait(function() character.DespawnNow(true) end,5000)
end)