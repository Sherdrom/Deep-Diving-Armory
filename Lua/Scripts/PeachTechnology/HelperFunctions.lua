local HELPER_DEBUG = false

local function dbg(msg)
    if HELPER_DEBUG then
        print("[AfflictionHelper] " .. tostring(msg))
    end
end

local AfflictionHelper = {}

function AfflictionHelper.SetDebug(enabled)
    HELPER_DEBUG = enabled
end

function AfflictionHelper.GetAffStrength(character, identifier)
    if character == nil or character.CharacterHealth == nil then
        return 0
    end
    return character.CharacterHealth.GetAfflictionStrengthByIdentifier(identifier)
end

_G.AfflictionHelper = AfflictionHelper

return AfflictionHelper