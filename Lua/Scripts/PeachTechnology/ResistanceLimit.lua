-- ============================================================
-- ResistanceLimit - Enemy job characters bypass affliction resistance
-- When a human with job deep_securityofficer_enemy or
-- deep_medicaldoctor_enemy attacks, the target's affliction
-- resistance is overridden.
--
-- CONFIG:
--   RESISTANCE_OVERRIDES = {
--       afflictionId = maxValue,    -- cap resistance at this value
--       afflictionType = maxValue,  -- affliction type also supported
--   }
--   Afflictions NOT listed in RESISTANCE_OVERRIDES remain unchanged
--   (original game resistance applies).
--   Example: gunshotwound = 0.5 means target's gunshotwound
--   resistance is capped at 0.5 when attacked by enemy jobs.
-- ============================================================

local ENEMY_JOB_IDS = {
    ["deep_securityofficer_enemy"] = true,
    ["deep_medicaldoctor_enemy"] = true,
}

-- ============================================================
-- Per-affliction resistance override values (max cap)
-- Keyed by affliction identifier or type (lowercase)
-- ============================================================

local RESISTANCE_OVERRIDES = {
     gunshotwound = 0.8,
    -- bleeding = 0.3,
    -- damage = 0.2,
}

local DEBUG = false

-- ============================================================
-- Attack depth counter (handles nested ApplyAttack calls)
-- ============================================================

local enemyAttackDepth = 0

-- ============================================================
-- Build lowercase lookup table for O(1) resistance override access
-- ============================================================

local resistanceOverrideLookup = {}
local overrideCount = 0

for key, maxVal in pairs(RESISTANCE_OVERRIDES) do
    if type(maxVal) == "number" and maxVal >= 0 then
        resistanceOverrideLookup[key:lower()] = maxVal
        overrideCount = overrideCount + 1
    end
end

local hasOverrides = overrideCount > 0

-- ============================================================
-- Helper: check if a character is a valid enemy-job attacker
-- ============================================================

local function IsEnemyJobAttacker(character)
    if character == nil then
        return false
    end
    if not character.IsHuman then
        return false
    end
    for jobId, _ in pairs(ENEMY_JOB_IDS) do
        if character:HasJob(jobId) then
            return true
        end
    end
    return false
end

-- ============================================================
-- Hook: Character.ApplyAttack Before
-- Detect enemy-job attackers and increment depth counter
-- ============================================================

Hook.Patch(
    "ResistanceLimit_ApplyAttack",
    "Barotrauma.Character",
    "ApplyAttack",
    {
        "Barotrauma.Character",
        "Microsoft.Xna.Framework.Vector2",
        "Barotrauma.Attack",
        "System.Single",
        "Microsoft.Xna.Framework.Vector2",
        "System.Boolean",
        "Barotrauma.Limb",
        "System.Single",
    },
    function(instance, ptable)
        local attacker = ptable["attacker"]
        if IsEnemyJobAttacker(attacker) then
            enemyAttackDepth = enemyAttackDepth + 1
            if DEBUG then
                print("[ResistanceLimit] enemy attack begin, depth=" .. enemyAttackDepth .. " attacker=" .. (attacker.Name or "?"))
            end
        end
    end,
    Hook.HookMethodType.Before
)

-- ============================================================
-- Hook: Character.ApplyAttack After
-- Decrement depth counter when attack completes
-- ============================================================

Hook.Patch(
    "ResistanceLimit_ApplyAttackAfter",
    "Barotrauma.Character",
    "ApplyAttack",
    {
        "Barotrauma.Character",
        "Microsoft.Xna.Framework.Vector2",
        "Barotrauma.Attack",
        "System.Single",
        "Microsoft.Xna.Framework.Vector2",
        "System.Boolean",
        "Barotrauma.Limb",
        "System.Single",
    },
    function(instance, ptable)
        if enemyAttackDepth > 0 then
            enemyAttackDepth = enemyAttackDepth - 1
            if DEBUG then
                print("[ResistanceLimit] enemy attack end, depth=" .. enemyAttackDepth)
            end
        end
    end,
    Hook.HookMethodType.After
)

-- ============================================================
-- Hook: CharacterHealth.GetResistance After
-- Override resistance when an enemy-job character is attacking.
-- If the affliction has a configured override, clamp to that max.
-- Otherwise, keep the original resistance unchanged.
-- ============================================================

Hook.Patch(
    "ResistanceLimit_GetResistance",
    "Barotrauma.CharacterHealth",
    "GetResistance",
    { "Barotrauma.AfflictionPrefab", "Barotrauma.LimbType" },
    function(instance, ptable)
        if enemyAttackDepth <= 0 then
            return
        end

        local value = ptable.ReturnValue
        if type(value) ~= "number" then
            return
        end
        if value == 0 then
            return
        end

        local prefab = ptable["afflictionPrefab"]
        if not prefab then
            return
        end

        local id = prefab.Identifier:ToString():lower()
        local affType = prefab.AfflictionType:ToString():lower()

        -- Determine the effective max cap from overrides
        local maxCap = nil
        if hasOverrides then
            local capById = resistanceOverrideLookup[id]
            local capByType = resistanceOverrideLookup[affType]
            if capById or capByType then
                -- Use the stricter (lower) cap if both id and type match
                maxCap = capById
                if capByType and (not maxCap or capByType < maxCap) then
                    maxCap = capByType
                end
            end
        end

        if not maxCap then
            -- No override configured: keep original resistance
            return
        end

        -- Clamp: resistance cannot exceed the configured max
        if value <= maxCap then
            return
        end

        if DEBUG then
            local label = id ~= "" and id or affType
            print("[ResistanceLimit] resistance override: " .. label .. " original=" .. tostring(value) .. " -> " .. maxCap)
        end

        -- Return clamped value directly; the LuaCs framework will convert
        -- it to the correct type (float) via DynValue.ToObject(typeof(float)),
        -- matching the game's GetResistance return type.
        return maxCap
    end,
    Hook.HookMethodType.After
)

-- ============================================================
-- Lifecycle hooks
-- ============================================================

Hook.Add("loaded", "ResistanceLimit.Loaded", function()
    if not DEBUG then return end
    local jobList = {}
    for jobId in pairs(ENEMY_JOB_IDS) do
        jobList[#jobList + 1] = jobId
    end
    print("[ResistanceLimit] loaded, enemy jobs: " .. table.concat(jobList, ", "))
    if hasOverrides then
        print("[ResistanceLimit] resistance overrides: " .. overrideCount .. " entries")
        for key, maxVal in pairs(resistanceOverrideLookup) do
            print("[ResistanceLimit]   " .. key .. " -> max " .. maxVal)
        end
    end
end)

Hook.Add("roundStart", "ResistanceLimit.RoundStart", function()
    enemyAttackDepth = 0
    if not DEBUG then return end
    print("[ResistanceLimit] roundStart, depth reset")
end)