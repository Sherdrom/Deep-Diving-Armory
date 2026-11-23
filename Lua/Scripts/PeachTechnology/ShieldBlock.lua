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

-- 计算命中目标的盾牌拦截量; 非盾牌返回nil
local function GetTargetBlockCount(target)
    local userData = GetUserData(target)
    if userData == nil then
        return nil
    end
    return GetTotalShieldBlockCount(userData)
end

-- 首见缓存原始值, 否则恢复为原始值; 返回原始值 (原版路径专用)
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

-- ============ 补丁1: 原版物理弹 (OnProjectileCollision) ============
-- 物理碰撞回调内的归一化: 保证 HandleProjectileCollision 内 hits.Count >= MaxTargetsToHit
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

-- ============ 补丁2: 原版弹 (物理碰撞 + 原版hitscan共用此签名) ============
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

        local totalBlock = GetTargetBlockCount(ptable["target"])
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

-- ============ 补丁3: VCE虚拟弹匣 (VirtualizedProjectile) ============
-- VirtualizedProjectile 为纯hitscan: DoHitscan 逐命中调用其私有
-- HandleProjectileCollision(Fixture, Vector2), 与原版签名 (Fixture, Vector2, Vector2)
-- 不同, 补丁2不会触发; 其穿透停止判定为 DoHitscan 循环内的 hitCount >= MaxTargetsToHit
-- 同一弹丸实例被整个弹匣复用, ParseProjectileData 每发射击前按当前弹种重设
-- MaxTargetsToHit, 因此对盾牌命中采用增量扣减 (在当前值上直接扣拦截量),
-- 无需维护原始值缓存, 跨发/混装弹匣切换弹种均自愈
Hook.Patch(
    "VCE_VirtualizedMagazine.VirtualizedProjectile",
    "HandleProjectileCollision",
    function(instance, ptable)
        local totalBlock = GetTargetBlockCount(ptable["target"])
        if totalBlock == nil then
            return
        end

        local current = instance.MaxTargetsToHit
        local newValue = current - totalBlock + 1
        if newValue < 1 then
            newValue = 1
        end

        log(string.format(
            "VCE shield blocked: blockCount=%d | MaxTargetsToHit %d -> %d",
            totalBlock, current, newValue
        ))

        if newValue ~= current then
            instance.MaxTargetsToHit = newValue
        end
    end,
    Hook.HookMethodType.Before
)

Hook.Add("roundStart", "ShieldBlock.RoundStart", function()
    for key in pairs(maxTargetsCache) do
        maxTargetsCache[key] = nil
    end
end)
