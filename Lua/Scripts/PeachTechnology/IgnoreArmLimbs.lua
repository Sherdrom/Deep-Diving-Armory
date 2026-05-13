local IgnoreArmLimbsMod = {
    IgnoreChance = 0.6,
    DebugMode = false,
}

local function log(...)
    if IgnoreArmLimbsMod.DebugMode then
        print("[IgnoreArmLimbs]", ...)
    end
end

local ARM_LIMB_TYPES = {
    [LimbType.RightHand] = true,
    [LimbType.LeftHand] = true,
    [LimbType.LeftForearm] = true,
    [LimbType.RightForearm] = true,
    [LimbType.LeftArm] = true,
    [LimbType.RightArm] = true,
}

local HASH_MULTIPLIER = 2654435761
local HASH_MODULUS = 4294967296
local CHANCE_RESOLUTION = 10000

local function IsHumanArm(userData)
    if userData == nil then
        return false
    end

    if not LuaUserData.HasMember(userData, "character") then
        return false
    end

    local character = userData.character
    if character == nil or not character.IsHuman then
        return false
    end

    local limbType = userData.type
    return limbType ~= nil and ARM_LIMB_TYPES[limbType] == true
end

local function ShouldIgnoreHit(projectile, limb)
    if IgnoreArmLimbsMod.IgnoreChance <= 0 then
        return false
    end

    local seed = math.floor(Timer.Time * 1000)

    if projectile.item ~= nil then
        seed = seed * 31 + projectile.item.ID
    end

    seed = seed * 37 + limb.character.ID

    local hash = (seed * HASH_MULTIPLIER) % HASH_MODULUS
    return (hash % CHANCE_RESOLUTION) / CHANCE_RESOLUTION < IgnoreArmLimbsMod.IgnoreChance
end

local function patchCallback(instance, ptable)
    local target = ptable["target"]
    if target == nil then
        return
    end

    local userData = target.Body.UserData

    if not IsHumanArm(userData) then
        return
    end

    if ShouldIgnoreHit(instance, userData) then
        log("忽略手臂命中: " .. tostring(userData.type))
        ptable.PreventExecution = true
        return false
    end
end

Hook.Patch(
    "Barotrauma.Items.Components.Projectile",
    "OnProjectileCollision",
    {
        "FarseerPhysics.Dynamics.Fixture",
        "FarseerPhysics.Dynamics.Fixture",
        "FarseerPhysics.Dynamics.Contacts.Contact"
    },
    patchCallback,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "Barotrauma.Items.Components.Projectile",
    "HandleProjectileCollision",
    {
        "FarseerPhysics.Dynamics.Fixture",
        "Microsoft.Xna.Framework.Vector2",
        "Microsoft.Xna.Framework.Vector2"
    },
    patchCallback,
    Hook.HookMethodType.Before
)
