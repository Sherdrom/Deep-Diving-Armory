local events, patches = {}, {}

SERVER = true
CharacterTeamType = { None = 0, Team1 = 1, Team2 = 2 }
Hook = { HookMethodType = { After = "After" } }
function Hook.Add(name, _, callback) events[name] = callback end
function Hook.Patch(_, className, methodName, parameterTypes, callback, patchType)
    assert(className == "Barotrauma.Item" and methodName == "Equip")
    assert(parameterTypes[1] == "Barotrauma.Character")
    assert(patchType == Hook.HookMethodType.After)
    patches[className .. "." .. methodName] = callback
end

local talent = {}
TalentPrefab = { TalentPrefabs = { deep_talent_all = talent } }

local function makeCharacter(team)
    local character = { TeamID = team, talents = {}, giveCalls = 0 }
    function character:HasTalent(identifier) return self.talents[identifier] == true end
    function character:GiveTalent(prefab)
        self.giveCalls = self.giveCalls + 1
        self.talents.deep_talent_all = true
        return true
    end
    return character
end

local crew = makeCharacter(CharacterTeamType.Team1)
local enemy = makeCharacter(CharacterTeamType.Team2)

local function makeItem(packageName, isWeapon)
    return {
        Prefab = { ContentPackage = { Name = packageName } },
        HasTag = function(tag) return isWeapon and tag == "weapon" end,
    }
end

dofile("Lua/Scripts/PeachTechnology/GiveTalents.lua")
assert(next(events) == nil, "GiveTalents still registered scan or polling hooks")

local equip = patches["Barotrauma.Item.Equip"]
equip(makeItem("Vanilla", true), { character = crew })
equip(makeItem("Deep Diving Armory", false), { character = crew })
equip(makeItem("Deep Diving Armory", true), { character = enemy })
assert(crew.giveCalls == 0 and enemy.giveCalls == 0, "non-DDA weapon or enemy received the talent")

local ddaWeapon = makeItem("Deep-Diving-Armory", true)
equip(ddaWeapon, { character = crew })
equip(ddaWeapon, { character = crew })
assert(crew.talents.deep_talent_all and crew.giveCalls == 1,
    "DDA weapon equip did not grant exactly one talent")

print("GiveTalents event check OK")
