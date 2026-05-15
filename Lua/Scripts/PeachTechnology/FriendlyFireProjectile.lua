local MOD_ID = "FriendlyFireProjectile"
local DEBUG = false

local function Log(message)
    if DEBUG then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

Hook.Patch(
    MOD_ID,
    "Barotrauma.Items.Components.Projectile",
    "Shoot",
    function(instance, ptable)
        local user = ptable["user"]

        if not user.IsHuman then
            return
        end

        if user.CharacterHealth.GetAfflictionStrengthByIdentifier("friendly_fire") <= 0 then
            return
        end

        instance.FriendlyFire = false
        Log("FriendlyFire disabled for shooter: " .. tostring(user.Name))
    end,
    Hook.HookMethodType.Before
)