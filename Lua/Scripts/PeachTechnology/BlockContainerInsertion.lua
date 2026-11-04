-- =====================================================================
-- BlockContainerInsertion.lua (容器准入强制拦截 - 按物品独立配置)
--
-- 功能:
--   即便原版规则允许 (容量足够 / Containable 匹配), 也强制禁止指定物品
--   进入其规则中配置的容器物品栏。规则按条独立配置, 互不影响:
--   每条规则 = "哪些物品" 禁止放入 "哪些容器"。
--   默认规则: tags=deep_gunsmith_weapon 的物品放不进
--   IOStorageTerminalFixed 容器的物品栏。
--
-- 规则结构 (BLOCK_RULES, 可任意增删):
--   itemTags          物品标签列表, 物品携带其中任意一个即命中 (可省略)
--   itemIdentifiers   物品标识符列表, 大小写不敏感 (可省略)
--   blockedContainers 目标容器标识符列表, 大小写不敏感 (必填)
--   itemTags 与 itemIdentifiers 至少填一项; 两者可同时填写 (并集关系)
--
-- 拦截点 (Hook.Patch Before):
--   Barotrauma.Items.Components.ItemContainer.CanBeContained(Item)        (L547)
--   Barotrauma.Items.Components.ItemContainer.CanBeContained(Item, int)   (L553)
--
--   CanBeContained 是容器物品栏准入的语义总闸, 全部动态放入路径都经过它:
--   - ItemInventory.FindAllowedSlot (ItemInventory.cs L30): 任意槽放入
--   - ItemInventory.CanBePutInSlot (ItemInventory.cs L50): 指定槽放入
--   由此覆盖: 客户端拖拽本地预测、服务器权威校验 (ServerSource/Items/
--   Inventory.cs L215 HandleAddedItems -> TryPutItem)、机器人 AI
--   (AIObjectiveLoadItem L308)、商店货物入柜 (CargoManager.cs L590)、
--   拖到容器实体上 (ItemContainer.Combine L845)。
--
--   不拦截 CanBeContained(ItemPrefab) 重载 (L560/L565): 仅用于 UI 预查询
--   与出生内容物判定, 不参与实际放入, 且 ItemPrefab 无实例级 HasTag API
--   (Tags 集合封送不可靠); 不拦截 ForceToSlot: 引擎交换失败回滚依赖它。
--   角色背包 (CharacterInventory) 不走 CanBeContained, 不受影响。
--
-- 多人同步:
--   shared 注册, 客户端与服务器各自拦截:
--   - 客户端: 拖拽在本地即被拒 (槽位红色边框高亮), 不产生脏的物品栏状态
--   - 服务器: 拦截所有客户端 (含未装脚本者) 的物品栏状态应用与 AI 操作,
--     被拒物品不入柜, 服务器随后的 corrective network event 会纠正客户端
--   - 单人/主机进程: SERVER 与 CLIENT 同进程, 双重生效
--
-- 性能:
--   容器命中判定按容器 Item.ID 缓存命中的规则列表 (数字键, MoonSharp
--   封送可靠), roundStart 清空; 未命中任何规则的容器仅一次表查询即返回;
--   物品条件检查仅在容器命中至少一条规则后, 对命中规则逐条执行;
--   标签检查使用预创建的 Identifier 对象, 避免每次调用的字符串转换。
-- =====================================================================

if not SERVER and not CLIENT then return end

-- ==================== 配置 ====================

local DEBUG_MODE = false

-- 规则列表: 每条规则独立生效
local BLOCK_RULES = {
    -- deep_gunsmith_weapon 物品禁止放入 IOStorageTerminalFixed
    {
        itemTags = { "deep_gunsmith_weapon" },
        blockedContainers = { "iostorageterminalfixed", "iostorage_terminal_fixed" },
    },
    -- 示例: 也可按物品 identifier 匹配, 或混合使用
    -- {
    --     itemIdentifiers = { "revolver" },
    --     itemTags = { "some_extra_tag" },
    --     blockedContainers = { "some_container" },
    -- },
}

-- ==================== 基础 ====================

local MOD_ID = "BlockContainerInsertion"

local function dbg(...)
    if DEBUG_MODE then print("[" .. MOD_ID .. "]", ...) end
end

-- ==================== 规则预处理 ====================

