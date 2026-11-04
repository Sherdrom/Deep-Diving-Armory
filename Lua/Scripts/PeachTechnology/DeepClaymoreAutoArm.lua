-- DeepClaymoreAutoArm: 阔剑地雷敌近自动布防
--
-- 功能:
--   按物品分组配置触发阵营, 检测矩形区域内存在匹配阵营的存活生物时将物品 condition 写为
--   conditionValue (默认 99, 等价于 CustomInterface "阔剑地雷开关" 的布防值):
--     - itemsNonTeam (敌我识别阔剑, 原版): 仅非 team1 生物触发
--     - itemsTeam1   (敌方阔剑):           仅 team1 生物触发, 其他生物不触发
--     - itemsAny     (无识别阔剑):         任意存活生物触发, 无视阵营
--   分组表置空 {} 即禁用该类; 实际引爆的对象筛选由各物品 XML 爆炸 StatusEffect 的
--   Conditional 决定 (原版为 deep_enemy_affliction_resistance gt 0.5), 脚本仅负责"开保险"
--
-- 与 XML 联动说明 (weapon/explosive/explosive.xml):
--   - 布防态 = condition 99 (TickBox 写入), 解除态 = condition 100
--   - Holdable OnContained 每 0.9s 强制 condition=100, 爆炸判定要求 condition <= 99 且 OnNotContained
--   - 因此仅处理未收纳 (ParentInventory == nil) 的已布置物品, 不与收纳解除逻辑互斥
--
-- 实现原理:
--   1. item.created / item.removed hook 增量跟踪目标物品, loaded / roundStart 全量重建注册表,
--      不每帧全量遍历 Item.ItemList
--   2. think 主循环按 scanInterval 节流; 每次扫描先构建全部存活角色的肢体包围盒与阵营
--      标记快照, 再对每个未收纳目标物品按其触发模式做矩形相交判定 (覆盖角色全身含脚部),
--      命中即布防
--   3. condition 已等于目标值时跳过写入, 避免冗余属性写入与同步流量
--   4. 双重保险: 布防写入前再次校验 OnNotContained 与未被移除, 确保 condition=99 只会
--      写入未收纳状态 (ParentInventory == nil, 与游戏源码 StatusEffect.cs 的
--      ActionType.OnNotContained 判定一致) 的物品, 杜绝物品栏内布防
--
-- 多人同步说明:
--   仅服务端/单机运行; item.Condition 修改走服务端常规状态同步复制到客户端, 无需客户端脚本

local MOD_NAME = "DeepClaymoreAutoArm"

-- 布防触发模式
local MODE_NON_TEAM = 1 -- 仅非 team1 生物触发
local MODE_TEAM1 = 2    -- 仅 team1 生物触发
local MODE_ANY = 3      -- 任意存活生物触发

local CONFIG = {
    -- 敌我识别阔剑: 检测到非 team1 生物时布防 (可自定义增删, 置空 {} 禁用)
    itemsNonTeam = {
        "deep_claymore",
        "deep_claymore_left",
    },
    -- 敌方阔剑: 检测到 team1 生物时布防, 其他生物不触发 (可自定义增删, 置空 {} 禁用)
    itemsTeam1 = {
        "deep_claymore_enemy",
        "deep_claymore_left_enemy",
    },
    -- 无识别阔剑: 检测到任何存活生物时布防, 无视阵营 (可自定义增删, 置空 {} 禁用)
    itemsAny = {
        "deep_claymore_dangerous_right",
        "deep_claymore_dangerous_left",
    },
    -- 矩形检测区域 宽/高 (世界像素, 可自定义), 默认取自 deep_claymore 贴图 sourcerect 256x93
    detectWidth = 102,
    detectHeight = 37,
    -- 命中后写入的 condition 值 (可自定义, 99 = 布防态)
    conditionValue = 0,
    -- 扫描周期 (秒)
    scanInterval = 0.25,
    -- 调试日志开关
    debug = false,
}

-- identifier -> 触发模式 查找表 (小写键), BuildConfig 中构建
local identifierMode = {}

-- 预编译常量: 矩形检测区域半宽/半高
local halfW, halfH = 0.0, 0.0

-- think 主循环上次扫描时间
local lastScanTime = 0.0

