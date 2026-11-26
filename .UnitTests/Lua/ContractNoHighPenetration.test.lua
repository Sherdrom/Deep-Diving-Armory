local patches = { before = {}, after = {} }
Hook = {
    HookMethodType = { Before = "before", After = "after" },
    Patch = function(_, class, method, callback, phase)
        local key = class .. "." .. method
        local list = patches[phase][key] or {}
        patches[phase][key] = list
        list[#list + 1] = callback
    end
}
Identifier = function(value) return value:lower() end
Single = function(value) return { Value = string.unpack("f", string.pack("f", value)) } end
ItemPrefab = { Prefabs = {} }
local scripts = "Lua/Scripts/PeachTechnology/"
dofile(scripts .. "HelperFunctions.lua")
dofile(scripts .. "ChipBodyshotPenetration.lua")
dofile(scripts .. "ContractNoHighPenetration.lua")

local function invoke(key, owner, p, body)
    local result
    for _, f in ipairs(patches.before[key] or {}) do
        result = f(owner, p)
        if p.PreventExecution then break end
    end
    if not p.PreventExecution and body then result = body() end
    for _, f in ipairs(patches.after[key] or {}) do f(owner, p) end
    return result
end

local apply = "Barotrauma.Character.ApplyAttack"
local limb = "Barotrauma.Attack.DoDamageToLimb"
local effects = "Barotrauma.StatusEffect.HasRequiredItems"
local collision = "Barotrauma.Items.Components.Projectile.HandleProjectileCollision"
local dda = { Name = "Deep-Diving-Armory" }
local other = { Name = "Other Mod" }
local tag, chip, gunPen = "deep_round", false, 0
local gun = {
    Prefab = { Identifier = "gun" },
    HasTag = function(t) return t == "gunsmith" end,
    GetComponentString = function() return { Penetration = gunPen } end,
    OwnInventory = { AllItems = function(_, prev)
        if chip and not prev then return { Prefab = { Identifier = "chip_bodyshot" } } end
    end }
}
local attack = { Penetration = 0.8 }
local projectile = { Attack = attack, Launcher = gun }
local item = {
    HasTag = function(t) return t == tag end,
    Prefab = { Identifier = "round", ContentPackage = dda },
    GetComponentString = function(t) if t == "Projectile" then return projectile end end
}
attack.SourceItem = item
local strength = 1
local shooter = { CharacterHealth = { GetAfflictionStrengthByIdentifier = function(id)
    assert(id == "deep_contract_no_high_penetration_detect")
    return strength
end } }
local function params(pen, attacker, target)
    return { attack = attack, attacker = attacker, targetLimb = target, penetration = pen,
        OriginalParameters = { penetration = pen } }
end
local function check(expected, pen, attacker, target)
    local p = params(pen, attacker, target)
    invoke(apply, {}, p)
    assert((p.PreventExecution == true) == expected, "unexpected result at penetration " .. pen)
end

for _, pen in ipairs({ 0, 0.8, 0.85, 0.89998 }) do check(false, pen, shooter, {}) end
for _, pen in ipairs({ 0.89999998, 0.9, 0.95, 1 }) do check(true, pen, shooter, {}) end
check(false, 1, nil, {})
attack.SourceItem = nil
check(false, 1, shooter, {})
attack.SourceItem, item.Removed = item, true
check(false, 1, shooter, {})
item.Removed = false
strength = 0
check(false, 1, shooter, {})
strength = 0.001
check(true, 1, shooter, {})
item.Prefab.ContentPackage = other
check(false, 1, shooter, {})
item.Prefab.ContentPackage = dda
tag = "grenade"
check(false, 1, shooter, {})
tag = "riflemanbonus"
check(false, 1, shooter, {})
projectile.Hitscan = true
check(true, 1, shooter, {})
tag = "shotgunammo"
projectile.Attack = {}
check(false, 1, shooter, {}) -- another attack on an item which also has a projectile
projectile.Attack = attack
chip = true
check(true, 0.8, shooter, {})
check(false, 0.75, shooter, {})
check(true, 0, shooter, nil) -- DoDamage(character) omits round and gun penetration
chip, gunPen = false, 0.1
check(true, 0, shooter, nil)

item.Prefab = { Identifier = Identifier("VCE_VirtualizedProjectile"), ContentPackage = other }
ItemPrefab.Prefabs.localround = { ContentPackage = dda }
ItemPrefab.Prefabs.foreign = { ContentPackage = other }
local rounds = { "foreign", "localround" }
item.ParentInventory = { Container = { SerializableProperties = {
    [Identifier("LoadedAmmoIdentifiersArray")] = { GetValue = function() return rounds end }
} } }
check(true, 1, shooter, {})
rounds = { "localround", "foreign" }
check(false, 1, shooter, {})
rounds = {}
check(false, 1, shooter, {})
item.Prefab = { Identifier = "round", ContentPackage = dda }

local radiation, explosion = {}, { Afflictions = {} }
attack.StatusEffects = function(_, prev) if not prev then return radiation end end
local function allowed(effect, entity)
    return invoke(effects, effect, { entity = entity }, function() return true end)
end
invoke(collision, projectile, {}, function()
    invoke(limb, attack, {}, function()
        check(true, 1, shooter, {})
        assert(allowed(radiation, {}) == false)
        invoke(limb, attack, {}, function()
            check(false, 1, nil, {})
            assert(allowed(radiation, {}))
        end)
        assert(allowed(radiation, {}) == false)
    end)
    explosion.Explosions = function(_, prev) if not prev then return true end end
    assert(allowed(explosion, item) == false)
    assert(allowed(explosion, {}))
    assert(allowed({ Afflictions = { "burn" } }, item) == false)
    assert(allowed({ Afflictions = {}, Explosions = function() end }, item))
end)
assert(allowed(radiation, {}) and allowed(explosion, item))
invoke(limb, attack, {}, function()
    invoke(limb, attack, {}, function() check(true, 1, shooter, {}) end)
    assert(allowed(radiation, {}))
end)
print("PASS: contract scope, final penetration, mixed magazines, nested hits and secondary effects")
