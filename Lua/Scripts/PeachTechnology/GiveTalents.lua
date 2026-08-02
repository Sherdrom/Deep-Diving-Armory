if not SERVER then return end

local TALENT_ID = "deep_talent_all"
local talentPrefab

local function findTalent()
    local prefabs = TalentPrefab.TalentPrefabs
    local prefab = prefabs[TALENT_ID]
    if prefab then return prefab end

    for id, candidate in pairs(prefabs) do
        if tostring(id) == TALENT_ID then return candidate end
    end
end

local function giveTalent(character)
    if not talentPrefab or not character or character.Removed then return end
    if character.TeamID == CharacterTeamType.Team1 then character:GiveTalent(talentPrefab) end
end

local function giveToExistingCharacters()
    talentPrefab = findTalent()
    if not talentPrefab then
        print("[GiveTalents] ERROR: talent not found " .. TALENT_ID)
        return
    end

    for _, character in pairs(Character.CharacterList) do giveTalent(character) end
end

Hook.Add("loaded", "GiveTalents.Loaded", giveToExistingCharacters)
Hook.Add("roundStart", "GiveTalents.RoundStart", giveToExistingCharacters)
Hook.Add("character.created", "GiveTalents.CharacterCreated", giveTalent)

Hook.Patch(
    "GiveTalents.TeamChanged",
    "Barotrauma.Character",
    "set_TeamID",
    { "Barotrauma.CharacterTeamType" },
    function(character) giveTalent(character) end,
    Hook.HookMethodType.After
)
