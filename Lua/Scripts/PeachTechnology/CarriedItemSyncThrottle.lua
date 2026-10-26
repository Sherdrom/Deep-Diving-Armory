--[[
    CarriedItemSyncThrottle.lua
    功能：按刚体状态与调用栈分流优化容器内部物品与携带物品的逐帧刚体同步,
          消除移动时的性能骤增: 手持容器保持原版实时同步 (枪械类需求),
          装备栏与普通库存格节流, 白名单容器内部物品完全跳过,
          角色直接携带物品 (路径A) 维持分窗节流。

    路径A (角色直接携带物品):
        原版 Character.Update (Character.cs L3513-3523) 在角色位移超过约 0.32 显示单位
        (DistanceSquared 阈值 0.1, 约合 3 毫米) 时, 每帧对物品栏内全部"刚体已禁用"的物品
        调用 Item.SetTransform, 内含 Farseer 刚体变换同步 (PhysicsBody.cs L787-796) 与
        broadphase 代理移动。携带 100 件物品即每帧 100 次物理调用。
        Hook Item.SetTransform Before, 过滤条件 = 物品栏内 + 刚体禁用 +
        所有者 = 当前正在执行 Update 的角色本人 (Character.Update Before 打调用栈标记、
        After 出栈清除, 标记仅存活于该角色 Update 栈内, L3469 全类唯一方法名):
        原版循环只遍历角色物品栏顶层物品 (GetAllItems 不递归),
        容器内部物品 (枪内弹匣、弹匣内弹丸) 的发射流程复位 (Projectile.cs L494)、
        事件驱动重定位等调用所有者不是角色本人, 一律放行保持原版弹道精度。

    路径B (容器内部物品, 如手持/穿着的背包):
        原版 ItemContainer.Update (ItemContainer.cs L642-644) 仅在容器直接位于
        CharacterInventory 时每帧调用 SetContainedItemPositionsIfNeeded; 其位置阈值
        (ItemContainer.cs L746-752, DistanceSquared > 10, 约合 3.2 显示单位) 被物品随
        跑步的摆动动画持续突破, 导致每帧执行 SetContainedItemPositions (L948): 对每件
        内部物品执行 Farseer 变换同步 (L1019) + UpdateDrawPosition + rect 重算 +
        Submarine/CurrentHull 传播, 并递归嵌套容器 (L1040)。容器落在地上且刚体 Awake
        时 (L687-693) 同样每帧触发。嵌套容器自身不满足 L642 条件, 仅经根容器递归调用。

        前置拦截 (SetContainedItemPositionsIfNeeded 入口, L744, private 方法,
        全源码仅 Update L644/L691 两处调用, 方法体为纯阈值检查+全量同步, 无其他
        副作用; OnContaining 等状态效果在 Update 其他分支, 不受影响):
        刚体禁用/无刚体的不透明容器 (HideItems=true, 即 L642 门条件限定的
        穿戴/普通库存格类) 整体 PreventExecution, 逐帧阈值检查一并跳过,
        移动时内部物品零位置计算, 消除周期性批量同步尖峰; 透明容器
        (HideItems=false, 内容物可见) 放行走原窗口节流, 避免内容物绘制冻结穿帮;
        刚体启用容器 (手持/世界Awake) 放行, 由下游 SetContainedItemPositions
        钩子分流。L642 的 CharacterInventory 门条件使该拦截天然只命中穿戴类,
        世界物品栏 (柜/箱) 内的容器不经 Update 触发, 不受影响。

        分流规则 (作用于 SetContainedItemPositions 入口):
        1) 白名单容器: 内部物品完全跳过 (见白名单节), 不区分容器位置;
        2) 容器刚体启用中 (手持物品/地上物品/无刚体): 放行并打同帧放行标记,
           原版实时同步, 枪械类内部物品 (弹匣/弹丸) 需每帧跟随手部摆动,
           地上容器保持原版 L687-693 Awake 分支行为;
        3) 嵌套容器 (刚体禁用) 且直接父容器持有本帧标记: 跟随放行并传播标记。
           递归调用 (L1040 经 Item.cs L1957 转发) 只发生在父同步栈内, 跟随使
           手持容器嵌套链 (枪→弹匣→弹丸) 实时、装备容器窗口帧内批量同步完整;
        4) 其余刚体禁用调用 (取出/放入/Move 等事件驱动定位与无标记嵌套):
           按 owner.ID 分窗节流 (直接携带时键为角色ID, 与路径A共用窗口;
           窗口帧内同样打标记); 穿戴容器经前置拦截后仅事件驱动调用到达此处;
        5) 刚体状态与实时/节流需求的对应依据: 手持物品刚体启用 (AnimController
           持握跟随对象, AnimController.cs L593 每帧 SetTransform), 装备槽与
           普通格物品刚体禁用 (正是路径A原版循环 L3513-3523 的处理类), 地上
           物品刚体启用, 嵌套物品刚体禁用且仅经根容器递归调用 (L642 条件限定
           自触发只发生在容器直接位于 CharacterInventory 时)。

    节流机制 (两条路径共用):
        Hook.Patch 目标方法 (Before), 按同步主体 ID 分窗: 窗口每 SYNC_INTERVAL 秒开启一次,
        同一帧内该主体的全部调用批量放行 (对齐原版单帧循环语义, 避免批量同步被截断),
        窗口外置 PreventExecution 跳过原方法。Timer.Time 基于 Timing.TotalTime
        (LuaCsTimer.cs L12-13), 逐帧恒定, 同帧调用必然相等。

    白名单 (仅路径B):
        CONTAINER_WHITELIST 中的容器 (按物品 prefab identifier 匹配, 如 deep_6sh118)
        内部物品完全跳过位置同步: 命中即无条件 PreventExecution, 不参与节流窗口,
        内部物品零位置计算。嵌套递归 (外层 L1040 -> Item.cs L1957-1963 转发) 亦经过
        同一 public 入口, 白名单嵌套容器同样被拦截。

    安全性 (基于源码逐点核实)：
        路径A:
        1) 丢弃落点: Item.Drop 自行传送刚体 (Item.cs L3546-3549) 并置 transformDirty
           强制刷新隔舱归属 (Item.cs L3572), 不依赖被节流的循环;
        2) 拾取路径 (Inventory.cs L684-691): SetTransform 为同位置无操作, 拦截无状态损失;
        3) AI 物品重定位 (HumanAIController.cs L898): 调用前刚执行 Drop, 刚体已启用, 放行;
        4) 丢弃时的容器定位 (Item.cs L3559): 刚体刚被启用, 放行;
        5) 持握物品跟随手部 (AnimController.cs L593): 刚体启用中, 放行 (保证手持跟随精度);
        6) 原版循环只同步直接携带物品 (GetAllItems 不递归嵌套物品栏,
           Inventory.cs L335-371), 故 ParentInventory.Owner 必为角色。
        路径B:
        1) 节流与白名单只作用于装备槽/普通库存格中的容器; 手持槽容器与
           地上容器保持原版实时同步, 枪械类跟随精度无损;
        2) 容器内物品不可见 (原版背包不透明), 滞后无视觉表现;
        3) 从容器取出物品: 取出路径自行定位 (手持跟随/丢弃自同步/移入物品栏走路径A);
        4) 透明容器 (内容物可见) 的内容物绘制位置最多滞后 SYNC_INTERVAL 秒, 属可接受代价;
        5) 翻转/编辑器等事件驱动调用同样被节流, 最多延迟一个窗口周期, 状态无损;
        6) ItemContainer.Move 覆写 (L518-521) 与 Insert/Remove 路径最终都汇入
           SetContainedItemPositions, 单点节流全覆盖, 无遗漏入口;
        7) 嵌套容器随根容器判定: 根被节流时递归不发生, 根窗口帧内嵌套随批量放行,
           与原版单帧批量语义一致;
        8) 类型探测被禁止: LuaCs 对已注册类型访问不存在成员会抛错
           (cannot access field AnimController of userdata<Item>), 回调内所有
           成员访问仅限 Item/Inventory/PhysicsBody/Character 确定存在的成员;
           路径A的目标类判定不用类型探测, 用 Character.Update 调用栈标记
           (所有者=正在 Update 的角色本人) 精确圈定原版循环调用;
        9) 嵌套跟随标记是弹道修复的核心: 嵌套容器 (如枪内弹匣) 刚体禁用, 若按
           自身窗口独立节流, 手持枪械每帧放行的递归同步被截断, 弹匣内弹丸的
           刚体位置/旋转滞后, 发射时 Projectile.Use 取 item.body.Rotation
           (L463) 与 item.body.SimPosition (L486) 得到旧值, 射线一半从枪口
           出发方向正确、一半从弹匣旧位置出发指向旧瞄准方向; 标记按帧失效
           (Timer.Time 同帧相等), 实体 ID 全局唯一无键冲突;
        10) 容器同步内部为刚体级调用 (L1019 SetTransformIgnoreContacts), 不经过
            Item.SetTransform, 路径A不拦截同步本身;
        11) 穿戴容器前置冻结的语义与白名单一致: 内容物世界坐标停在放入/上次同步
            时的值, 仅影响 InWater/NotInWater 类效果判定与依赖世界坐标的第三方
            脚本; 取出路径 (手持跟随/丢弃自同步/移入物品栏走路径A) 与容器丢弃
            落地 (刚体启用转世界Awake分支) 均恢复定位; OnContaining/OnWearing
            等状态效果在 Update 的独立分支, 冻结不影响其逐帧执行;
        12) SetContainedItemPositionsIfNeeded 为 private 方法, LuaCs Hook.Patch
            经 BindingFlags.NonPublic 解析 (Turret.TryLaunch 已验证先例),
            全源码单声明无重载, name-only 查找安全。

    残余影响：
        白名单容器与不透明穿戴容器 (装备槽/普通库存格) 内部物品无滞后上限: 世界坐标
        停在放入/上次同步时的值直到取出, 仅影响 InWater/NotInWater 类状态效果判定与
        依赖这些物品世界坐标的第三方脚本; 取出路径 (手持跟随/丢弃自同步/移入物品栏
        走路径A) 自行定位, 容器丢弃落地后刚体启用恢复实时同步, 无残留问题。
        透明穿戴容器与携带物品本体仍在窗口节流内, 最多滞后 SYNC_INTERVAL 秒;
        手持容器实时同步, 丢弃与投掷落点不受影响。

    作用域：
        双端独立运行, 无网络协议交互, 任意一端单独安装均安全。
        客户端节省本地与视野内角色的开销, 服务器节省全部角色的开销, 多人收益最大。

    调试：
        DEBUG_MODE = true 时输出窗口开启与节流计数日志, 供 F3 性能面板对比验证
        (重点观察 Update:Character / Update:MapEntity:Items 分区在静止/移动两种状态下的差值)。
]]

