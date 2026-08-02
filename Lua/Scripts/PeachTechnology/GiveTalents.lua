if not SERVER and Game.IsMultiplayer then return end

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

local function giveTalent(item, character)
    if not character or character.Removed or character.TeamID ~= CharacterTeamType.Team1
        or not item or not item.Prefab or not item.Prefab.ContentPackage
        or item.Prefab.ContentPackage.Name ~= "Deep-Diving-Armory"
        or not item.HasTag("weapon")
        or character:HasTalent(TALENT_ID) then return end

    talentPrefab = talentPrefab or findTalent()
    if talentPrefab then character:GiveTalent(talentPrefab) end
end

Hook.Patch(
    "GiveTalents.Equip",
    "Barotrauma.Item",
    "Equip",
    { "Barotrauma.Character" },
    function(item, ptable) giveTalent(item, ptable["character"]) end,
    Hook.HookMethodType.After
)