-- 物品注册表: 键为目标物品实例, 值为触发模式
local trackedItems = {}

-- 角色碰撞体快照: 复用数组, 元素 { x, y, halfW, halfH, isTeam1 }
local threats = {}

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if CONFIG.debug then Log(msg) end
end

local function BuildConfig()
    local categories = {
        { key = "itemsNonTeam", mode = MODE_NON_TEAM, fallback = "deep_claymore" },
        { key = "itemsTeam1", mode = MODE_TEAM1, fallback = "deep_claymore_enemy" },
        { key = "itemsAny", mode = MODE_ANY, fallback = "deep_claymore_dangerous_right" },
    }
    for i = 1, #categories do
        local category = categories[i]
        local list = CONFIG[category.key]
        if type(list) ~= "table" then
            list = { category.fallback }
            CONFIG[category.key] = list
            Log("Invalid " .. category.key .. ", reset to " .. category.fallback)
        end
        for j = 1, #list do
            identifierMode[string.lower(list[j])] = category.mode
        end
    end
    if type(CONFIG.detectWidth) ~= "number" or CONFIG.detectWidth <= 0 then
        CONFIG.detectWidth = 256
        Log("Invalid detectWidth, reset to 256")
    end
    if type(CONFIG.detectHeight) ~= "number" or CONFIG.detectHeight <= 0 then
        CONFIG.detectHeight = 93
        Log("Invalid detectHeight, reset to 93")
    end
    if type(CONFIG.conditionValue) ~= "number" then
        CONFIG.conditionValue = 99
        Log("Invalid conditionValue, reset to 99")
    end
    if type(CONFIG.scanInterval) ~= "number" or CONFIG.scanInterval <= 0 then
        CONFIG.scanInterval = 0.25
        Log("Invalid scanInterval, reset to 0.25")
    end
    halfW = CONFIG.detectWidth * 0.5
    halfH = CONFIG.detectHeight * 0.5
end

local function TrackItem(item)
    if trackedItems[item] ~= nil then return end
    local prefab = item.Prefab
    if prefab == nil then return end
    local mode = identifierMode[string.lower(tostring(prefab.Identifier))]
    if mode == nil then return end
    trackedItems[item] = mode
end

-- 回合重建: 清空注册表后对 Item.ItemList 全扫一次, 覆盖加载前已存在实例
local function ScanExistingItems()
    for item in pairs(trackedItems) do
        trackedItems[item] = nil
    end
    for _, item in pairs(Item.ItemList) do
        TrackItem(item)
    end
end

-- 构建角色快照: 全部存活角色的肢体包围盒与 team1 阵营标记
-- (死亡/失能不触发, 与传感器 IgnoreDead 语义一致)
-- WorldPosition 是躯干中心, 站立时远离地面, 直接判定会导致敌人躺下才触发;
-- PhysicsBody.WorldRect 对 Lua 不可访问 (cannot access field), 因此遍历
-- AnimController.Limbs 的 WorldPosition 取包围盒 (剔除已断肢体, 防止断肢飞出拉大范围),
-- 覆盖角色全身含脚部, 站立经过即命中; 肢体缺失时退化为躯干中心点判定
local function BuildThreatSnapshot()
    local count = 0
    for _, character in pairs(Character.CharacterList) do
        if not character.Removed
            and not character.IsDead
            and not character.IsIncapacitated then
            count = count + 1
            local entry = threats[count]
            if entry == nil then
                entry = {}
                threats[count] = entry
            end
            local minX, maxX, minY, maxY
            local anim = character.AnimController
            local limbs = anim ~= nil and anim.Limbs or nil
            if limbs ~= nil then
                for _, limb in pairs(limbs) do
                    if not limb.IsSevered then
                        local p = limb.WorldPosition
                        if minX == nil then
                            minX, maxX = p.X, p.X
                            minY, maxY = p.Y, p.Y
                        else
                            if p.X < minX then minX = p.X end
                            if p.X > maxX then maxX = p.X end
                            if p.Y < minY then minY = p.Y end
                            if p.Y > maxY then maxY = p.Y end
                        end
                    end
                end
            end
            if minX ~= nil then
                entry.x = (minX + maxX) * 0.5
                entry.y = (minY + maxY) * 0.5
                entry.halfW = (maxX - minX) * 0.5
                entry.halfH = (maxY - minY) * 0.5
            else
                local pos = character.WorldPosition
                entry.x = pos.X
                entry.y = pos.Y
                entry.halfW = 0.0
                entry.halfH = 0.0
            end
            entry.isTeam1 = character.TeamID == CharacterTeamType.Team1
        end
    end
    return count
