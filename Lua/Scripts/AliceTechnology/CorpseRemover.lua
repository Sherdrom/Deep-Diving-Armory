local forceremove = false

LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Character"], "Despawn")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.AICharacter"], "Despawn")

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
            character.Despawn()
        end
    end
end, nil, false)


Hook.Add("character.death", "Deep_CR", function(c)
    if c.Removed then return end
    if      (not forceremove)
        and (
               (c.CauseOfDeath.Type == CauseOfDeathType.Disconnected and Game.GameSession.Campaign ~= nil )
            --or c.CauseOfDeath.Type == CauseOfDeathType.Unknown
            or c.IsHuskInfected
            or (not c.IsHuman)
            or (c.TeamID == CharacterTeamType.Team1 and Game.GameSession.Campaign ~= nil)
        ) then
        return
    end
    c.EnableDespawn = true
    if c.Removed then return end
    Timer.Wait(function()
        if not c.Removed and c.IsDead then
            c.Despawn() 
        end
    end,30000)
end)