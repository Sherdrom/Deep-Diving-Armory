-- AIRandomWeapon: AI在战斗中每隔固定时间随机切换使用另一把武器
--
-- 实现原理:
--   Hook.Patch (After) on AIObjectiveCombat.TryArm:
--       TryArm 是引擎每秒调用的武器装备方法, 内部通过 GetWeapon 选择
--       最高优先级武器. 补丁在这个已有的按角色入口中执行随机切换,
--       不再进行全局角色扫描.
--       TryArm 会先按引擎逻辑赋值 instance.Weapon, After hook 再恢复随机选择.
--       After hook 在 TryArm 执行后:
--       - 若达到 SwitchInterval, 从物品栏收集武器并执行随机切换
--       - 若 TryArm 返回 false (武器选择失败), 清除 chosenWeapons 记录,
--         让引擎下次自行选择可用武器
--       - 若 TryArm 返回 true 且 chosenWeapons 中有有效记录,
--         将 instance.Weapon 重新设为我们选择的随机武器
--       - 若记录中的武器已失效(移除/不在物品栏), 清除记录
--
--   Weapon setter 公开, 自动清空 _weaponComponent 缓存,
--   后续 WeaponComponent getter 通过 GetWeaponComponent(Weapon) 正确解析.
--
-- 限制说明 (多人同步):
--   AIObjectiveCombat 仅服务端执行, TryArm 补丁仅在服务端 AI 逻辑中触发,
--   无需额外 CharacterList 扫描或客户端守卫.
--   单机或服务端正常运行.

local MOD_NAME = "AIRandomWeapon"

local Config = {
    Debug = false,
    SwitchInterval = 4,     -- 武器切换间隔(秒)
    MinWeaponCount = 2,     -- 触发切换的最少武器数
    MinWeaponPriority = 30, -- 最低武器优先级, CombatPriority低于此值的武器不会被随机到
    PriorityWeaponThreshold = 1000, -- 优先武器阈值, CombatPriority超过此值的武器优先使用, 不会切换到其他武器
    CleanupInterval = 30,   -- 清理过期记录的间隔(秒)
}

-- 每个角色的上次切换时间
local switchTimers = {}

-- 每个角色当前被选择的随机武器 (用于在 TryArm After hook 中强制恢复)
local chosenWeapons = {}

-- 上次清理时间
local lastCleanupTime = 0

-- 武器组件类型列表 (按引擎 GetWeaponComponent 优先级排序, 命中即停止遍历)
local WEAPON_COMPONENT_TYPES = {
    "RangedWeapon",
    "MeleeWeapon",
    "RepairTool",
    "Holdable",
}

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if Config.Debug then Log(msg) end
end