local DEBUG_MODE = false

-- 节流间隔(秒): 0.25 = 保守 (残余滞后小, 节流率约 96%), 0.5 = 激进 (节流率约 98%)
local SYNC_INTERVAL = 0.25

-- 状态清理周期(秒)与条目最大存活时间(秒), 防止长回合中状态表随实体更替无限增长
local STATE_PRUNE_INTERVAL = 60.0
local STATE_MAX_AGE = 120.0

-- 容器白名单: 表内 prefab identifier 对应的容器, 内部物品完全跳过逐帧位置同步
-- (命中即无条件 PreventExecution, 不参与节流窗口, 内部物品零位置计算)
-- 适用于内容物不可见的封闭容器; 内容物可见的容器加入后, 内部物品绘制位置停在放入时的值
local CONTAINER_WHITELIST = {
    deep_6sh118 = true,
}

-- [同步主体ID] = 该主体上次放行窗口开启时的 Timer.Time
-- 路径A的键为物品栏所有者(角色)ID, 路径B的键同为 owner.ID:
-- 容器直接在角色物品栏时=角色ID (与路径A共用窗口), 嵌套时=外层容器物品ID
-- 实体 ID 全局唯一不冲突; 嵌套调用仅发生在根容器同步的同一帧, 窗口节奏自然对齐
local passTimes = {}
local lastPruneTime = -STATE_PRUNE_INTERVAL

