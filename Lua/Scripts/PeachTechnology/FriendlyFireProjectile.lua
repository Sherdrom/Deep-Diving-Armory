local MOD_ID = "FriendlyFireProjectile"
local DEBUG = false
local FRIENDLY_FIRE_MARKER = Identifier("friendly_fire")
local FRIENDLY_FIRE_CHIP = Identifier("chip_friendly_fire")

local HAND_SLOTS = { InvSlotType.LeftHand, InvSlotType.RightHand }

local function Log(message)
    if DEBUG then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

local function HasFriendlyFireStat(character)
    local info = character.Info
    if info == nil then
        return false
    end
    return info:GetSavedStatValue(StatTypes.None, FRIENDLY_FIRE_MARKER) > 0
end

local function HasFriendlyFireAffliction(character)
    local health = character.CharacterHealth
    if health == nil then
        return false
    end
    return health:GetAfflictionStrengthByIdentifier(FRIENDLY_FIRE_MARKER) > 0
end

local function HeldItemContainsChip(character)
    local inventory = character.Inventory
    if inventory == nil then
        return false
    end

    for i = 1, #HAND_SLOTS do
        local heldItem = inventory.GetItemInLimbSlot(HAND_SLOTS[i])
        if heldItem ~= nil and not heldItem.Removed then
            local ownInventory = heldItem.OwnInventory
            if ownInventory ~= nil and ownInventory.AllItems ~= nil then
                for item in ownInventory.AllItems do
                    if item ~= nil and not item.Removed and item.Prefab ~= nil
                        and item.Prefab.Identifier == FRIENDLY_FIRE_CHIP then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- 三级判定: SavedStat -> affliction -> 手持武器容器内芯片, 任一命中即视为携带标记
local function HasFriendlyFireMarker(character)
    return HasFriendlyFireStat(character)
        or HasFriendlyFireAffliction(character)
        or HeldItemContainsChip(character)
end

Hook.Patch(
    MOD_ID,
    "Barotrauma.Items.Components.Projectile",
    "Shoot",
    function(instance, ptable)
        local user = ptable["user"]

        if user == nil or not user.IsHuman then
            return
        end

        if not HasFriendlyFireMarker(user) then
            return
        end

        instance.FriendlyFire = false
        Log("FriendlyFire disabled for shooter: " .. tostring(user.Name))
    end,
    Hook.HookMethodType.Before
)

-- 新功能: 友军识别器 — 目标携带标记时, 同阵营其他角色发射的子弹穿过目标
Hook.Patch(
    MOD_ID .. ".TargetPassthrough",
    "Barotrauma.Items.Components.Projectile",
    "ShouldIgnoreCharacterCollision",
    function(instance, ptable)
        local character = ptable["character"]
        if character == nil then
            return
        end

        local user = instance.User
        if user == nil or character == user then
            return
        end

        if not character.IsFriendly(user) then
            return
        end

        if HasFriendlyFireMarker(character) then
            ptable.PreventExecution = true
            Log("Projectile passed through: " .. tostring(character.Name))
            return true
        end
    end,
    Hook.HookMethodType.Before
)
