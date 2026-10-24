-- HumanAiVision
-- 目标: 敌对 HumanAI 只有在"身体朝向"目标时才能发现并锁定玩家, 禁止背后探测.
--
-- 原版问题(源码依据):
--   1) HumanAIController.ReportProblems (HumanAIController.cs L1017-1126) 遍历
--      Character.GetVisibleHulls (Character.cs L5652-5698) 的结果; 该函数无条件
--      包含 CurrentHull, 随后用 AIObjectiveFightIntruders.IsValidTarget
--      (AIObjectiveFightIntruders.cs L59-81) 判定, 而该函数没有任何朝向/视线检查,
--      因此同一舱室内 360 度都能发现玩家并立即 AddCombatObjective.
--   2) HumanAIController.SpotEnemies (L542-578) 用头部 TransformedRotation 的
--      +-70 度锥形判定; 头部跟随光标独立旋转, 身体背对目标时头部仍可通过锥形,
--      之后的 Character.CanSeeTarget (Character.cs L2590-2601) 默认 checkFacing=false.
--   3) 目标建立后 AIObjectiveCombat.Attack (AIObjectiveCombat.cs L1436) 只校验视线,
--      不校验朝向, 依赖 HumanAIController.Update 的 Aim 转向 (L506-536) 纠正.
--
-- 本脚本只在"目标获取"阶段增加身体朝向门控, 不修改 CanSeeTarget 的全局语义:
--   A. AIObjectiveFightIntruders.IsValidTarget Before: 覆盖同舱室扫描/名单扫描路径.
--   B. HumanAIController.SpotEnemies Before/After 维护调用上下文, 并在
--      Character.CanSeeTarget After 中仅在上下文内把结果置为 false.
--      (不重写 SpotEnemies: 其内部使用 Lua 不可调用的泛型 IsCurrentObjective<T>)
--
-- 不影响的路径: RespondToAttack (被背后射击仍会反击并转身, 源码 L1300-1420 直接
--   AddCombatObjective), AIObjectiveCombat.Attack, 友方 AI 与友好 NPC, AI 对怪物
--   或敌方 NPC 的探测.
-- 多人: 仅在服务端注册补丁, AI 决策本就由服务端权威计算.

if not SERVER and Game.IsMultiplayer then return end

local MOD_NAME = "HumanAiVision"

local CONFIG = {
    Enabled = true,
    -- 总视野角(度); 半角 = 该值的一半. 180 度 = 整个前向半平面均可发现,
    -- 此时 cos²(半角) 趋近 0, 判定退化为 dx * Dir > 0 (正后方仍不可见).
    TotalFovDegrees = 180,
    -- true 时玩家队伍 AI 也受同样限制; 默认 false, 避免削弱己方 AI.
    AffectPlayerTeamAI = false,
    Debug = false,
}

local COS_HALF_FOV = math.cos(math.rad(CONFIG.TotalFovDegrees * 0.5))
local COS_HALF_SQ = COS_HALF_FOV * COS_HALF_FOV

-- HumanAIController.IsFriendly 是 public static, 需通过静态表访问
local HumanAIControllerStatic = LuaUserData.CreateStatic("Barotrauma.HumanAIController")

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if CONFIG.Debug then Log(msg) end
end

-- SpotEnemies 调用上下文深度: 只在 SpotEnemies 执行期间收紧 CanSeeTarget.
-- 使用计数而非 userdata 相等比较, 避免 MoonSharp 包装对象在 Lua 中的相等语义差异.
local spotDepth = 0
local spotSeer

local function IsCharacterLike(obj)
    return obj ~= nil and LuaUserData.HasMember(obj, "IsHuman")
end

-- 作用域: 只限制"敌对 HumanAI 对玩家队伍角色"的探测.
-- 玩家队友 AI 默认不受限; 友好 NPC/同队角色经 IsFriendly 排除.
local function IsScopedPair(seer, target)
    if not CONFIG.Enabled then return false end
    if not IsCharacterLike(seer) or not seer.IsHuman then return false end
    if not IsCharacterLike(target) or not target.IsHuman then return false end
    if not target.IsOnPlayerTeam then return false end
    if seer.IsOnPlayerTeam and not CONFIG.AffectPlayerTeamAI then return false end
    if HumanAIControllerStatic.IsFriendly(seer, target, false, false) then return false end
    return true
