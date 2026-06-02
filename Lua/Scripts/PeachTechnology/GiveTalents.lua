-- ============================================================
-- GiveTalents - 每隔一段时间自动给予 Team1 所有生物一个天赋
-- 修改下方的 CONFIG 即可自由配置间隔和天赋 identifier
-- ============================================================

-- 日志输出
local function dbgPrint(msg)
    print("[GiveTalents] " .. msg)
end

-- ============================================================
-- 配置（可自由修改）
-- ============================================================
local CONFIG = {
    interval = 5,                         -- 间隔秒数
    talentIdentifier = "deep_talent_all",  -- 天赋 identifier
    debug = false,                         -- 调试日志开关
}

local TAG = "[GiveTalents]"
local talentPrefab = nil
local lastTime = 0
local running = true

-- ============================================================
-- 日志辅助
-- ============================================================
local function log(msg)
    if CONFIG.debug then
        dbgPrint(msg)
    end
end

-- 第1步：脚本被加载的确认
log("STEP 1: Script file executing")

-- 第2步：确认全局变量可访问
log("STEP 2: Checking globals")
log("SERVER=" .. tostring(SERVER) .. " CLIENT=" .. tostring(CLIENT))
log("Character=" .. tostring(Character ~= nil) .. " TalentPrefab=" .. tostring(TalentPrefab ~= nil))
log("Timer.GetTime()=" .. tostring(Timer.GetTime()))

-- ============================================================
-- 尝试获取天赋 Prefab
-- ============================================================
local function tryGetTalentPrefab()
    local talentId = CONFIG.talentIdentifier
    local prefabs = TalentPrefab.TalentPrefabs

    log("Looking for talent: " .. talentId)
    log("TalentPrefabs type: " .. type(prefabs))

    local prefab = prefabs[talentId]
    if prefab then
        log("Talent found via string key: " .. talentId)
        return prefab
    end

    log("String key lookup failed, trying iteration")
    local count = 0
    for k, v in pairs(prefabs) do
        count = count + 1
        if tostring(k) == talentId then
            log("Talent found via iteration: " .. talentId)
            return v
        end
    end
    log("Iterated " .. count .. " talents, not found: " .. talentId)
    log("Talent not found: " .. talentId)
    return nil
end

-- ============================================================
-- 核心逻辑
-- ============================================================
local function giveTalentsToTeam1()
    if not talentPrefab then
        log("talentPrefab is nil, skip")
        return
    end

    local charList = Character.CharacterList
    local team1 = CharacterTeamType.Team1
    local totalChars = 0
    local team1Count = 0
    local givenCount = 0

    if CONFIG.debug then
        log("CharacterList type: " .. type(charList) .. " Team1 value: " .. tostring(team1))
    end

    for _, character in pairs(charList) do
        totalChars = totalChars + 1

        if CONFIG.debug then
            local name = character.Name or "?"
            log("Char: " .. name .. " TeamID=" .. tostring(character.TeamID) .. " IsHuman=" .. tostring(character.IsHuman))
        end

        if character.TeamID == team1 then
            team1Count = team1Count + 1
            if character:GiveTalent(talentPrefab) then
                givenCount = givenCount + 1
            end
        end
    end

    if CONFIG.debug then
        log("Tick: chars=" .. totalChars .. " team1=" .. team1Count .. " given=" .. givenCount)
    end
end

-- ============================================================
-- think hook
-- ============================================================
local thinkDebugCounter = 0

local function onThink()
    thinkDebugCounter = thinkDebugCounter + 1
    if CONFIG.debug and thinkDebugCounter % 60 == 1 then
        log("Think alive, running=" .. tostring(running) .. " side=" .. (SERVER and "Server" or "Client"))
    end

    if not running then
        return
    end

    local now = Timer.GetTime()
    if now - lastTime >= CONFIG.interval then
        lastTime = now
        giveTalentsToTeam1()
    end
end

-- ============================================================
-- 生命周期 hooks
-- ============================================================
log("STEP 3: Registering hooks")

log("Registering roundEnd hook")
Hook.Add("roundEnd", "GiveTalents.RoundEnd", function()
    if not SERVER then
        return
    end
    running = false
    talentPrefab = nil
    log("Round ended, timer stopped")
end)

log("Registering think hook")
Hook.Add("think", "GiveTalents.Think", onThink)

log("Registering loaded hook")
Hook.Add("loaded", "GiveTalents.Loaded", function()
    local side = ""
    if CLIENT then side = "Client" end
    if SERVER then side = side .. (side ~= "" and " " or "") .. "Server" end
    log("Loaded on " .. side .. ". Interval: " .. CONFIG.interval .. "s, Talent: " .. CONFIG.talentIdentifier)

    talentPrefab = tryGetTalentPrefab()
    if talentPrefab then
        lastTime = Timer.GetTime()
        log("Timer started, interval=" .. CONFIG.interval .. "s")
    else
        log("Talent not found in loaded hook, will retry in think")
    end
end)

log("STEP 4: Script fully loaded, ALL hooks registered")