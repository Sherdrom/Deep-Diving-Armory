local MOD_ID = "FriendlyFireProjectile"
local DEBUG = false
local FRIENDLY_FIRE_MARKER = Identifier("friendly_fire")

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

        if not user.Info or user.Info:GetSavedStatValue(StatTypes.None, FRIENDLY_FIRE_MARKER) <= 0 then
            return
        end

        instance.FriendlyFire = false
        Log("FriendlyFire disabled for shooter: " .. tostring(user.Name))
    end,
    Hook.HookMethodType.Before
)