-- 容器同步的同帧放行标记: [容器物品ID] = 最近一次放行 SetContainedItemPositions 时的 Timer.Time
-- 嵌套容器的递归调用 (ItemContainer.cs L1040 经 Item.cs L1957 转发) 发现直接父容器
-- 持有本帧标记时跟随放行并传播, 保证手持容器 (每帧实时同步) 的嵌套链实时、
-- 装备容器窗口帧内的批量同步完整传导; 标记仅同帧有效 (Timer.Time 逐帧恒定, LuaCsTimer.cs L12-13)
local syncPassStamps = {}

-- 原版携带循环的调用栈标记: Character.Update Before 记录当前正在更新的角色 ID 与时间戳,
-- After 清除 (标记仅存活于 Character.Update 栈内, 不泄漏到同帧的物品更新阶段)
-- 路径A仅节流 "所有者=该角色本人" 的调用 (即原版循环 L3513-3523 的目标类),
-- 其余场景 (枪械发射流程、容器同步、事件驱动重定位) 的调用者不是角色本人, 一律放行
local loopCharacterId = nil
local loopStamp = -1.0

local debugPassCount = 0
local debugBlockCount = 0

local function Log(message)
    print("[CarriedItemSyncThrottle] " .. message)
end

local function PruneState(now)
    if now - lastPruneTime < STATE_PRUNE_INTERVAL then
        return
    end
    lastPruneTime = now
    local removed = 0
    for stateKey, passTime in pairs(passTimes) do
        -- passTime > now + 1 兼容回合重开导致的时钟回退
        if passTime > now + 1.0 or now - passTime > STATE_MAX_AGE then
            passTimes[stateKey] = nil
            removed = removed + 1
        end
    end
    for stampKey, stampTime in pairs(syncPassStamps) do
        if stampTime > now + 1.0 or now - stampTime > STATE_MAX_AGE then
            syncPassStamps[stampKey] = nil
            removed = removed + 1
        end
    end
    if DEBUG_MODE and removed > 0 then
        Log("state pruned, removed=" .. removed)
    end
