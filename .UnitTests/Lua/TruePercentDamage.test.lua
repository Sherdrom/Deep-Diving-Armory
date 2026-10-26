local hooks = {}
Hook = {
    Add = function(name, _, callback)
        hooks[name] = callback
    end,
}

local health = { afflictions = {}, deadlyChecks = 0 }
function health:GetAfflictionStrengthByIdentifier(identifier)
    self.deadlyChecks = self.deadlyChecks + 1
    for _, affliction in ipairs(self.afflictions) do
        if affliction.Identifier == identifier and affliction.Strength > 0 then
            return affliction.Strength
        end
    end
    return 0
end
local function makeAffliction(identifier, strength, vitalityDecrease)
    return {
        Identifier = identifier,
        Strength = strength,
        GetVitalityDecrease = function()
            return vitalityDecrease
        end,
    }
end

dofile("Lua/Scripts/PeachTechnology/TruePercentDamage.lua")
assert(hooks["character.applyAffliction"] and hooks.afflictionUpdate,
    "TruePercentDamage did not register both hooks")

local healing = makeAffliction("nausea", 5, -1)
local deadly = makeAffliction("deep_headshot_deadly", 1, 1)
health.afflictions = { healing }
local apply = hooks["character.applyAffliction"]
local update = hooks.afflictionUpdate

assert(apply(health, nil, deadly) == nil, "deadly affliction was blocked")
assert(healing.Strength == 5, "deadly apply cleared healing too early")

health.afflictions[#health.afflictions + 1] = deadly
update(healing, health, nil)
assert(healing.Strength == 0, "afflictionUpdate did not clear existing healing")
local deadlyChecks = health.deadlyChecks
healing.Strength = 5
update(healing, health, nil)
assert(healing.Strength == 0 and health.deadlyChecks == deadlyChecks,
    "direct healing strength change was not corrected from cache")

local incomingHealing = makeAffliction("nausea", 1, -1)
assert(apply(health, nil, incomingHealing) == true and incomingHealing.Strength == 0,
    "new healing affliction was not zeroed and blocked")
assert(apply(health, nil, makeAffliction("gunshotwound", 1, 1)) == nil,
    "harmful affliction was blocked")

deadly.Strength = 0
update(deadly, health, nil)
local afterDeadly = makeAffliction("nausea", 2, -1)
assert(apply(health, nil, afterDeadly) == nil and afterDeadly.Strength == 2,
    "healing stayed blocked after the deadly affliction ended")

print("TruePercentDamage event check OK")
