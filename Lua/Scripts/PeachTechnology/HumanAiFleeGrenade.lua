-- HumanAiFleeGrenade: AI 强制逃离已激活的威胁手雷 (deep_ai_escape 标签)
--
-- 功能:
--   任意人类 AI (HumanAIController) 与"已激活"的带标签威胁物品 距离不超过 detectionRange 时,
--   每帧强制覆写其移动向量使其远离该物品, 优先级高于一切 AI 目标
--   (战斗/维修/命令全部被压制); 威胁消失后原版 AI 下一帧自动接管, 无状态污染。
--   已激活判定: condition < activeThreshold (与物品自身告警阈值一致)。
--
-- 实现原理:
--   1. item.created / item.removed hook 增量跟踪带 deep_ai_escape 标签的物品实例, 不每帧全量遍历 Item.ItemList。
--   2. loaded / roundStart 时对 Item.ItemList 做一次初始扫描重建注册表 (覆盖加载前已存在实例)。
--   3. Hook.Patch 挂在 HumanAIController.Update 之后:
--      该方法内部已按 目标系统 -> steeringManager.Update -> host.Steering(即 AnimController.TargetMovement)
--      完成本帧移动决策, 补丁内写入 TargetMovement 即为该帧最终生效值
--      (MentalStateManager/ShipCommandManager 不写移动, 不会覆盖);
--      原版 AI 的路径与目标状态不受污染, 停止覆写后自然恢复。
--   4. 双节流: 全局激活列表刷新 (refreshInterval) + 每 AI 重新评估 (recheckInterval);
--      每帧路径仅剩 O(1) 状态查表 + 一次属性写入。
--   5. 激活手雷坐标解析: 物品在容器/角色物品栏内时物理体已禁用 (WorldPosition 停留在存入位置),
--      沿 ParentInventory.Owner 链上溯取持有者实时坐标; 自由态直接用 item.WorldPosition。
--   6. 逃离期间开火抑制: Before 补丁拦截 AIObjectiveCombat.UseWeapon (原版与 NFF 复制版
--      Attack 的共同开火咽喉), 仅 fleeing 态 PreventExecution; 非逃离态零动作,
--      超视距限射完全交由 EnemyBattleBehavior 的同名 UseWeapon 补丁管辖, 二者兼容。
--
-- 多人同步说明:
--   多人游戏 AI 逻辑仅服务端运行, NPC 移动经服务端->客户端常规同步复制;
--   单人模式下照常运行。

local MOD_NAME = "HumanAiFleeGrenade"

local CONFIG = {
    -- 感知半径 (世界像素)
    detectionRange = 1300,
    -- condition < 该值视为已激活
    activeThreshold = 90,
    -- 全局激活列表刷新周期 (秒)
    refreshInterval = 0.2,
    -- 每 AI 重新评估周期 (秒, 与原版敌人检测节奏一致)
    recheckInterval = 0.2,
    -- 调试日志开关
    debug = false,
}

-- 目标物品标签 (小写): 携带该标签的物品均视为威胁源, 多个手雷物品共用同一标签即可
-- 判定走 Item.HasTag(Identifier) 公开方法 (tags ∪ Prefab.Tags 的哈希查找, O(1) 零分配),
-- 不使用 ItemPrefab.Tags.Contains (该成员未注册到 MoonSharp, Lua 不可访问)
local TARGET_TAG = "deep_ai_escape"

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if CONFIG.debug then Log(msg) end
end

-- 预编译常量: 感知半径平方 (BuildConfig 中赋值)
local sqrRange = 0.0

-- 全局激活列表刷新计时
local lastRefreshTime = 0.0

-- 物品注册表: 键为带目标标签的物品实例
local trackedGrenades = {}

-- 目标标签的 Identifier 实例: 服务端引导段创建, TrackItem 闭包捕获
local targetTagId = nil

-- 激活列表: 数组, 元素为复用的坐标缓存 { x, y, holder }
local activeGrenades = {}

-- 每 AI 逃离状态: 弱键表, 元素 { fleeing, fleeX, fleeY, nextRecheck }
local aiState = setmetatable({}, { __mode = "k" })

-- 朝向枚举: Barotrauma.Direction 不在 LuaCs 默认枚举表内 (LibShared.lua 仅注册 28 个枚举),
-- 需通过 CreateEnumTable 自行创建, 否则全局 Direction 为 nil
local Direction = nil

