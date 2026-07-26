-- AIRandomWeapon: AI在战斗中每隔固定时间随机切换使用另一把武器
--
-- 实现原理:
--   两个组件协同工作:
--
--   [1] think hook (节流, 仅服务端/单机):
--       扫描所有处于战斗状态(AIObjectiveCombat)的 human bot,
--       从物品栏收集所有 CombatPriority > 0 的武器, 若有 >= MinWeaponCount
--       把可用武器且距上次切换超过 SwitchInterval 秒, 则随机选择一把
--       不同于当前的武器, 通过 instance.Weapon = newItem 赋值,
--       并将该武器记录到 chosenWeapons 表中.
--
--   [2] Hook.Patch (After) on AIObjectiveCombat.TryArm:
--       TryArm 是引擎每秒调用的武器装备方法, 内部通过 GetWeapon 选择
--       最高优先级武器并赋值 instance.Weapon, 会覆盖 think hook 设置的随机武器.
--       After hook 在 TryArm 执行后拦截:
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
--   AIObjectiveCombat 仅服务端执行, think 回调用运行时守卫
--   if not SERVER and Game.IsMultiplayer then return end 拦截客户端.
--   TryArm 补丁仅在服务端 AI 逻辑中触发, 无需额外守卫.
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
-- Component 1: think hook - 定时切换随机武器
-- ============================================================
local function ProcessCharacter(character, currentTime)
    if not character.IsHuman or not character.IsBot then return end
    if character.IsDead or character.Removed then return end

    local aiController = character.AIController
    if aiController == nil then return end

    local objectiveManager = aiController.ObjectiveManager
    if objectiveManager == nil then return end

    local currentObjective = objectiveManager.CurrentObjective
    if currentObjective == nil then return end

    if not LuaUserData.IsTargetType(currentObjective, "Barotrauma.AIObjectiveCombat") then return end

    -- 检查切换冷却
    local lastTime = switchTimers[character]
    if lastTime ~= nil and currentTime - lastTime < Config.SwitchInterval then return end

    -- 收集可用武器
    local weapons = CollectWeapons(character)
    if #weapons < Config.MinWeaponCount then return end

    -- 检查是否存在优先武器 (CombatPriority > PriorityWeaponThreshold)
    -- 若存在, 则锁定该武器, 不进行随机切换
    for _, entry in ipairs(weapons) do
        if entry.priority > Config.PriorityWeaponThreshold then
            -- 若当前武器已是优先武器, 无需操作
            if currentObjective.Weapon == entry.item then return end
            -- 切换到优先武器并清除随机选择记录
            currentObjective.Weapon = entry.item
            chosenWeapons[character] = nil
            LogDebug(character.Name .. " locked to priority weapon " .. tostring(entry.item.Name) .. " (priority: " .. entry.priority .. ")")
            return
        end
    end

    -- 获取当前使用的武器
    local currentWeapon = currentObjective.Weapon

    -- 从可用武器中排除当前武器, 构建候选列表
    local candidates = {}
    for _, entry in ipairs(weapons) do
        if currentWeapon == nil or entry.item ~= currentWeapon then
            candidates[#candidates + 1] = entry
        end
    end

    if #candidates == 0 then return end

    -- 随机选择一把武器
    local chosen = candidates[math.random(1, #candidates)]

    -- 赋值新武器 (Weapon setter 自动清空 _weaponComponent 缓存)
    currentObjective.Weapon = chosen.item

    -- 记录切换时间和选择的武器
    switchTimers[character] = currentTime
    chosenWeapons[character] = chosen.item

    LogDebug(character.Name .. " switched to " .. tostring(chosen.item.Name) .. " (priority: " .. chosen.priority .. ")")
end

Hook.Add("think", MOD_NAME .. ".SwitchWeapons", function()
    if not SERVER and Game.IsMultiplayer then return end

    local currentTime = Timer.GetTime()

    for _, character in pairs(Character.CharacterList) do
        ProcessCharacter(character, currentTime)
    end

    CleanupTimers(currentTime)
end)

-- ============================================================
-- Component 2: Hook.Patch (After) on TryArm - 阻止引擎覆盖随机武器
-- ============================================================
-- AIObjectiveCombat.TryArm() 无参数, 签名简单, 可被 Hook.Patch.
-- TryArm 每秒调用 GetWeapon 选择最高优先级武器并赋值 instance.Weapon,
-- 会覆盖 think hook 设置的随机武器.
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
        local character = instance.character
        if character == nil then return end

        local chosen = chosenWeapons[character]
        if chosen == nil then return end

        -- TryArm 返回 false: 武器选择失败, 可能是随机武器弹药耗尽等
        -- 清除记录, 让引擎下次自行选择可用武器
        if ptable.ReturnValue == false then
            chosenWeapons[character] = nil
            LogDebug("TryArm returned false, cleared choice for " .. character.Name)
            return
        end

        -- 验证选择的武器是否仍在物品栏中
        if chosen.Removed or not character.Inventory.Contains(chosen) then
            chosenWeapons[character] = nil
            return
        end

        -- 将 Weapon 恢复为我们选择的随机武器
        instance.Weapon = chosen
    end,
    Hook.HookMethodType.After
)

Log("Initialized | SwitchInterval=" .. Config.SwitchInterval .. "s | MinWeaponCount=" .. Config.MinWeaponCount .. " | MinWeaponPriority=" .. Config.MinWeaponPriority .. " | PriorityWeaponThreshold=" .. Config.PriorityWeaponThreshold)
