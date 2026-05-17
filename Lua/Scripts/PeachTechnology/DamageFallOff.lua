-- 伤害衰减脚本 - 多套衰减配置版本
local cfg = {
    enabled = true,
    showInConsole = false,
    debugMode = false,
    damageFalloffEnabled = true,
}

local falloffProfiles = {
    ["deep_damage_fall_off_600_1200_detect"] = {
        falloffStartDistance = 600,
        falloffEndDistance = 1200,
        minDamageMultiplier = 0.05
    },
    ["deep_damage_fall_off_1500_2300_detect"] = {
        falloffStartDistance = 1500,
        falloffEndDistance = 2300,
        minDamageMultiplier = 0.05
    },
}

local pendingFalloff = {}
local RANGED_THRESHOLD = 150

local function debugPrint(...)
    if not cfg.debugMode then return end
    print("[DistanceCalculator]", ...)
end

local function calcDistance(pos1, pos2)
    if pos1 == nil or pos2 == nil then return 0 end
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    return math.sqrt(dx * dx + dy * dy)
end

local function calcFalloffMultiplier(distance, profile)
    if not cfg.damageFalloffEnabled then return 1.0 end
    if distance <= profile.falloffStartDistance then return 1.0 end
    if distance >= profile.falloffEndDistance then return profile.minDamageMultiplier end

    local falloffRange = profile.falloffEndDistance - profile.falloffStartDistance
    local currentFalloff = distance - profile.falloffStartDistance
    local falloffRatio = currentFalloff / falloffRange
    return 1.0 - (falloffRatio * (1.0 - profile.minDamageMultiplier))
end

