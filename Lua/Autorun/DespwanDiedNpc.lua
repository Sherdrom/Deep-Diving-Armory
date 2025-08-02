if not (Game.IsSingleplayer or SERVER) then return end

LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Character"], "Despawn")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.AICharacter"], "Despawn")

Hook.Add("character.death", "characterDeath", function(character)
   print(character.IsDead, character.CauseOfDeath.Type, CauseOfDeathType.Disconnected, character.SpeciesName)
   if (not character.IsDead or (character.CauseOfDeath.Type == CauseOfDeathType.Disconnected and GameMain.GameSession.Campaign ~= nil ) or (character.SpeciesName ~= CharacterPrefab.HumanSpeciesName) or (character.TeamID == CharacterTeamType.Team1)) then
       return
   end
   character.Despawn()
end)