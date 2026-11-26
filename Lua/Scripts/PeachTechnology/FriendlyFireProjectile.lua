local MOD_ID = "FriendlyFireProjectile"
local DEBUG = false
local FRIENDLY_FIRE_MARKER = Identifier("deep_firendlyfire_avoid_tac_detect")
-- 标识符统一用 tostring(Prefab.Identifier) 比较(代码库已验证方式), 不做 userdata 等值比较
local FRIENDLY_FIRE_CHIP_ID = "deep_firendlyfire_avoid_tac"

local MAX_SCAN_DEPTH = 6
local MARKER_CACHE_INTERVAL = 0.5
-- 弱键缓存: 角色对象跨回合重建后被 GC 自动清除, 不产生跨回合陈旧状态
local markerCache = setmetatable({}, { __mode = "k" })

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

local function ContainsChipRecursive(item, depth)
    if item == nil or item.Removed or depth > MAX_SCAN_DEPTH then
        return false
    end

    local ownInventory = item.OwnInventory
    if ownInventory == nil or ownInventory.AllItems == nil then
        return false
    end

    -- C# IEnumerable 用泛型 for 迭代(本脚本原版已验证写法), pairs 对 userdata 报错
    for contained in ownInventory.AllItems do
        if contained ~= nil and not contained.Removed then
            local prefab = contained.Prefab
            if prefab ~= nil and tostring(prefab.Identifier) == FRIENDLY_FIRE_CHIP_ID then
                return true
            end
            if ContainsChipRecursive(contained, depth + 1) then
                return true
            end
        end
    end

    return false
end

-- 全背包顶层扫描(AllItems 含穿戴槽位: 头盔/衣服/背包/双手, 非递归快照,
-- 语义同原版 Character.cs 死亡入袋遍历), 芯片实际存放于头盔容器内, 故逐物品递归下钻
local function InventoryContainsChip(character)
    local inventory = character.Inventory
    if inventory == nil or inventory.AllItems == nil then
        return false
    end

    for item in inventory.AllItems do
        if item ~= nil and not item.Removed then
            local prefab = item.Prefab
            if prefab ~= nil and tostring(prefab.Identifier) == FRIENDLY_FIRE_CHIP_ID then
                return true
            end
            if ContainsChipRecursive(item, 1) then
                return true
            end
        end
    end

    return false
end

-- 三级判定: SavedStat -> affliction -> 全背包芯片扫描, 任一命中即视为携带标记.
-- 前两级是装备数值系统(AdjustEquipmentStatvalue)在装备事件时写入的会话态数据:
-- 多人跨回合重建角色后标记清零, 且服务器侧没有回合开局重扫触发点(客户端靠
-- Inventory.ApplyReceivedState 重扫恢复), 表现为客户端射线穿过而服务器仍判命中.
-- 第三级直接判定物品在场, 与会话状态无关, 客户端/服务器各自判定, 跨回合稳定.
-- 碰撞回调为热路径, 结果按角色做短周期缓存, 携带状态变化最迟 0.5s 内生效
local function HasFriendlyFireMarker(character)
    if character == nil or character.Removed then
        return false
    end

    local now = Timer.GetTime()
    local cached = markerCache[character]
    if cached ~= nil and now - cached.time < MARKER_CACHE_INTERVAL then
        return cached.value
    end

    local value = HasFriendlyFireStat(character)
        or HasFriendlyFireAffliction(character)
        or InventoryContainsChip(character)

    markerCache[character] = { time = now, value = value }
    return value
end

for _, projectileType in ipairs({
    "Barotrauma.Items.Components.Projectile",
    "VCE_VirtualizedMagazine.VirtualizedProjectile",
}) do
Hook.Patch(
    MOD_ID .. "." .. projectileType,
    projectileType,
    "Shoot",
    {
        "Barotrauma.Character",
        "Microsoft.Xna.Framework.Vector2",
        "Microsoft.Xna.Framework.Vector2",
        "System.Single",
        "System.Collections.Generic.List`1[[FarseerPhysics.Dynamics.Body, Farseer.NetStandard]]",
        "System.Boolean",
        "System.Single",
        "System.Single",
    },
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

-- 新功能: 友军识别器 -- 目标携带标记时, 同阵营其他角色发射的子弹穿过目标
Hook.Patch(
    MOD_ID .. ".TargetPassthrough." .. projectileType,
    projectileType,
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
end
