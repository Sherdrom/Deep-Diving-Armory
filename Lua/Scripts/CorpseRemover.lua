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

-- 创建延迟删除函数
local function DelayedDespawn(character)
    Timer.Wait(function()
        if character ~= nil and not character.Removed then
            character.EnableDespawn = true
            character.Despawn()
        end
    end, 30000) -- 30000毫秒 = 30秒
end

Hook.Add("character.death", "Deep_CR", function(c)
    if not forceremove then forceremove = false end
    if c.Removed then return end
    
    -- 安全地检查 CauseOfDeath
    local causeOfDeathType = nil
    if c.CauseOfDeath ~= nil then
        causeOfDeathType = c.CauseOfDeath.Type
    end
    
    -- 如果是队友且不在战役中，或者满足其他条件，则不删除
    if      (not forceremove)
        and (
               (causeOfDeathType == CauseOfDeathType.Disconnected and GameMain.GameSession.Campaign ~= nil )
            or causeOfDeathType == CauseOfDeathType.Unknown
            or c.IsHuskInfected
            or (not c.IsHuman)
            or (c.TeamID == CharacterTeamType.Team1 and GameMain.GameSession.Campaign ~= nil)
        ) then
        return
    end
    
    -- 使用延迟删除而不是立即删除
    DelayedDespawn(c)
end)