end

-- 身体朝向 FOV 判定(水平前向半平面 + 半角), 不使用开方.
-- Dir 为 Ragdoll.Dir(1 或 -1), 与 PhysicsBody.TransformedRotation 的朝向定义一致.
local function IsInBodyFov(seer, target)
    local anim = seer.AnimController
    if anim == nil then return true end
    local seerPos = seer.WorldPosition
    local targetPos = target.WorldPosition
    local dx = targetPos.X - seerPos.X
    local dy = targetPos.Y - seerPos.Y
    local forwardDot = dx * anim.Dir
    if forwardDot <= 0.0 then return false end
    return forwardDot * forwardDot >= COS_HALF_SQ * (dx * dx + dy * dy)
end

-- SpotEnemies 上下文进入/退出
local function OnSpotEnemiesBefore(instance, ptable)
    local character = instance.Character
    if character == nil then return end
    spotSeer = character
    spotDepth = spotDepth + 1
end

local function OnSpotEnemiesAfter(instance, ptable)
    spotDepth = spotDepth - 1
    if spotDepth <= 0 then
        spotDepth = 0
        spotSeer = nil
    end
end

-- 仅在 SpotEnemies 内部调用 CanSeeTarget 时收紧结果, 不改变其它调用方(含战斗瞄准).
local function OnCanSeeTargetAfter(instance, ptable)
    if spotDepth <= 0 or spotSeer == nil then return end
    local target = ptable["target"]
    if not IsCharacterLike(target) then return end
    if ptable.ReturnValue == false then return end
    if not IsScopedPair(spotSeer, target) then return end
    if IsInBodyFov(spotSeer, target) then return end
    ptable.ReturnValue = false
    LogDebug("SpotEnemies blocked: " .. spotSeer.Name .. " -> " .. target.Name)
end

-- 同舱室/名单扫描路径的 FOV 门控.
-- Before 钩子需同时设置 PreventExecution 与 ReturnValue, LuaPatcherService 才会跳过原方法.
local function OnIsValidTargetBefore(instance, ptable)
    local target = ptable["target"]
    local character = ptable["character"]
    if target == nil or character == nil then return end
    if not IsScopedPair(character, target) then return end
    if IsInBodyFov(character, target) then return end
    ptable.PreventExecution = true
    ptable.ReturnValue = false
    LogDebug("IsValidTarget blocked: " .. character.Name .. " -> " .. target.Name)
    return false
end

-- SpotEnemies 无参数, 使用不带 parameterTypes 的重载注册
Hook.Patch(MOD_NAME .. ".SpotEnemies.Before",
    "Barotrauma.HumanAIController", "SpotEnemies",
    OnSpotEnemiesBefore, Hook.HookMethodType.Before)
Hook.Patch(MOD_NAME .. ".SpotEnemies.After",
    "Barotrauma.HumanAIController", "SpotEnemies",
    OnSpotEnemiesAfter, Hook.HookMethodType.After)

-- CanSeeTarget 不带 parameterTypes 注册: LuaCs 类型解析器无法解析接口类型
-- Barotrauma.ISpatialEntity (ResolveMethod 会抛 invalid parameter type);
-- 该方法在 Character 中仅此一个重载 (Character.cs L2590), 按名称解析无歧义.
Hook.Patch(MOD_NAME .. ".CanSeeTarget.After",
    "Barotrauma.Character", "CanSeeTarget",
    OnCanSeeTargetAfter, Hook.HookMethodType.After)

Hook.Patch(MOD_NAME .. ".IsValidTarget.Before",
    "Barotrauma.AIObjectiveFightIntruders", "IsValidTarget",
    { "Barotrauma.Character", "Barotrauma.Character", "System.Boolean" },
    OnIsValidTargetBefore, Hook.HookMethodType.Before)

Log("patches applied | FOV=" .. tostring(CONFIG.TotalFovDegrees)
    .. " | AffectPlayerTeamAI=" .. tostring(CONFIG.AffectPlayerTeamAI))
