Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Core = Gunsmith.Core
local Stats = {}
Gunsmith.Stats = Stats

Stats.Keys = {
    "weight",
    "ergonomics",
    "recoilControl",
    "spreadReduction",
    "fireRateMultiplier",
    "damageMultiplier"
}

function Stats.Empty()
    local result = {}
    for _, key in ipairs(Stats.Keys) do
        result[key] = 0
    end
    return result
end

function Stats.PartStats(part)
    local result = Stats.Empty()
    if not part or type(part.stats) ~= "table" then return result end

    for _, key in ipairs(Stats.Keys) do
        if type(part.stats[key]) == "number" then
            result[key] = part.stats[key]
        end
    end
    return result
end

function Stats.Add(target, source)
    for _, key in ipairs(Stats.Keys) do
        target[key] = (target[key] or 0) + (source[key] or 0)
    end
    return target
end

function Stats.SumSelection(selection)
    local result = Stats.Empty()
    if type(selection) ~= "table" then return result end

    for _, path in ipairs(Core.SortedSelectionPaths(selection)) do
        local part = Core.GetPart(selection[path])
        Stats.Add(result, Stats.PartStats(part))
    end
    return result
end

function Stats.Encode(stats, separator)
    local values = {}
    local source = stats or Stats.Empty()
    for _, key in ipairs(Stats.Keys) do
        table.insert(values, key .. "=" .. string.format("%.4f", source[key] or 0))
    end
    return table.concat(values, separator or ",")
end