-- 从物品栏收集所有 CombatPriority > 0 的武器
-- 返回: { {item=Item, priority=float}, ... }
local function CollectWeapons(character)
    local result = {}
    local inventory = character.Inventory
    if inventory == nil then return result end

    for item in inventory.AllItemsMod do
        if item == nil or item.Removed then goto continue_item end

        for _, compType in ipairs(WEAPON_COMPONENT_TYPES) do
            local comp = item.GetComponentString(compType)
            if comp ~= nil then
                local priority = comp.CombatPriority
                if priority >= Config.MinWeaponPriority then
                    result[#result + 1] = { item = item, priority = priority }
                end
                break
            end
        end

        ::continue_item::
    end

    return result
end

-- 清理已移除/死亡角色的记录
local function CleanupTimers(currentTime)
    if currentTime - lastCleanupTime < Config.CleanupInterval then return end
    lastCleanupTime = currentTime

    local staleKeys = {}
    for character, _ in pairs(switchTimers) do
        if character.Removed or character.IsDead then
            staleKeys[#staleKeys + 1] = character
        end
    end
    for _, key in ipairs(staleKeys) do
        switchTimers[key] = nil
        chosenWeapons[key] = nil
    end
end

-- ============================================================
-- TryArm hook 内的随机切换逻辑
-- ============================================================
local function ProcessCharacter(character, currentObjective, currentTime)
    if not character.IsHuman or not character.IsBot then return end
    if character.IsDead or character.Removed then return end

    if currentObjective == nil then return end

    local previousChoice = chosenWeapons[character]
    if previousChoice ~= nil then
        local inventory = character.Inventory
        if previousChoice.Removed or inventory == nil or not inventory.Contains(previousChoice) then
            chosenWeapons[character] = nil
            previousChoice = nil
        end
    end

    -- 检查切换冷却
    local lastTime = switchTimers[character]
    if lastTime ~= nil and currentTime - lastTime < Config.SwitchInterval then
        if previousChoice ~= nil then currentObjective.Weapon = previousChoice end
        return
    end

    -- 收集可用武器
    local weapons = CollectWeapons(character)
    if #weapons < Config.MinWeaponCount then
        if previousChoice ~= nil then currentObjective.Weapon = previousChoice end
        return
    end

    -- TryArm 已经先按引擎逻辑设置 Weapon; 若已有随机选择, 它才是实际当前武器.
    local currentWeapon = previousChoice or currentObjective.Weapon

    -- 检查是否存在优先武器 (CombatPriority > PriorityWeaponThreshold)
    -- 若存在, 则锁定该武器, 不进行随机切换
    for _, entry in ipairs(weapons) do
        if entry.priority > Config.PriorityWeaponThreshold then
            -- 若当前武器已是优先武器, 无需操作
            if currentWeapon == entry.item then
                currentObjective.Weapon = entry.item
                return
            end
            -- 切换到优先武器并清除随机选择记录
            currentObjective.Weapon = entry.item
            chosenWeapons[character] = nil
            LogDebug(character.Name .. " locked to priority weapon " .. tostring(entry.item.Name) .. " (priority: " .. entry.priority .. ")")
            return
        end
    end

    -- 从可用武器中排除当前武器, 构建候选列表
    local candidates = {}
    for _, entry in ipairs(weapons) do
        if currentWeapon == nil or entry.item ~= currentWeapon then
            candidates[#candidates + 1] = entry
        end
    end

    if #candidates == 0 then
        if previousChoice ~= nil then currentObjective.Weapon = previousChoice end
        return
    end

    -- 随机选择一把武器
    local selected = candidates[math.random(1, #candidates)]

    -- 赋值新武器 (Weapon setter 自动清空 _weaponComponent 缓存)
    currentObjective.Weapon = selected.item

    -- 记录切换时间和选择的武器
    switchTimers[character] = currentTime
    chosenWeapons[character] = selected.item

    LogDebug(character.Name .. " switched to " .. tostring(selected.item.Name) .. " (priority: " .. selected.priority .. ")")
end

-- ============================================================
-- Hook.Patch (After) on TryArm - 定时切换并阻止引擎覆盖随机武器
-- ============================================================
-- AIObjectiveCombat.TryArm() 无参数, 签名简单, 可被 Hook.Patch.
-- TryArm 每秒调用 GetWeapon 选择最高优先级武器并先赋值 instance.Weapon.
-- After hook 在 TryArm 执行后:
--   - 若 TryArm 返回 false (武器选择失败/武器为空), 清除 chosenWeapons 记录
--   - 若 TryArm 返回 true 且 chosenWeapons 中有有效记录, 将 Weapon 恢复为随机武器
--   - 若记录中的武器已失效(移除/不在物品栏), 清除记录

Hook.Patch(
    MOD_NAME .. ".GuardWeaponChoice",
    "Barotrauma.AIObjectiveCombat",
    "TryArm",
    {},
    function(instance, ptable)
        local currentTime = Timer.GetTime()
        CleanupTimers(currentTime)

        local character = instance.character
        if character == nil then return end

        -- TryArm 返回 false: 武器选择失败, 可能是随机武器弹药耗尽等
        -- 清除记录, 让引擎下次自行选择可用武器
        if ptable.ReturnValue == false then
            local hadChoice = chosenWeapons[character] ~= nil
            chosenWeapons[character] = nil
            if hadChoice then
                LogDebug("TryArm returned false, cleared choice for " .. character.Name)
            end
            return
        end

        ProcessCharacter(character, instance, currentTime)
    end,
    Hook.HookMethodType.After
)

Log("Initialized | SwitchInterval=" .. Config.SwitchInterval .. "s | MinWeaponCount=" .. Config.MinWeaponCount .. " | MinWeaponPriority=" .. Config.MinWeaponPriority .. " | PriorityWeaponThreshold=" .. Config.PriorityWeaponThreshold)
