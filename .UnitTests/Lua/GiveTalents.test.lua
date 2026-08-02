local events, patches = {}, {}

SERVER = true
CharacterTeamType = { None = 0, Team1 = 1, Team2 = 2 }
Hook = { HookMethodType = { After = "After" } }
function Hook.Add(name, _, callback) events[name] = callback end
function Hook.Patch(_, className, methodName, parameterTypes, callback, patchType)
    assert(className == "Barotrauma.Character" and methodName == "set_TeamID")
    assert(parameterTypes[1] == "Barotrauma.CharacterTeamType")
    assert(patchType == Hook.HookMethodType.After)
    patches[className .. "." .. methodName] = callback
end

local talent = {}
TalentPrefab = { TalentPrefabs = { deep_talent_all = talent } }

local function makeCharacter(team)
    local character = { TeamID = team, talents = {}, giveCalls = 0 }
    function character:GiveTalent(prefab)
        self.giveCalls = self.giveCalls + 1
        if self.talents[prefab] then return false end
        self.talents[prefab] = true
        return true
    end
    return character
end

local crew = makeCharacter(CharacterTeamType.Team1)
local enemy = makeCharacter(CharacterTeamType.Team2)
Character = { CharacterList = { crew, enemy } }

dofile("Lua/Scripts/PeachTechnology/GiveTalents.lua")
assert(events.think == nil, "GiveTalents still registered a polling hook")

events.loaded()
assert(crew.talents[talent] and enemy.giveCalls == 0, "loaded scan granted the wrong characters")

local spawnedCrew = makeCharacter(CharacterTeamType.Team1)
events["character.created"](spawnedCrew)
assert(spawnedCrew.talents[talent], "created Team1 character did not receive the talent")

local pendingCrew = makeCharacter(CharacterTeamType.None)
events["character.created"](pendingCrew)
assert(pendingCrew.giveCalls == 0, "unassigned character received the talent")
pendingCrew.TeamID = CharacterTeamType.Team1
patches["Barotrauma.Character.set_TeamID"](pendingCrew)
assert(pendingCrew.talents[talent], "Team1 assignment did not grant the talent")

local roundCrew = makeCharacter(CharacterTeamType.Team1)
Character.CharacterList = { roundCrew }
events.roundStart()
assert(roundCrew.talents[talent], "round-start recovery did not grant the talent")

print("GiveTalents event check OK")