-- 编译后的规则列表, 元素结构:
--   index            规则序号 (从 1 开始, 与 BLOCK_RULES 对应, 用于日志)
--   tagIdentifiers   预创建的 Identifier 对象数组 (与 tagStrings 一一对应)
--   tagStrings       原始标签字符串 (仅用于日志输出)
--   itemIdSet        物品标识符集合 (统一小写)
--   containerIdSet   容器标识符集合 (统一小写)
local rules = {}
for i = 1, #BLOCK_RULES do
    local cfg = BLOCK_RULES[i]
    local rule = { index = i }

    if cfg.itemTags ~= nil and #cfg.itemTags > 0 then
        rule.tagIdentifiers = {}
        rule.tagStrings = {}
        for j = 1, #cfg.itemTags do
            rule.tagIdentifiers[j] = Identifier(cfg.itemTags[j])
            rule.tagStrings[j] = cfg.itemTags[j]
        end
    end

    if cfg.itemIdentifiers ~= nil and #cfg.itemIdentifiers > 0 then
        rule.itemIdSet = {}
        for j = 1, #cfg.itemIdentifiers do
            rule.itemIdSet[string.lower(cfg.itemIdentifiers[j])] = true
        end
    end

    if cfg.blockedContainers ~= nil and #cfg.blockedContainers > 0 then
        rule.containerIdSet = {}
        for j = 1, #cfg.blockedContainers do
            rule.containerIdSet[string.lower(cfg.blockedContainers[j])] = true
        end
    end

    -- 容器与物品条件缺一不可, 不完整规则直接忽略
    if rule.containerIdSet ~= nil and (rule.tagIdentifiers ~= nil or rule.itemIdSet ~= nil) then
        rules[#rules + 1] = rule
    else
        print("[" .. MOD_ID .. "] WARNING: rule " .. i .. " is incomplete and ignored (need blockedContainers + itemTags/itemIdentifiers)")
    end
end

-- 容器命中缓存: 容器 Item.ID -> 命中的规则数组 (无命中时为 false 哨兵,
-- Item.ID 回合内唯一且不复用)
local containerCache = {}

-- ==================== 判定 ====================

-- 返回该容器命中的规则数组 (nil 表示无命中)
local function GetRulesForContainer(containerComponent)
    local ownerItem = containerComponent.Item
    if ownerItem == nil then return nil end

    local itemId = ownerItem.ID
    local cached = containerCache[itemId]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local identValue = nil
    local prefab = ownerItem.Prefab
    if prefab ~= nil and prefab.Identifier ~= nil then
        local value = prefab.Identifier.Value
        if value ~= nil then identValue = string.lower(value) end
    end

    local matched = nil
    for r = 1, #rules do
        local rule = rules[r]
        if rule.containerIdSet[identValue] then
            matched = matched or {}
            matched[#matched + 1] = rule
        end
    end

    containerCache[itemId] = matched or false
    return matched
end

-- 检查物品是否命中规则, 返回命中原因字符串 (nil 表示未命中)
local function MatchesRule(item, rule)
    if rule.tagIdentifiers ~= nil then
        for i = 1, #rule.tagIdentifiers do
            if item.HasTag(rule.tagIdentifiers[i]) then
                return "tag=" .. rule.tagStrings[i]
            end
        end
    end
    if rule.itemIdSet ~= nil then
        local prefab = item.Prefab
        if prefab ~= nil and prefab.Identifier ~= nil then
            local value = prefab.Identifier.Value
            if value ~= nil and rule.itemIdSet[string.lower(value)] then
                return "id=" .. value
            end
        end
    end
    return nil
end

-- ==================== Hook 注册 ====================

-- Before 前缀: 命中规则时 PreventExecution = true 并 return false
-- (官方语义见 HookPatchTests.TestFullMethodReplacement/TestReturnBoxed:
--  跳过原方法并以 Lua 返回值作为方法返回值), 原版准入逻辑不执行
local function CanBeContainedPrefix(instance, ptable)
    local matchedRules = GetRulesForContainer(instance)
    if matchedRules == nil then return end

    local item = ptable["item"]
    if item == nil then return end

    for r = 1, #matchedRules do
        local rule = matchedRules[r]
        local reason = MatchesRule(item, rule)
        if reason ~= nil then
            ptable.PreventExecution = true
            local containerItem = instance.Item
            dbg("blocked:",
                tostring(item.Name),
                "rule=" .. rule.index,
                reason,
                "container=" .. (containerItem ~= nil and tostring(containerItem.Name) or "unknown"),
                "side=" .. (SERVER and "SERVER" or "CLIENT"))
            return false
        end
    end
end

-- 两个实例重载分别注册, 参数类型表消歧 (LuaPatcherService 按
-- GetMethod(name, types) 精确全签名匹配)
Hook.Patch("Barotrauma.Items.Components.ItemContainer", "CanBeContained",
    { "Barotrauma.Item" },
    CanBeContainedPrefix,
    Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.Items.Components.ItemContainer", "CanBeContained",
    { "Barotrauma.Item", "System.Int32" },
    CanBeContainedPrefix,
    Hook.HookMethodType.Before)

-- Item.ID 仅回合内唯一, 回合开始清空缓存防止跨回合误判
Hook.Add("roundStart", MOD_ID .. ".clearContainerCache", function()
    for itemId in pairs(containerCache) do
        containerCache[itemId] = nil
    end
end)

print("[" .. MOD_ID .. "] OK! rules=" .. #rules)