local function BuildConfig()
    if type(CONFIG.detectionRange) ~= "number" or CONFIG.detectionRange <= 0 then
        CONFIG.detectionRange = 1200
        Log("Invalid detectionRange, reset to 1200")
    end
    if type(CONFIG.activeThreshold) ~= "number" then
        CONFIG.activeThreshold = 90
        Log("Invalid activeThreshold, reset to 90")
    end
    if type(CONFIG.refreshInterval) ~= "number" or CONFIG.refreshInterval <= 0 then
        CONFIG.refreshInterval = 0.2
        Log("Invalid refreshInterval, reset to 0.2")
    end
    if type(CONFIG.recheckInterval) ~= "number" or CONFIG.recheckInterval <= 0 then
        CONFIG.recheckInterval = 0.2
        Log("Invalid recheckInterval, reset to 0.2")
    end
    sqrRange = CONFIG.detectionRange * CONFIG.detectionRange
end

-- 解析激活手雷的世界坐标与归属角色 (归属角色用于自持守卫, 防止逃离自身造成零向量)
local function ResolvePosition(item)
    local current = item
    while current.ParentInventory ~= nil do
        local invOwner = current.ParentInventory.Owner
        if invOwner == nil then break end
        if LuaUserData.IsTargetType(invOwner, "Barotrauma.Character") then
            local pos = invOwner.WorldPosition
            return pos.X, pos.Y, invOwner
        end
        current = invOwner
    end
    local pos = current.WorldPosition
    return pos.X, pos.Y, nil
end

-- 重建激活列表: 仅收录 condition 低于阈值的存活实例, 坐标缓存复用避免每周期分配
local function RefreshActiveGrenades()
    local count = 0
    for item in pairs(trackedGrenades) do
        if item.Removed then
            -- 安全网: item.removed 未触发时清理残留项
            trackedGrenades[item] = nil
        elseif item.Condition < CONFIG.activeThreshold then
            count = count + 1
            local entry = activeGrenades[count]
            if entry == nil then
                entry = {}
                activeGrenades[count] = entry
            end
            entry.x, entry.y, entry.holder = ResolvePosition(item)
        end
    end
    for i = #activeGrenades, count + 1, -1 do
        activeGrenades[i] = nil
    end
end

-- 重新评估单个 AI 的逃离向量: 汇总感知范围内全部威胁的加权方向, 归一化后乘奔跑速度
local function RecheckCharacter(character, state)
    local pos = character.WorldPosition
    local px, py = pos.X, pos.Y
    local dirX, dirY = 0.0, 0.0
    local threat = false

    for i = 1, #activeGrenades do
        local entry = activeGrenades[i]
        if entry.holder ~= character then
            local dx, dy = px - entry.x, py - entry.y
            local distSq = dx * dx + dy * dy
            if distSq <= sqrRange then
                threat = true
                local dist = math.sqrt(distSq)
                -- 距离越近权重越高 (1 - dist/range); 零距离时方向退化, 跳过累加
                if dist > 0.001 then
                    local weight = 1.0 - dist / CONFIG.detectionRange
                    dirX = dirX + (dx / dist) * weight
                    dirY = dirY + (dy / dist) * weight
                end
            end
        end
    end

    if not threat then
        if state.fleeing then
            state.fleeing = false
            LogDebug("Flee end: " .. character.Name)
        end
        return
    end

    local lenSq = dirX * dirX + dirY * dirY
    -- 方向完全退化 (如威胁相互抵消) 时保持上一次向量, 不做切换
    if lenSq < 1e-6 then return end

    local len = math.sqrt(lenSq)
    local speed = character.AnimController:GetCurrentSpeed(true)
    state.fleeX = dirX / len * speed
    state.fleeY = dirY / len * speed
    if not state.fleeing then
        state.fleeing = true
        LogDebug("Flee start: " .. character.Name)
    end
end

-- 每帧覆写移动向量与朝向: 面向威胁方向倒退撤离 (复刻原版 AIObjectiveFindSafety.UpdateSimpleEscape 惯例)
local function ApplyFlee(character, state)
    local anim = character.AnimController
    anim.TargetMovement = Vector2(state.fleeX, state.fleeY)
    anim.TargetDir = state.fleeX < 0 and Direction.Right or Direction.Left
end

local function TrackItem(item)
    if trackedGrenades[item] ~= nil then return end
    if not item:HasTag(targetTagId) then return end
    trackedGrenades[item] = true
