local contract = "deep_contract_no_high_penetration_detect"
local virtualType = "VCE_VirtualizedMagazine.VirtualizedProjectile"
local virtualItem = Identifier("VCE_VirtualizedProjectile")
local loadedAmmo = Identifier("LoadedAmmoIdentifiersArray")

-- Both Attack and Projectile can apply their own status effects after ApplyAttack returns.
local hits, blocked = {}, {}
local function trackHit(class, method)
    Hook.Patch("DDA.HighPen.Start", class, method, function(owner)
        hits[#hits + 1] = owner
    end, Hook.HookMethodType.Before)
    Hook.Patch("DDA.HighPen.End", class, method, function(owner)
        local i = #hits
        if hits[i] == owner then hits[i], blocked[i] = nil, nil end
    end, Hook.HookMethodType.After)
end

trackHit("Barotrauma.Attack", "DoDamage")
trackHit("Barotrauma.Attack", "DoDamageToLimb")
trackHit("Barotrauma.Items.Components.Projectile", "HandleProjectileCollision")
trackHit(virtualType, "HandleProjectileCollision")

Hook.Patch("DDA.HighPen.Contract", "Barotrauma.Character", "ApplyAttack", function(_, p)
    local attack = p["attack"]
    local item = attack and attack.SourceItem
    if not item or item.Removed or AfflictionHelper.GetAffStrength(p["attacker"], contract) <= 0 then return end
    local projectile = item.GetComponentString("Projectile")
    if not projectile or projectile.Attack ~= attack then return end
    if not (item.HasTag("deep_round") or item.HasTag("shotgunammo")
        or (projectile.Hitscan and item.HasTag("riflemanbonus"))) then return end

    local pen = p["penetration"]
    if type(pen) ~= "number" then pen = pen.Value end -- chip writes a boxed LuaSingle
    if not p["targetLimb"] and p.OriginalParameters["penetration"] == 0 then
        -- DoDamage(character) omits the round and launcher penetration passed by DoDamageToLimb.
        local gun = projectile.Launcher and projectile.Launcher.GetComponentString("RangedWeapon")
        pen = pen + attack.Penetration + (gun and gun.Penetration or 0)
    end
    if math.floor((pen + 0.00001) * 10) < 9 then return end

    local prefab = item.Prefab
    if prefab.Identifier == virtualItem then
        -- VCE hitscan runs synchronously with the loaded round at the end of the saved array.
        local magazine = item.ParentInventory and item.ParentInventory.Container
        local property = magazine and magazine.SerializableProperties[loadedAmmo]
        local rounds = property and property:GetValue(magazine)
        local round = rounds and rounds[#rounds]
        prefab = round and ItemPrefab.Prefabs[round]
    end
    if not prefab or not prefab.ContentPackage or prefab.ContentPackage.Name ~= "Deep-Diving-Armory" then return end

    local i = #hits
    if hits[i] == attack then
        blocked[i] = { effects = attack.StatusEffects }
        i = i - 1
    end
    if hits[i] == projectile then blocked[i] = { item = item } end
    p.PreventExecution = true -- the engine returns its default, zero-damage AttackResult
end, Hook.HookMethodType.Before)

local function blocksEffect(hit, effect, entity)
    if hit.effects then
        for owned in hit.effects do
            if owned == effect then return true end
        end
    elseif hit.item == entity then
        if #effect.Afflictions > 0 then return true end
        for _ in effect.Explosions do return true end
    end
end

-- Both target overloads of StatusEffect.Apply check HasRequiredItems before applying the effect.
Hook.Patch("DDA.HighPen.Effects", "Barotrauma.StatusEffect", "HasRequiredItems", function(effect, p)
    local hit = blocked[#hits]
    if hit and blocksEffect(hit, effect, p["entity"]) then
        p.PreventExecution = true
        return false
    end
end, Hook.HookMethodType.Before)