end

-- 窗口判定: 返回 true = 放行(可能同时开启新窗口), false = 节流(调用方置 PreventExecution)
local function AllowOrOpenWindow(stateKey)
    local now = Timer.Time
    PruneState(now)

    local lastPass = passTimes[stateKey]
    if lastPass ~= nil then
        if now == lastPass then
            -- 同帧窗口开启中: 放行本次逐帧循环批量的剩余调用
            return true
        end
        if now > lastPass and now - lastPass < SYNC_INTERVAL then
            -- 窗口间隔内: 节流
            return false
        end
    end

    -- 开启新窗口 (now < lastPass 的时钟回退场景同样落在此处, 自动覆盖旧状态)
    passTimes[stateKey] = now
    return true
end

-- 路径A辅助: Character.Update Before 记录当前正在更新的角色 (原版携带循环
-- L3513-3523 的唯一来源栈), After 出栈清除, 防止标记泄漏到同帧稍后的
-- 物品更新阶段 (否则该阶段所有者=该角色的事件驱动调用会被误节流)
local function OnCharacterUpdate(instance, ptable)
    loopCharacterId = instance.ID
    loopStamp = Timer.Time
end

local function OnCharacterUpdateAfter(instance, ptable)
    loopCharacterId = nil
    loopStamp = -1.0
