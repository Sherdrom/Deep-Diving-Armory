SERVER = false
Descriptors = {}
Deep_Lua = { Path = "." }

local hooks = {}
Hook = {
    Add = function(name, callbackOrId, callback)
        hooks[name] = callback or callbackOrId
    end,
}

LuaUserData = {
    MakeFieldAccessible = function() end,
}

Game = {
    SoundManager = {
        LoadSound = function(path) return path end,
    },
}

Rectangle = function(...) return { ... } end
Vector2 = function(...) return { ... } end

local playCount = 0
SoundPlayer = {
    PlaySound = function() playCount = playCount + 1 end,
}

dofile("Lua/Scripts/BenzeneTechnology/AllSprite/AllSprite.lua")

local function makeItem(id)
    local component = { wearableSprites = { { Sprite = {} } } }
    return {
        ID = id,
        WorldPosition = {},
        GetComponentString = function() return component end,
    }
end

local variants = {
    { on = "SixBFortySeven_Night_On", origin = "SixBFortySeven_Origin" },
    { on = "FAST_BLACK_Night_On", origin = "FAST_BLACK_Origin" },
    { on = "FAST_Night_On", origin = "FAST_Origin" },
    { on = "FAST_Ranger_Night_On", origin = "FAST_Ranger_Origin" },
    { on = "FAST_Heavy_Trooper_Night_On", origin = "FAST_Heavy_Trooper_Origin" },
    { on = "FAST_Sledge_Hammer_Night_On", origin = "FAST_Sledge_Hammer_Origin" },
    { on = "GHOST_Night_On", origin = "GHOST_Origin" },
}

for index, variant in ipairs(variants) do
    local player = makeItem(index * 2)
    local other = makeItem(index * 2 + 1)
    local invoke = hooks[variant.on]
    local reset = hooks[variant.origin]
    assert(invoke and reset, "missing AllSprite hook for " .. variant.on)
    local baseline = playCount

    invoke(nil, nil, player)
    invoke(nil, nil, player)
    assert(playCount == baseline + 1, "player " .. variant.on .. " played more than once")

    invoke(nil, nil, other)
    reset(nil, nil, other)
    invoke(nil, nil, player)
    assert(playCount == baseline + 2, "other " .. variant.origin .. " reset player state")

    reset(nil, nil, player)
    invoke(nil, nil, player)
    assert(playCount == baseline + 3, "player " .. variant.origin .. " did not reset its own state")
end

print("AllSprite night sound state check OK")
