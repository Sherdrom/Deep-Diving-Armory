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
            character.EnableDespawn = true
            character.DespawnNow(true) 
        end
    end
end, nil, false)


Hook.Add("character.death", "Deep_CR_AddtoList", function(c)
    if (not c.IsHuman) and (not forceremove) then return end
    c.EnableDespawn = true
    c.DespawnNow(true)
end)