end

-- 路径A: 角色物品栏内禁用刚体物品的逐帧 Item.SetTransform (Character.cs L3513-3523)
local function OnItemSetTransform(instance, ptable)
    -- 快速路径1: 不在物品栏内 → 放行 (世界中绝大多数 SetTransform 调用)
    local inventory = instance.ParentInventory
    if inventory == nil then
        return
    end

    -- 快速路径2: 无刚体或刚体启用中 → 原版循环的 continue 分支,
    -- 以及丢弃/拾取/AI重定位/持握跟随等事件驱动调用 → 放行
    local body = instance.body
    if body == nil or body.Enabled then
        return
    end

    -- 至此命中: 物品栏内且刚体已禁用的物品 (原版逐帧同步的目标类)
    local owner = inventory.Owner
    if owner == nil then
        return
    end

    -- 调用栈判别: 仅节流原版循环内的调用 (所有者=当前正在 Update 的角色本人);
    -- 枪械发射流程的跨射线复位 (Projectile.cs L494)、事件驱动重定位等
    -- 场景发生在其他栈内, 标记已出栈清除, 一律放行保持原版弹道精度
    if owner.ID ~= loopCharacterId or loopStamp ~= Timer.Time then
        return
    end

    if AllowOrOpenWindow(owner.ID) then
        if DEBUG_MODE then
            debugPassCount = debugPassCount + 1
            if debugPassCount % 50 == 1 then
                Log("pathA pass opened, ownerId=" .. owner.ID .. ", itemId=" .. instance.ID
                    .. ", passes=" .. debugPassCount .. ", blocked=" .. debugBlockCount)
            end
        end
        return
    end

    ptable.PreventExecution = true
    if DEBUG_MODE then
        debugBlockCount = debugBlockCount + 1
    end
end

-- 路径B前置拦截: ItemContainer.Update 的逐帧触发源 (L644 穿戴分支 / L691 世界Awake分支)
-- 刚体禁用/无刚体的不透明穿戴容器整体冻结 (阈值检查一并跳过, 移动时零位置计算,
-- 消除 0.25s 窗口的批量同步尖峰); 透明容器与刚体启用容器放行走下游分流
-- 注意: 仅访问 Item/PhysicsBody/ItemContainer.HideItems (public, L92, 纯字段读取)
--       上确定存在的成员, 禁止任何类型探测
local function OnContainerSetContainedItemPositionsIfNeeded(instance, ptable)
    local containerItem = instance.Item
    if containerItem == nil then
        return
    end

    -- 启用中 = 手持容器 / 世界Awake容器 (L691 分支): 放行, 阈值检查后经
    -- SetContainedItemPositions 钩子分流 (枪械实时同步/白名单跳过)
    local body = containerItem.body
    if body ~= nil and body.Enabled then
        return
    end

    -- 透明容器 (内容物可见): 放行, 保持原窗口节流, 避免内容物绘制冻结穿帮
    if not instance.HideItems then
        return
    end

    -- 禁用/无刚体的不透明容器 (L642 门条件限定的 CharacterInventory 直属类):
    -- 整体 PreventExecution; 世界物品栏 (柜/箱) 内的容器不经 Update 触发,
    -- 不会到达此处, 其插入定位仍由 SetContainedItemPositions 钩子窗口节流
    ptable.PreventExecution = true
end

