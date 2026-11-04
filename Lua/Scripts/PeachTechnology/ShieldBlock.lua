local DEBUG = false

local SHIELD_CONFIG = {
    ["deep_double_handed_shield_heavy"] = 2,
    ["deep_mobile_shield"] = 1,
    ["deep_single_handed_shield"] = 1,
    ["deep_wuchuan"] = 2,
}

local SHIELD_UPGRADE_CONFIG = {
    ["deep_mobile_shield_fix_plate_phy"] = 1,
    ["deep_mobile_shield_fix_plate_tun"] = 2,
}

local maxTargetsCache = setmetatable({}, { __mode = "k" })

print("[ShieldBlock] Loaded")

local function log(...)
    if DEBUG then
        print("[ShieldBlock]", ...)
    end
end

local function GetUserData(target)
    if target == nil then
        return nil
    end
    local body = target.Body
    if body == nil then
        return nil
    end
    return body.UserData
end

local function GetShieldItem(userData)
    if userData == nil then
        return nil
    end
    if LuaUserData.HasMember(userData, "Prefab") then
        return userData
    end
    if LuaUserData.HasMember(userData, "Item") then
        local item = userData.Item
        if item ~= nil and LuaUserData.HasMember(item, "Prefab") then
            return item
        end
    end
    return nil
end

local function GetTotalShieldBlockCount(userData)
    local shieldItem = GetShieldItem(userData)
    if shieldItem == nil then
        return nil
    end

    local prefab = shieldItem.Prefab
    if prefab == nil then
        return nil
    end

    local identifier = tostring(prefab.Identifier)
    local baseCount = SHIELD_CONFIG[identifier]
    if baseCount == nil or baseCount <= 0 then
        return nil
    end

    local total = baseCount

    local inventory = shieldItem.OwnInventory
    if inventory ~= nil then
        local capacity = inventory.Capacity
        if capacity ~= nil and capacity > 0 then
            for i = 0, capacity - 1 do
                local containedItem = inventory.GetItemAt(i)
                if containedItem ~= nil and LuaUserData.HasMember(containedItem, "Prefab") then
                    local containedPrefab = containedItem.Prefab
                    if containedPrefab ~= nil then
                        local containedId = tostring(containedPrefab.Identifier)
                        local upgradeCount = SHIELD_UPGRADE_CONFIG[containedId]
                        if upgradeCount ~= nil and upgradeCount > 0 then
                            if containedItem.Condition ~= nil and containedItem.Condition <= 0 then
                                log("Shield upgrade broken: " .. containedId .. " (condition=0)")
                            else
                                total = total + upgradeCount
                                log("Shield upgrade: " .. containedId .. " +" .. tostring(upgradeCount) .. " (total=" .. tostring(total) .. ")")
                            end
                        end
                    end
                end
            end
        end
    end

    return total
end

-- 首见缓存原始值, 否则恢复为原始值; 返回原始值
local function NormalizeMaxTargets(instance)
    local pristine = maxTargetsCache[instance]
    if pristine == nil then
        pristine = instance.MaxTargetsToHit
        maxTargetsCache[instance] = pristine
    else
        instance.MaxTargetsToHit = pristine
    end
    return pristine
end

-- 物理碰撞回调内的归一化: 保证 Projectile.cs L974 的 hits.Count >= MaxTargetsToHit
-- 判定始终使用原始值 (该回调早于 HandleProjectileCollision 执行)
Hook.Patch(
    "Barotrauma.Items.Components.Projectile",
    "OnProjectileCollision",
    {
        "FarseerPhysics.Dynamics.Fixture",
        "FarseerPhysics.Dynamics.Fixture",
        "FarseerPhysics.Dynamics.Contacts.Contact"
    },
    function(instance, ptable)
        NormalizeMaxTargets(instance)
    end,
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
    function(instance, ptable)
        local pristine = NormalizeMaxTargets(instance)

        local target = ptable["target"]
        local userData = GetUserData(target)
        if userData == nil then
            return
        end

        local totalBlock = GetTotalShieldBlockCount(userData)
        if totalBlock == nil then
            return
        end

        local newValue = pristine - totalBlock + 1
        if newValue < 1 then
            newValue = 1
        end

        log(string.format(
            "Shield blocked: blockCount=%d | MaxTargetsToHit %d -> %d",
            totalBlock, pristine, newValue
        ))

        instance.MaxTargetsToHit = newValue
    end,
    Hook.HookMethodType.Before
)

Hook.Add("roundStart", "ShieldBlock.RoundStart", function()
    for key in pairs(maxTargetsCache) do
        maxTargetsCache[key] = nil
    end
end)