end

-- 初始扫描/回合重建: 清空注册表与全部运行时状态后全扫一次 Item.ItemList
local function ScanExistingItems()
    for item in pairs(trackedGrenades) do
        trackedGrenades[item] = nil
    end
    for character in pairs(aiState) do
        aiState[character] = nil
    end
    for i = #activeGrenades, 1, -1 do
        activeGrenades[i] = nil
    end
    lastRefreshTime = 0.0
    for _, item in pairs(Item.ItemList) do
        TrackItem(item)
    end
end

-- 仅服务端/单机加载: AI 逻辑仅服务端运行 (与 init.lua 服务端脚本守卫一致)
if SERVER or not Game.IsMultiplayer then

    local HumanAIControllerStatic = LuaUserData.CreateStatic("Barotrauma.HumanAIController")
    Direction = LuaUserData.CreateEnumTable("Barotrauma.Direction")
    local IdentifierStatic = LuaUserData.CreateStatic("Barotrauma.Identifier")
    targetTagId = IdentifierStatic(TARGET_TAG)

    -- 增量跟踪: 覆盖回合内新产出的目标实例
    Hook.Add("item.created", MOD_NAME .. ".TrackItem", function(item)
        TrackItem(item)
    end)

    Hook.Add("item.removed", MOD_NAME .. ".UntrackItem", function(item)
        trackedGrenades[item] = nil
    end)

    Hook.Add("loaded", MOD_NAME .. ".ScanLoaded", function()
        ScanExistingItems()
    end)

    Hook.Add("roundStart", MOD_NAME .. ".ScanRoundStart", function()
        ScanExistingItems()
    end)

    -- 开火抑制补丁: 逃离期间禁止武器使用 (AIObjectiveCombat.UseWeapon 是 Attack 与
    -- NFF 复制版 Attack 的共同开火咽喉), 非逃离态直接返回, 控制权完全交还
    -- EnemyBattleBehavior 的同名 UseWeapon 限射补丁 (超视距拦截), 二者互不干扰
    Hook.Patch(MOD_NAME .. ".SuppressFire", "Barotrauma.AIObjectiveCombat", "UseWeapon", { "System.Single" },
    function(instance, ptable)
        local character = instance.character
        local state = character ~= nil and aiState[character] or nil
        if state ~= nil and state.fleeing then
            ptable.PreventExecution = true
        end
    end, Hook.HookMethodType.Before)

    -- 主补丁: 在 HumanAIController.Update 之后执行, 覆写结果为该帧最终生效移动
    -- 参数类型必须显式给出 (Update(Single)): LuaPatcherService 对传入的参数表做精确签名匹配,
    -- 空表会被解析为无参 Update() 而找不到方法
    Hook.Patch(MOD_NAME .. ".ForceFlee", "Barotrauma.HumanAIController", "Update", { "System.Single" },
    function(instance, ptable)
        local character = instance.Character
        -- 镜像原版 Update 顶部守卫: 移除/死亡/失能/禁用 AI 的角色不处理
        if HumanAIControllerStatic.DisableCrewAI
            or character == nil
            or character.Removed
            or character.IsDead
            or character.IsIncapacitated then
            return
        end

        -- 全局激活列表刷新 (节流)
        local now = Timer.GetTime()
        if now - lastRefreshTime >= CONFIG.refreshInterval then
            lastRefreshTime = now
            RefreshActiveGrenades()
        end

        local state = aiState[character]
        if state == nil then
            state = { fleeing = false, fleeX = 0.0, fleeY = 0.0, nextRecheck = 0.0 }
            aiState[character] = state
        end

        -- 快速路径: 无激活手雷且未在逃离, 零开销返回
        if #activeGrenades == 0 and not state.fleeing then
            return
        end

        -- 节流重评逃离向量
        if now >= state.nextRecheck then
            state.nextRecheck = now + CONFIG.recheckInterval
            RecheckCharacter(character, state)
        end

        -- 每帧覆写 (逃离中)
        if state.fleeing then
            ApplyFlee(character, state)
        end
    end, Hook.HookMethodType.After)

    BuildConfig()
    Log("Initialized | Range=" .. CONFIG.detectionRange
        .. " | ActiveThreshold=" .. CONFIG.activeThreshold
        .. " | Tag=" .. TARGET_TAG)
end