-- 路径B: 容器内部物品的逐帧重定位 (ItemContainer.cs L642-644 / L687-693 → L948)
-- 分流: 白名单无条件跳过; 刚体启用 (手持/地上) 放行走原版实时;
--       刚体禁用 (装备槽/普通格/嵌套) 按 owner.ID 分窗节流
-- 注意: 仅访问 Item/Inventory/PhysicsBody 上确定存在的成员,
--       LuaCs 对已注册类型访问不存在成员会抛错, 禁止任何类型探测
local function OnContainerSetContainedItemPositions(instance, ptable)
    local containerItem = instance.Item
    if containerItem == nil then
        return
    end

    -- 白名单: 内部物品完全不做位置同步 (嵌套递归经 Item.cs L1961 转发到同一
    -- public 入口, 白名单嵌套容器同样被拦截)
    if CONTAINER_WHITELIST[tostring(containerItem.Prefab.Identifier)] then
        ptable.PreventExecution = true
        return
    end

    -- 刚体状态分流 (对应依据见头部注释路径B分流规则4):
    -- 启用中 = 手持物品 (AnimController 持握跟随对象) / 地上物品 (L687-693
    -- Awake 分支) / 无刚体物品 → 原版实时同步, 枪械跟随精度无损
    local body = containerItem.body
    if body == nil or body.Enabled then
        -- 手持/地上容器本帧实时同步: 打同帧放行标记, 供嵌套容器跟随传播
        syncPassStamps[containerItem.ID] = Timer.Time
        return
    end

    -- 禁用 = 装备槽/普通库存格/嵌套容器: 相对载体静止, 分窗节流
    local inventory = containerItem.ParentInventory
    if inventory == nil then
        return -- 防御: 刚体禁用却不在物品栏的理论外场景, 放行
    end

    local owner = inventory.Owner
    if owner == nil then
        return
    end

    -- 嵌套跟随: 递归调用只发生在直接父容器的同步栈内, 父持有本帧标记时
    -- 跟随放行并传播标记; 缺失此跟随会把手持枪械的嵌套链 (枪→弹匣→弹丸)
    -- 截断为独立 0.25s 窗口, 发射射线起点与方向将取到滞后的刚体状态
    if syncPassStamps[owner.ID] == Timer.Time then
        syncPassStamps[containerItem.ID] = Timer.Time
        return
    end

    -- 直接携带时键=角色ID (与路径A共用窗口); 嵌套时键=外层容器物品ID,
    -- 嵌套调用仅发生在根容器同步的同一帧, 窗口节奏与根的放行自然对齐
    if AllowOrOpenWindow(owner.ID) then
        -- 窗口帧放行: 打标记供自身嵌套链传播 (装备容器批量同步完整传导)
        syncPassStamps[containerItem.ID] = Timer.Time
        if DEBUG_MODE then
            debugPassCount = debugPassCount + 1
            if debugPassCount % 50 == 1 then
                Log("pathB pass opened, ownerId=" .. owner.ID
                    .. ", containerId=" .. containerItem.ID
                    .. ", passes=" .. debugPassCount .. ", blocked=" .. debugBlockCount)
            end
        end
        return
    end

    ptable.PreventExecution = true
    if DEBUG_MODE then
        debugBlockCount = debugBlockCount + 1
    end
end

Hook.Patch("CarriedItemSyncThrottle.OnItemSetTransform", "Barotrauma.Item", "SetTransform", OnItemSetTransform, Hook.HookMethodType.Before)
Hook.Patch("CarriedItemSyncThrottle.OnContainerSetContainedItemPositionsIfNeeded", "Barotrauma.Items.Components.ItemContainer", "SetContainedItemPositionsIfNeeded", OnContainerSetContainedItemPositionsIfNeeded, Hook.HookMethodType.Before)
Hook.Patch("CarriedItemSyncThrottle.OnContainerSetContainedItemPositions", "Barotrauma.Items.Components.ItemContainer", "SetContainedItemPositions", OnContainerSetContainedItemPositions, Hook.HookMethodType.Before)
Hook.Patch("CarriedItemSyncThrottle.OnCharacterUpdate", "Barotrauma.Character", "Update", OnCharacterUpdate, Hook.HookMethodType.Before)
Hook.Patch("CarriedItemSyncThrottle.OnCharacterUpdateAfter", "Barotrauma.Character", "Update", OnCharacterUpdateAfter, Hook.HookMethodType.After)