end

-- OnNotContained 判定: 与游戏源码 StatusEffect.cs 的判定完全一致
-- (case ActionType.OnNotContained: item.ParentInventory == null 时才生效),
-- ParentInventory ~= nil 即物品位于容器/角色物品栏/手持槽内
local function IsNotContained(item)
    return item.ParentInventory == nil
end

-- 布防写入: 写入前再次校验未被移除且处于 OnNotContained 状态, 双重保险确保
-- condition=99 只会写入未收纳的已布置物品, 杜绝物品栏内布防
local function ArmItem(item, ix, iy)
    if item.Removed then return end
    if not IsNotContained(item) then return end
    if math.abs(item.Condition - CONFIG.conditionValue) <= 0.01 then return end
    item.Condition = CONFIG.conditionValue
    LogDebug("Armed: " .. tostring(item.Prefab.Identifier)
        .. " at " .. string.format("%.0f,%.0f", ix, iy))
end

-- 单次扫描: 快速路径 (无目标物品/无角色) 零分配返回, 按物品触发模式匹配后布防
local function Scan()
    -- O(1) 检查: 回合内无目标物品时跳过角色快照构建, 空场零开销
    if next(trackedItems) == nil then return end
    local threatCount = BuildThreatSnapshot()
    if threatCount == 0 then return end

    for item, mode in pairs(trackedItems) do
        if item.Removed then
            -- 安全网: item.removed 未触发时清理残留项
            trackedItems[item] = nil
        elseif IsNotContained(item) then
            local pos = item.WorldPosition
            local ix, iy = pos.X, pos.Y
            for i = 1, threatCount do
                local entry = threats[i]
                -- 模式过滤: 敌方雷仅匹配 team1, 原版雷仅匹配非 team1, 无识别雷全匹配
                if (mode == MODE_ANY
                        or (mode == MODE_TEAM1 and entry.isTeam1)
                        or (mode == MODE_NON_TEAM and not entry.isTeam1)) then
                    -- 矩形相交判定: 检测矩形与角色碰撞体 AABB 重叠即命中 (含脚部),
                    -- 轴对齐, 中心距 <= 半宽和/半高和
                    local dx = ix - entry.x
                    local reachW = halfW + entry.halfW
                    if dx <= reachW and dx >= -reachW then
                        local dy = iy - entry.y
                        local reachH = halfH + entry.halfH
                        if dy <= reachH and dy >= -reachH then
                            ArmItem(item, ix, iy)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- 仅服务端/单机加载: condition 修改仅在服务端生效 (与 init.lua 服务端脚本守卫一致)
if SERVER or not Game.IsMultiplayer then

    -- 增量跟踪: 覆盖回合内新产出的目标实例
    Hook.Add("item.created", MOD_NAME .. ".TrackItem", function(item)
        TrackItem(item)
    end)

    Hook.Add("item.removed", MOD_NAME .. ".UntrackItem", function(item)
        trackedItems[item] = nil
    end)

    Hook.Add("loaded", MOD_NAME .. ".ScanLoaded", function()
        ScanExistingItems()
    end)

    Hook.Add("roundStart", MOD_NAME .. ".ScanRoundStart", function()
        ScanExistingItems()
    end)

    -- 主循环: think 每帧进入, 内部按 scanInterval 节流
    Hook.Add("think", MOD_NAME .. ".Think", function()
        local now = Timer.GetTime()
        if now - lastScanTime < CONFIG.scanInterval then return end
        lastScanTime = now
        Scan()
    end)

    BuildConfig()
    Log("Initialized | Width=" .. CONFIG.detectWidth
        .. " Height=" .. CONFIG.detectHeight
        .. " | Condition=" .. CONFIG.conditionValue
        .. " | NonTeam=" .. #CONFIG.itemsNonTeam
        .. " | Team1=" .. #CONFIG.itemsTeam1
        .. " | Any=" .. #CONFIG.itemsAny)
end
