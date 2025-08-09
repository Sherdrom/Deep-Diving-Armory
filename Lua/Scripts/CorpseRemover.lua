local forceremove = false

Game.AddCommand("EnableForceCorpseRemove", "Force ALL characters to remove after death", function()
    forceremove = true
end, nil, false)
Game.AddCommand("DisableForceCorpseRemove", "Only Human will remove after death", function()
    forceremove = false
end, nil, false)
Game.AddCommand("RemoveAllCorpses", "Force remove all corpses immediately", function()
    for __,character in pairs(Character.CharacterList) do
        if character.isDead then 
            if character.Removed then return end
            character.EnableDespawn = true
            if character.Removed then return end
            character.DespawnNow(true) 
        end
    end
end, nil, false)


Hook.Add("character.death", "Deep_CR_AddtoList", function(c)
    if c.Removed then return end
    if (not c.IsHuman) and (not forceremove) then return end
    c.EnableDespawn = true
    if c.Removed then return end
    c.DespawnNow(true)
end)