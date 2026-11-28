local callbacks = { before = {}, after = {} }
Hook = {
    HookMethodType = { Before = "before", After = "after" },
    Patch = function(class, method, parameters, callback, phase)
        if type(parameters) == "function" then phase, callback = callback, parameters end
        callbacks[phase][class .. "." .. method] = callback
    end,
}
LimbType = { Head = 1, Torso = 2 }
dofile("Lua/Scripts/PeachTechnology/HeadShotMultiplier.lua")

local apply = "Barotrauma.Character.ApplyAttack"
local head = { type = LimbType.Head }
local attack = { SourceItem = { Tags = "deep_headshot_gunshotwound_4,deep_headshot_burn_2" } }
local function hit(character, limb, body)
    callbacks.before[apply](character, { attack = attack, targetLimb = limb })
    if body then body() end
    if callbacks.after[apply] then callbacks.after[apply](character, {}) end
end

local function wound(character, id)
    local health = { Character = character, GetResistance = function() return 0 end }
    local affliction = { Prefab = { Identifier = id }, Strength = 1 }
    callbacks.before["Barotrauma.CharacterHealth.AddLimbAffliction"](health, { limb = head, newAffliction = affliction })
    return affliction.Strength
end

local victim, other = {}, {}
assert(wound(victim, "gunshotwound") == 1)
hit(victim, head) -- The contract skipped the original ApplyAttack. Its postfix still runs.
assert(wound(victim, "gunshotwound") == 1, "blocked headshot amplified an independent wound")
hit(victim, head, function()
    hit(other, head)
    assert(wound(victim, "gunshotwound") == 4, "allowed headshot lost its multiplier")
    assert(wound(victim, "gunshotwound") == 1, "one headshot applied its multiplier twice")
end)
assert(wound(victim, "burn") == 1, "unused multiplier survived the end of an allowed hit")
hit(victim, { type = LimbType.Torso }, function() assert(wound(victim, "gunshotwound") == 1) end)
print("PASS: headshot multipliers expire after blocked and completed attacks")