local function detectFalloff(attacker)
    if attacker == nil or attacker.CharacterHealth == nil then return nil, nil end

    for affName, profile in pairs(falloffProfiles) do
        local affliction = attacker.CharacterHealth.GetAffliction(affName)
        if affliction ~= nil then
            local strength = affliction.Strength
            if strength > 0.5 then
                debugPrint(string.format("Match: %s (strength=%.3f)", tostring(affName), strength))
                return affName, profile
            end
        end
    end

    if cfg.debugMode then
        local names = {}
        for name, _ in pairs(falloffProfiles) do
            names[#names + 1] = tostring(name)
        end
        debugPrint("No match. Checked: " .. table.concat(names, ", "))
    end

    return nil, nil
end

local function getAllAffsDebug(attacker)
    if attacker == nil or attacker.CharacterHealth == nil then return "" end

    local parts = {}
    for affName, _ in pairs(falloffProfiles) do
        local aff = attacker.CharacterHealth.GetAffliction(affName)
        if aff ~= nil then
            parts[#parts + 1] = string.format("%s=%.2f", tostring(affName), aff.Strength or 0)
        else
            parts[#parts + 1] = tostring(affName) .. "=none"
        end
    end
    return table.concat(parts, " | ")
end

Hook.Add("character.damageLimb", "DistanceCalculator.OnDamageLimb",
function(character, worldPosition, hitLimb, afflictions, stun, playSound, attackImpulse, attacker, damageMultiplier, allowStacking, penetration, shouldImplode)
    if not cfg.enabled then return nil end
    if attacker == nil then return nil end

    local attackerPos = attacker.WorldPosition
    if attackerPos == nil then return nil end

    local targetPos
    if character ~= nil then
        targetPos = character.WorldPosition
    elseif hitLimb ~= nil and LuaUserData.HasMember(hitLimb, "character") then
        targetPos = hitLimb.character.WorldPosition
    end

    if targetPos == nil then return nil end

    local distanceCm = calcDistance(attackerPos, targetPos)
    local isRanged = distanceCm > RANGED_THRESHOLD
    local matchedName, matchedProfile = detectFalloff(attacker)
    local hasBurn = (matchedProfile ~= nil)

    if cfg.showInConsole then
        local attackerName = tostring(attacker.Name or "?")
        local targetName = character and tostring(character.Name or "?") or "?"
        local msg = string.format("[dist] %s(%.0f,%.0f)->%s(%.0f,%.0f) | %.0fcm | %s",
            attackerName, attackerPos.X, attackerPos.Y,
            targetName, targetPos.X, targetPos.Y,
            distanceCm, isRanged and "ranged" or "melee")

        if hasBurn then
            msg = msg .. string.format(" | %s [%.0f-%.0fcm min%.0f%%]",
                tostring(matchedName),
                matchedProfile.falloffStartDistance,
                matchedProfile.falloffEndDistance,
                matchedProfile.minDamageMultiplier * 100)

            if isRanged then
                local fm = calcFalloffMultiplier(distanceCm, matchedProfile)
                if fm < 1.0 then
                    msg = msg .. string.format(" | dmg:%.0f%%", fm * 100)
                end
            end
        else
            local affs = getAllAffsDebug(attacker)
            if affs ~= "" then
                msg = msg .. " | " .. affs
            end
        end
        if not hasBurn then
            msg = msg .. " | no falloff"
        end
        print(msg)
    end

    local falloffMultiplier = 1.0
    if isRanged and hasBurn then
        falloffMultiplier = calcFalloffMultiplier(distanceCm, matchedProfile)
    end

    if falloffMultiplier < 1.0 then
        local charId = tostring(character.ID or "")
        pendingFalloff[charId] = {
            multiplier = falloffMultiplier,
            time = os.time()
        }
        debugPrint(string.format("Stored falloff: %s, multiplier=%.2f", charId, falloffMultiplier))
    end
end)

Hook.Patch("Barotrauma.CharacterHealth", "ApplyDamage",
function(instance, ptable)
    if not cfg.enabled or not cfg.damageFalloffEnabled then return end

    local attackResult = ptable["attackResult"]
    if attackResult == nil then return end

    local afflictions = attackResult.Afflictions
    if afflictions == nil then return end

    local character = instance.Character
    if character == nil then return end

    local charId = tostring(character.ID or "")
    local data = pendingFalloff[charId]
    if data == nil then return end

    if os.time() - data.time > 5 then
        pendingFalloff[charId] = nil
        return
    end

    local multiplier = data.multiplier
    for _, affliction in ipairs(afflictions) do
        if affliction ~= nil then
            affliction.Strength = affliction.Strength * multiplier
        end
    end

    debugPrint(string.format("Applied falloff: %s, multiplier=%.2f", charId, multiplier))
    pendingFalloff[charId] = nil
end, Hook.HookMethodType.Before)

local cleanupCounter = 0
Hook.Add("think", "DistanceCalculator.Cleanup", function()
    cleanupCounter = cleanupCounter + 1
    if cleanupCounter < 60 then return end
    cleanupCounter = 0

    if not next(pendingFalloff) then return end

    local now = os.time()
    local expired = {}
    for id, data in pairs(pendingFalloff) do
        if now - data.time > 10 then
            expired[#expired + 1] = id
        end
    end
    for _, id in ipairs(expired) do
        pendingFalloff[id] = nil
    end
end)

Hook.Add("chatMessage", "DistanceCalculator.Commands", function(message, client)
    if not message:startsWith("/distance") then return end

    local args = {}
    for arg in message:gmatch("%S+") do
        args[#args + 1] = arg
    end

    if #args < 2 then
        return true, "Usage: /distance [on|off|status|console|falloff|falloffon|falloffoff|profiles|setstart|setend|setmin]"
    end

    local cmd = args[2]:lower()

    if cmd == "on" then
        cfg.enabled = true
        return true, "Enabled"
    elseif cmd == "off" then
        cfg.enabled = false
        return true, "Disabled"
    elseif cmd == "debug" then
        cfg.debugMode = not cfg.debugMode
        cfg.showInConsole = cfg.debugMode
        return true, string.format("Debug: %s (console: %s)",
            cfg.debugMode and "on" or "off", cfg.showInConsole and "on" or "off")
    elseif cmd == "status" then
        local count = 0
        for _ in pairs(falloffProfiles) do count = count + 1 end
        local status = string.format("Enabled: %s | Console: %s | Falloff: %s | Profiles: %d",
            cfg.enabled and "yes" or "no",
            cfg.showInConsole and "yes" or "no",
            cfg.damageFalloffEnabled and "yes" or "no", count)
        local profileList = ""
        for name, profile in pairs(falloffProfiles) do
            profileList = profileList .. string.format("\n  %s [%.0f-%.0fcm, min%.0f%%]",
                tostring(name), profile.falloffStartDistance, profile.falloffEndDistance,
                profile.minDamageMultiplier * 100)
        end
        return true, status .. profileList
    elseif cmd == "console" then
        cfg.showInConsole = not cfg.showInConsole
        return true, "Console: " .. (cfg.showInConsole and "on" or "off")
    elseif cmd == "falloffon" then
        cfg.damageFalloffEnabled = true
        return true, "Falloff enabled"
    elseif cmd == "falloffoff" then
        cfg.damageFalloffEnabled = false
        return true, "Falloff disabled"
    elseif cmd == "falloff" then
        cfg.damageFalloffEnabled = not cfg.damageFalloffEnabled
        return true, "Falloff: " .. (cfg.damageFalloffEnabled and "on" or "off")
    elseif cmd == "profiles" then
        local count = 0
        local msg = ""
        for name, profile in pairs(falloffProfiles) do
            count = count + 1
            msg = msg .. string.format("\n  [%s] start:%.0fcm end:%.0fcm min:%.2f(%.0f%%)",
                tostring(name), profile.falloffStartDistance, profile.falloffEndDistance,
                profile.minDamageMultiplier, profile.minDamageMultiplier * 100)
        end
        return true, string.format("%d profiles:%s", count, msg)
    elseif cmd == "setstart" and #args >= 3 then
        local val = tonumber(args[3])
        if val == nil then return true, "Error: need a number" end
        local first = next(falloffProfiles)
        if first then
            falloffProfiles[first].falloffStartDistance = val
            return true, string.format("Set start to %.0f (%s)", val, first)
        else
            return true, "Error: no profiles"
        end
    elseif cmd == "setend" and #args >= 3 then
        local val = tonumber(args[3])
        if val == nil then return true, "Error: need a number" end
        local first = next(falloffProfiles)
        if first then
            falloffProfiles[first].falloffEndDistance = val
            return true, string.format("Set end to %.0f (%s)", val, first)
        else
            return true, "Error: no profiles"
        end
    elseif cmd == "setmin" and #args >= 3 then
        local val = tonumber(args[3])
        if val == nil then return true, "Error: need a number" end
        if val < 0 then val = 0 elseif val > 1 then val = 1 end
        local first = next(falloffProfiles)
        if first then
            falloffProfiles[first].minDamageMultiplier = val
            return true, string.format("Set min to %.2f (%.0f%%) (%s)", val, val * 100, first)
        else
            return true, "Error: no profiles"
        end
    end

    return true, string.format("Unknown: %s", cmd)
end)