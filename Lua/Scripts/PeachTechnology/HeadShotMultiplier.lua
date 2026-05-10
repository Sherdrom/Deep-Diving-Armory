local DEBUG = false

local function log(...)
    if DEBUG then
        print("[HeadShotMultiplier]", ...)
    end
end

local function parseHeadshotMultipliers(tagsStr)
    if tagsStr == nil or tagsStr == "" then
        return {}
    end
    local multipliers = {}
    for tagStr in string.gmatch(tagsStr, "[^,]+") do
        tagStr = string.gsub(tagStr, "^%s*(.-)%s*$", "%1")
        local affType, multStr = string.match(tagStr, "^deep_headshot_(.+)_([%d%.]+)$")
        if affType and multStr then
            local mult = tonumber(multStr)
            if mult and mult > 0 then
                multipliers[affType] = mult
                log("解析标签:", tagStr, "->", affType, "x" .. mult)
            end
        end
    end
    return multipliers
end

local pendingHeadshot = {}

Hook.Patch("Barotrauma.Character", "ApplyAttack",
{
    "Barotrauma.Character",
    "Microsoft.Xna.Framework.Vector2",
    "Barotrauma.Attack",
    "System.Single",
    "Microsoft.Xna.Framework.Vector2",
    "System.Boolean",
    "Barotrauma.Limb",
    "System.Single"
},
function(instance, p)
    pendingHeadshot[instance] = nil

    local targetLimb = p["targetLimb"]
    if targetLimb == nil or targetLimb.type ~= LimbType.Head then
        return
    end

    log("=== ApplyAttack 命中头部 ===")

    local attack = p["attack"]
    local sourceItem = attack.SourceItem
    log("武器SourceItem:", sourceItem ~= nil and tostring(sourceItem) or "nil")

    if sourceItem == nil then
        log("-> 无SourceItem, 跳过")
        return
    end

    local multipliers = parseHeadshotMultipliers(sourceItem.Tags)
    if next(multipliers) == nil then
        log("-> 武器无deep_headshot_*标签, 跳过")
        return
    end

    pendingHeadshot[instance] = multipliers
    log("-> 已记录倍率配置")
end, Hook.HookMethodType.Before)

local bypassResistanceId = nil

Hook.Patch("Barotrauma.CharacterHealth", "AddLimbAffliction",
{
    "Barotrauma.Limb",
    "Barotrauma.Affliction",
    "System.Boolean",
    "System.Boolean"
},
function(instance, p)
    local character = instance.Character
    local multipliers = pendingHeadshot[character]
    if multipliers == nil then
        return
    end

    local limb = p["limb"]
    if limb == nil then
        return
    end

    local affliction = p["newAffliction"]
    local affId = tostring(affliction.Prefab.Identifier)
    log("AddLimbAffliction: " .. affId .. " strength=" .. tostring(affliction.Strength))

    local mult = multipliers[affId]
    if mult == nil then
        log("-> 此affliction无倍率, 跳过")
        return
    end

    multipliers[affId] = nil
    if next(multipliers) == nil then
        pendingHeadshot[character] = nil
    end

    local resistance = instance:GetResistance(affliction.Prefab, limb.type)
    local divisor = 1 - resistance
    log("抗性:" .. tostring(resistance) .. " divisor:" .. tostring(divisor))

    local oldStrength = affliction.Strength

    if divisor > 0.001 then
        affliction.Strength = oldStrength * mult / divisor
        log(">>> 倍率生效(补偿法)! " .. affId .. " x" .. mult
            .. " old:" .. tostring(oldStrength)
            .. " new:" .. tostring(affliction.Strength)
            .. " resistance:" .. tostring(resistance))
    else
        bypassResistanceId = affId
        affliction.Strength = oldStrength * mult
        log(">>> 倍率生效(抗性穿透)! " .. affId .. " x" .. mult
            .. " old:" .. tostring(oldStrength)
            .. " new:" .. tostring(affliction.Strength))
    end
end, Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.CharacterHealth", "GetResistance",
{
    "Barotrauma.AfflictionPrefab",
    "Barotrauma.LimbType"
},
function(instance, p)
    if bypassResistanceId ~= nil then
        local prefab = p["afflictionPrefab"]
        local prefabId = tostring(prefab.Identifier)
        log("GetResistance被调用: prefab=" .. prefabId .. " bypassId=" .. tostring(bypassResistanceId))
        if prefabId == bypassResistanceId then
            bypassResistanceId = nil
            log("-> 穿透抗性: 返回0")
            p.PreventExecution = true
            return 0
        end
    end
end, Hook.HookMethodType.Before)