-- ContainerConditionTransfer: 同容器耐久转移 (压弹机)
--
-- 功能:
--   当配置的耐久增加物品 (target, 如弹匣) 与耐久减少物品 (source, 如大弹药箱)
--   位于同一个指定容器中时, 耐久按配置速率随时间渐进转移:
--     target.Condition += gainPerSecond * dt
--     source.Condition -= gainPerSecond * dt * drainRatio
--   增量与减量严格成比例 (drainRatio = drainPerSecond / gainPerSecond), 任一侧被
--   钳制时另一侧同步等比缩放, 总消耗恒等于总填充 x drainRatio;
--   当 target 耐久达到 fullCondition (默认 100) 后立即停止 source 的耐久消耗;
--   当 source 耗尽后转移自然停止。
--
-- 实现原理:
--   1. 预编译配置表: 容器 identifier/tag 集合与配方 target/source 查询表 (identifier 直查 +
--      标签规则, 解析结果按 identifier 缓存), 事件入口与周期枚举均为 O(1) 热路径。
--   2. inventoryPutItem 事件精确感知物品放入容器, 命中配置容器与配方物品即标记激活。
--   3. think 节流复核: 仅遍历激活集, 单次枚举容器 OwnInventory.AllItemsMod 收集配方物品
--      并执行转移; 容器内配方物品全部离开后自动修剪出激活集, 覆盖取走/移动/消耗的
--      所有无事件退出路径。
--   4. loaded / roundStart 全扫一次 Item.ItemList, 覆盖脚本加载前已存在的实例;
--      item.created 覆盖未经 PutItem 直接载入内容物的新容器。
--   5. 耐久写入仅服务端权威执行 (与 init.lua 服务端脚本守卫一致);
--      服务端 SetCondition 内部自动钳制 [0, MaxCondition] 并排队条件更新同步客户端
--      (Item.cs L2256 / L2293-2309)。
--
-- 多人同步说明:
--   全部逻辑仅服务端运行, 客户端零逻辑零补丁, 耐久条由服务端条件更新自动同步;
--   单人模式下照常运行。

local MOD_NAME = "ContainerConditionTransfer"

local CONFIG = {
    -- think 处理周期 (秒)
    checkInterval = 0.25,
    -- 单周期 dt 上限 (秒), 防服务器卡顿后耐久突跳
    maxDeltaTime = 1.0,
    -- 调试日志开关
    debug = false,
    -- 容器定义: identifier 与 tag 二选一, 可混用多条
    containers = {
        { tag = "deep_condition_transfer" },
        -- { tag = "magpress" },
    },
    -- 配方: 同容器内 target 耐久渐进增加, source 耐久渐进减少
    --   target/source 支持两种形式:
    --     "identifier"        按物品 identifier 精确匹配
    --     { tag = "tagname" } 按物品标签匹配
    --   多配方可共用同一 identifier/tag (如多容量弹匣共用同一弹药箱), 命中物品参与全部命中配方
    --   gainPerSecond 目标每秒耐久增量 (必须为正)
    --   drainPerSecond来源每秒耐久减量 (与增量严格成比例, 比例 = drainPerSecond / gainPerSecond)
    --   fullCondition 目标达到该耐久后停止转移 (不再消耗来源)
    recipes = {
        -- 铅制弹药
        {
            target = { tag = "lead_ammobox_reload_1" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_2" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_3" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_4" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_5" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_6" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_7" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "lead_ammobox_reload_8" },
            source = "ammobox1",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 钛制弹药
        {
            target = { tag = "tit_ammobox_reload_0_25" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 25.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_0_33" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 18.75,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_0_5" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 12.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_1" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_2" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_3" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_4" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_5" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_6" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_7" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tit_ammobox_reload_8" },
            source = "ammobox_7.62",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 刚素弹药
        {
            target = { tag = "phy_ammobox_reload_0_25" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 25.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_0_33" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 18.75,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_0_5" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 12.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_1" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_2" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_3" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_4" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_5" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_6" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_7" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ammobox_reload_8" },
            source = "ammobox_12.7",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 雷刚弹药
        {
            target = { tag = "phy_ful_ammobox_reload_0_5" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 12.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_1" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_2" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_3" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_4" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_5" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_6" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_7" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "phy_ful_ammobox_reload_8" },
            source = "ammobox_phy_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 钨刚弹药
        {
            target = { tag = "tun_ful_ammobox_reload_0_16" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 37.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_0_5" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 12.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_1" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_2" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_3" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_4" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_5" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_6" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_7" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "tun_ful_ammobox_reload_8" },
            source = "ammobox_tun_ful",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 贫铀弹药
        {
            target = { tag = "du_ammobox_reload_0_5" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 12.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_1" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_2" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_3" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_4" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_5" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_6" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_7" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "du_ammobox_reload_8" },
            source = "ammobox_du",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- RIP弹药
        {
            target = { tag = "rip_ammobox_reload_1" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 6.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_2" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 3.125,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_3" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 2.0833,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_4" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 1.5625,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_5" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 1.25,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_6" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 1.0417,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_7" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 0.8926,
            fullCondition = 100.0,
        },
        {
            target = { tag = "rip_ammobox_reload_8" },
            source = "ammobox_rip",
            gainPerSecond = 100.0,
            drainPerSecond = 0.78125,
            fullCondition = 100.0,
        },

        -- 陶瓷修理包
        {
            target = { tag = "ceramic_repair_tool_22" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 22.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_25" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 25.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_28_5" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 28.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_33" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 33.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_40" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 40.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_50" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 50.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_66" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 66.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "ceramic_repair_tool_100" },
            source = "deep_plate_repair_tool_ceramic",
            gainPerSecond = 100.0,
            drainPerSecond = 100.0,
            fullCondition = 100.0,
        },

        -- 复合修理包
        {
            target = { tag = "composite_repair_tool_28_5" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 28.5,
            fullCondition = 100.0,
        },
        {
            target = { tag = "composite_repair_tool_33" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 33.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "composite_repair_tool_40" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 40.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "composite_repair_tool_50" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 50.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "composite_repair_tool_66" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 66.0,
            fullCondition = 100.0,
        },
        {
            target = { tag = "composite_repair_tool_100" },
            source = "deep_plate_repair_tool_composite",
            gainPerSecond = 100.0,
            drainPerSecond = 100.0,
            fullCondition = 100.0,
        },

        -- 新增配方: 复制以下模板并填写
        -- {
        --     target = "magazine_identifier",   -- 或 { tag = "magazine_tag" }
        --     source = "ammobox_identifier",    -- 或 { tag = "ammobox_tag" }
        --     gainPerSecond = 20.0,
        --     drainPerSecond = 10.0,
        --     fullCondition = 100.0,
        -- },
    },
}

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if CONFIG.debug then Log(msg) end
end

-- 预编译配置表 (BuildConfig 在服务端守卫内填充)
local containerByIdentifier = {} -- 小写容器 identifier -> true
local containerTagNames = {}     -- 小写容器标签名数组
local containerTagIds = {}       -- Identifier 实例数组 (守卫内构造)
local recipeByTargetId = {}      -- 小写目标 identifier -> 配方数组 (多配方可共用同一 identifier)
local recipeBySourceId = {}      -- 小写来源 identifier -> 配方数组 (同上)
local targetTagRules = {}        -- { name, id = Identifier 实例, recipe = recipe } (守卫内构造)
local sourceTagRules = {}        -- 同上

-- 配方物品引用解析: 字符串形式记入 identifier 表, 表形式 { tag = ... } 记入标签规则
-- 返回两个键名供 BuildConfig 写入对应集合
local function ResolveItemRef(value)
    if type(value) == "string" then
        return { identifier = string.lower(value) }
    end
    if type(value) == "table" and type(value.tag) == "string" then
        return { tag = string.lower(value.tag) }
    end
    return nil
end

-- 容器配置校验: identifier 或 tag 至少提供一项
local function IsValidContainerEntry(index, entry)
    if type(entry) ~= "table" then
        Log("Invalid container entry (not a table) at index " .. index)
        return false
    end
    if type(entry.identifier) ~= "string" and type(entry.tag) ~= "string" then
        Log("Invalid container entry, requires 'identifier' or 'tag' string at index " .. index)
        return false
    end
    return true
end

-- 配方配置校验: target/source 引用与数值字段齐全且数值合法
local RECIPE_REF_FIELDS = { "target", "source" }
local RECIPE_NUMBER_FIELDS = { "gainPerSecond", "drainPerSecond", "fullCondition" }

local function IsValidRecipeEntry(index, entry)
    if type(entry) ~= "table" then
        Log("Invalid recipe entry (not a table) at index " .. index)
        return false
    end
    for _, field in ipairs(RECIPE_REF_FIELDS) do
        if ResolveItemRef(entry[field]) == nil then
            Log("Invalid recipe entry, field '" .. field
                .. "' must be an identifier string or a { tag = string } table at index " .. index)
            return false
        end
    end
    for _, field in ipairs(RECIPE_NUMBER_FIELDS) do
        if type(entry[field]) ~= "number" then
            Log("Invalid recipe entry, field '" .. field .. "' must be a number at index " .. index)
            return false
        end
    end
    if entry.fullCondition <= 0.0 then
        Log("Invalid recipe entry, 'fullCondition' must be positive at index " .. index)
        return false
    end
    if entry.gainPerSecond <= 0.0 then
        Log("Invalid recipe entry, 'gainPerSecond' must be positive at index " .. index)
        return false
    end
    if entry.drainPerSecond < 0.0 then
        Log("Invalid recipe entry, 'drainPerSecond' must not be negative at index " .. index)
        return false
    end
    return true
end

local function BuildConfig()
    local containerCount = 0
    for index, entry in ipairs(CONFIG.containers) do
        if IsValidContainerEntry(index, entry) then
            if type(entry.identifier) == "string" then
                containerByIdentifier[string.lower(entry.identifier)] = true
            end
            if type(entry.tag) == "string" then
                local lowerTag = string.lower(entry.tag)
                local seen = false
                for _, existing in ipairs(containerTagNames) do
                    if existing == lowerTag then
                        seen = true
                        break
                    end
                end
                if not seen then
                    table.insert(containerTagNames, lowerTag)
                end
            end
            containerCount = containerCount + 1
        end
    end

    local recipeCount = 0
    for index, entry in ipairs(CONFIG.recipes) do
        if IsValidRecipeEntry(index, entry) then
            local recipe = {
                gainPerSecond = entry.gainPerSecond,
                -- 比例系数: 目标每 +1 耐久对应来源 -ratio 耐久 (gain/drain 严格成比例,
                -- 收尾钳制与帧率抖动均按比例同步缩放, 总消耗 = 总填充 x ratio)
                drainRatio = entry.drainPerSecond / entry.gainPerSecond,
                fullCondition = entry.fullCondition,
            }
            local targetRef = ResolveItemRef(entry.target)
            local sourceRef = ResolveItemRef(entry.source)
            if targetRef.identifier ~= nil then
                local list = recipeByTargetId[targetRef.identifier]
                if list == nil then
                    list = {}
                    recipeByTargetId[targetRef.identifier] = list
                end
                table.insert(list, recipe)
            else
                table.insert(targetTagRules, { name = targetRef.tag, recipe = recipe })
            end
            if sourceRef.identifier ~= nil then
                local list = recipeBySourceId[sourceRef.identifier]
                if list == nil then
                    list = {}
                    recipeBySourceId[sourceRef.identifier] = list
                end
                table.insert(list, recipe)
            else
                table.insert(sourceTagRules, { name = sourceRef.tag, recipe = recipe })
            end
            recipeCount = recipeCount + 1
        end
    end

    Log("Initialized with " .. containerCount .. " container(s) and " .. recipeCount .. " recipe(s)")
end

-- 仅服务端/单机加载: 耐久写入必须由服务端权威执行 (与 init.lua 服务端脚本守卫一致)
if SERVER or not Game.IsMultiplayer then

    local IdentifierStatic = LuaUserData.CreateStatic("Barotrauma.Identifier")
    LuaUserData.RegisterType("VCE_VirtualizedMagazine.VirtualizedMagazine")

    -- 5.56 虚拟弹匣按选定弹药箱装填，原配方只提供容量对应的速率与消耗。
    local virtualAmmo = {
        ["ammobox1"] = "5.56x45round",
        ["ammobox_7.62"] = "5.56x45round_tit",
        ["ammobox_12.7"] = "5.56x45round_phy",
        ["ammobox_phy_ful"] = "556x45round_M995",
        ["ammobox_tun_ful"] = "556x45round_SSA_AP",
        ["ammobox_du"] = "556x45round_depleted_uranium",
    }
    local virtualMagazineTag = IdentifierStatic("556mag")

    local function GetVirtualMagazine(item)
        local container = item.OwnInventory and item.OwnInventory.Container
        if container and LuaUserData.IsTargetType(container, "VCE_VirtualizedMagazine.VirtualizedMagazine") then
            return container
        end
    end

    local function RefillVirtualMagazine(job, dt)
        local target, source, magazine, recipe = job.target, job.source, job.magazine, job.recipe
        local remaining = math.min(magazine.MaxSize - magazine.LoadedCount, job.remaining)
        if remaining <= 0 then return "done" end
        local costPerRound = recipe.fullCondition * recipe.drainRatio / magazine.MaxSize
        local affordable = costPerRound > 0 and math.floor(source.Condition / costPerRound + 1e-6) or remaining
        if affordable <= 0 then return "empty" end
        local ammoId = virtualAmmo[string.lower(tostring(source.Prefab.Identifier))]
        local progress = math.min(remaining, job.progress
            + recipe.gainPerSecond * dt * magazine.MaxSize / recipe.fullCondition)
        local count = math.min(math.floor(progress + 1e-6), affordable)
        if count > 0 then
            local rounds = {}
            for i = 1, count do rounds[i] = IdentifierStatic(ammoId) end
            local before = magazine.LoadedCount
            magazine.PushAmmoArray(rounds)
            local loaded = magazine.LoadedCount - before
            source.Condition = math.max(0, source.Condition - loaded * costPerRound)
            job.remaining = job.remaining - loaded
            progress = progress - loaded
            if loaded < count then return "rejected" end
        end
        -- Keep fractional loading time, never charge for rejected or incomplete rounds.
        job.progress = math.max(0, math.min(progress, 1))
        if job.remaining == 0 or magazine.LoadedCount == magazine.MaxSize then return "done" end
    end

    BuildConfig()

    -- 构造容器标签 Identifier 实例 (HasTag 判定入口, Prefab.Tags.Contains 未注册到 MoonSharp 不可用)
    for i = 1, #containerTagNames do
        containerTagIds[i] = IdentifierStatic(containerTagNames[i])
    end
    for i = 1, #targetTagRules do
        targetTagRules[i].id = IdentifierStatic(targetTagRules[i].name)
    end
    for i = 1, #sourceTagRules do
        sourceTagRules[i].id = IdentifierStatic(sourceTagRules[i].name)
    end

    -- 激活集: 键为容器物品实例, 值为运行时状态 { lastWorkLog }
    local activeContainers = {}

    -- 容器判定: 命中配置容器 identifier 或 tag
    -- 调用前提: 入参为 Item 实例 (Item.ItemList 迭代/item.created 事件均保证)
    local function IsConfiguredContainer(item)
        if containerByIdentifier[string.lower(tostring(item.Prefab.Identifier))] then
            return true
        end
        for i = 1, #containerTagIds do
            if item:HasTag(containerTagIds[i]) then return true end
        end
        return false
    end

    -- 物品角色解析缓存: 小写 identifier -> { targets = 配方数组, sources = 配方数组 }
    -- identifier 为物品的固有属性, HasTag 判定结果对其恒定, 缓存后同 identifier 零重复判定
    local resolveCache = {}

    -- 无角色共享常量: 普通物品 (绝大多数) 引用同一表, 解析零分配
    local EMPTY_ROLES = { targets = {}, sources = {} }

    -- 物品角色解析: identifier 数组与标签规则全部收集 (多配方可共用同一 identifier/tag),
    -- 命中多个配方的物品参与全部命中配方, 需避免配置歧义
    local function ResolveItemRoles(item)
        local idLower = string.lower(tostring(item.Prefab.Identifier))
        local cached = resolveCache[idLower]
        if cached ~= nil then return cached end

        local roles = {
            targets = {},
            sources = {},
        }
        local identifierList = recipeByTargetId[idLower]
        if identifierList ~= nil then
            for i = 1, #identifierList do
                table.insert(roles.targets, identifierList[i])
            end
        end
        for i = 1, #targetTagRules do
            if item:HasTag(targetTagRules[i].id) then
                table.insert(roles.targets, targetTagRules[i].recipe)
            end
        end
        identifierList = recipeBySourceId[idLower]
        if identifierList ~= nil then
            for i = 1, #identifierList do
                table.insert(roles.sources, identifierList[i])
            end
        end
        for i = 1, #sourceTagRules do
            if item:HasTag(sourceTagRules[i].id) then
                table.insert(roles.sources, sourceTagRules[i].recipe)
            end
        end

        if #roles.targets == 0 and #roles.sources == 0 then
            resolveCache[idLower] = EMPTY_ROLES
            return EMPTY_ROLES
        end
        resolveCache[idLower] = roles
        return roles
    end

    -- 激活标记: 登记容器实例 (幂等)
    local function ActivateContainer(container)
        if activeContainers[container] == nil then
            activeContainers[container] = { lastWorkLog = 0.0 }
            LogDebug("Container activated: " .. tostring(container.Prefab.Identifier))
        end
    end

    LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.CustomInterface"], "customInterfaceElementList")

    local function PressStatus(container, status, job)
        local interface = container.GetComponentString("CustomInterface")
        if not interface then return end
        local text = TextManager.Get("dda.magpress." .. status).Value
        if job then
            text = text:gsub("%[loaded%]", tostring(job.total - job.remaining)):gsub("%[total%]", tostring(job.total))
        end
        interface.Labels = "dda.magpress.source,dda.magpress.target,dda.magpress.count," .. text .. ",dda.magpress.stop"
    end

    local function StopPress(container, status)
        local state = activeContainers[container]
        PressStatus(container, status, state and state.virtualJob)
        if state then state.virtualJob = nil end
    end

    Hook.Add("dda.magpress.start", MOD_NAME .. ".StartPress", function(effect, deltaTime, container)
        if not container or tostring(container.Prefab.Identifier) ~= "ammoreload_machine" then return end
        -- shortcut: controlled mixed-ammo loading is single-player until VCE synchronizes its stack.
        if Game.IsMultiplayer then PressStatus(container, "singleplayer"); return end
        ActivateContainer(container)
        local state = activeContainers[container]
        if state.virtualJob then return end
        local interface = container.GetComponentString("CustomInterface")
        if not interface or not container.OwnInventory then return end
        local values, index = {}, 0
        for _, element in pairs(interface.customInterfaceElementList) do
            index = index + 1
            values[index] = tonumber(element.Signal)
            if index == 3 then break end
        end
        local sourceSlot, targetSlot, count = values[1], values[2], values[3]
        local function valid(value, minimum, maximum)
            return value and value >= minimum and value <= maximum and value == math.floor(value)
        end
        if not valid(sourceSlot, 1, 6) or not valid(targetSlot, 1, 6) or not valid(count, 0, 60) then
            PressStatus(container, "invalid"); return
        end
        local inventory = container.OwnInventory
        local source, target = inventory.GetItemAt(sourceSlot - 1), inventory.GetItemAt(targetSlot + 5)
        local magazine = target and GetVirtualMagazine(target)
        if not source or not virtualAmmo[string.lower(tostring(source.Prefab.Identifier))]
            or not magazine or not target:HasTag(virtualMagazineTag) then
            PressStatus(container, "invalid"); return
        end
        local recipe = ResolveItemRoles(target).targets[1]
        if not recipe then PressStatus(container, "invalid"); return end
        local remaining = magazine.MaxSize - magazine.LoadedCount
        if count > 0 then remaining = math.min(remaining, count) end
        state.virtualJob = {
            target = target, source = source, magazine = magazine, recipe = recipe,
            sourceSlot = sourceSlot - 1, targetSlot = targetSlot + 5,
            remaining = remaining, total = remaining, progress = 0,
        }
        PressStatus(container, "loading", state.virtualJob)
    end)

    Hook.Add("dda.magpress.stop", MOD_NAME .. ".StopPress", function(effect, deltaTime, container)
        if container and tostring(container.Prefab.Identifier) == "ammoreload_machine" then
            StopPress(container, "stopped")
        end
    end)

    Hook.Patch(MOD_NAME .. ".CancelRemoved", "Barotrauma.Items.Components.ItemContainer", "OnItemRemoved",
        { "Barotrauma.Item" }, function(instance, ptable)
            local state = activeContainers[instance.Item]
            local job = state and state.virtualJob
            if job and (ptable.containedItem == job.source or ptable.containedItem == job.target) then
                StopPress(instance.Item, "stopped")
            end
        end, Hook.HookMethodType.After)

    -- inventoryPutItem: 物品放入任意库存, 命中配置容器与配方物品即标记激活
    -- 事件为 Prefix 时机 (物品尚未真正入容器), 正确性由下一 think 周期复核收编
    Hook.Add("inventoryPutItem", MOD_NAME .. ".OnPutItem", function(inventory, item)
        if inventory == nil or item == nil then return end
        local owner = inventory.Owner
        if owner == nil or not LuaUserData.IsTargetType(owner, "Barotrauma.Item") then return end
        if not IsConfiguredContainer(owner) then return end
        local roles = ResolveItemRoles(item)
        if #roles.targets == 0 and #roles.sources == 0 then return end
        ActivateContainer(owner)
    end)

    -- item.created: 新产出的物品若为配置容器则标记待复核
    -- (覆盖未经 PutItem 直接载入内容物的路径, 复核由 think 周期完成)
    Hook.Add("item.created", MOD_NAME .. ".OnItemCreated", function(item)
        if item == nil then return end
        if IsConfiguredContainer(item) then
            ActivateContainer(item)
        end
    end)

    -- item.removed: 容器实例移除时清出激活集 (内容物退出由 think 复核处理)
    Hook.Add("item.removed", MOD_NAME .. ".OnItemRemoved", function(item)
        if item ~= nil then
            activeContainers[item] = nil
        end
    end)

    -- 初始扫描: 覆盖脚本加载前已存在的容器实例
    -- AllItemsMod 物化为 List<Item>, pairs 迭代为项目已验证模式 (AllItems 为 yield 迭代器不可用)
    local function ScanExistingItems()
        for _, item in pairs(Item.ItemList) do
            if IsConfiguredContainer(item) and item.OwnInventory ~= nil then
                for _, contained in pairs(item.OwnInventory.AllItemsMod) do
                    local roles = ResolveItemRoles(contained)
                    if #roles.targets > 0 or #roles.sources > 0 then
                        ActivateContainer(item)
                        break
                    end
                end
            end
        end
    end

    Hook.Add("loaded", MOD_NAME .. ".ScanLoaded", function()
        ScanExistingItems()
    end)

    Hook.Add("roundStart", MOD_NAME .. ".ScanRoundStart", function()
        for container in pairs(activeContainers) do
            activeContainers[container] = nil
        end
        ScanExistingItems()
    end)

    -- 单容器处理: 枚举容器内容收集配方物品并执行耐久转移
    -- 返回 true 表示容器内仍存在配方相关物品 (保持激活), false 表示可修剪
    local function ProcessContainer(container, state, now, dt)
        local ownInventory = container.OwnInventory
        if ownInventory == nil then return false end

        -- 收集: 每配方取首个未满 target 与首个有耐久 source (顺序填充语义)
        local targetOf, sourceOf = {}, {}
        local hasRecipeItem = false
        for _, contained in pairs(ownInventory.AllItemsMod) do
            local roles = ResolveItemRoles(contained)
            local magazine = GetVirtualMagazine(contained)
            for i = 1, #roles.targets do
                local recipe = roles.targets[i]
                hasRecipeItem = true
                local needsAmmo = not magazine and contained.Condition < recipe.fullCondition
                if targetOf[recipe] == nil and needsAmmo then
                    targetOf[recipe] = contained
                end
            end
            for i = 1, #roles.sources do
                local recipe = roles.sources[i]
                hasRecipeItem = true
                if sourceOf[recipe] == nil and contained.Condition > 0.0 then
                    sourceOf[recipe] = contained
                end
            end
        end

        local job = state.virtualJob
        if job then
            if container.Condition <= 0 or job.target.Removed or job.source.Removed
                or ownInventory.GetItemAt(job.sourceSlot) ~= job.source
                or ownInventory.GetItemAt(job.targetSlot) ~= job.target then
                StopPress(container, "stopped")
            else
                local status = RefillVirtualMagazine(job, dt)
                if status then StopPress(container, status)
                else PressStatus(container, "loading", job) end
            end
        end

        if not hasRecipeItem then return false end

        for recipe in pairs(targetOf) do
            local target = targetOf[recipe]
            local source = sourceOf[recipe]
            if source ~= nil then
                local remaining = recipe.fullCondition - target.Condition
                if remaining > 0.0 then
                    -- gain/drain 严格成比例 (drain = gain x drainRatio), 任一侧被钳制时
                    -- 另一侧同步等比缩放: 目标精确落在 fullCondition, 来源不击穿 0,
                    -- 且总消耗恒等于总填充 x ratio, 无收尾多扣
                    local gain = recipe.gainPerSecond * dt
                    local drain = gain * recipe.drainRatio
                    if gain > remaining then
                        drain = drain * (remaining / gain)
                        gain = remaining
                    end
                    if drain > source.Condition then
                        gain = gain * (source.Condition / drain)
                        drain = source.Condition
                    end

                    target.Condition = target.Condition + gain
                    source.Condition = source.Condition - drain

                    if CONFIG.debug and now - state.lastWorkLog >= 1.0 then
                        state.lastWorkLog = now
                        LogDebug("Transfer gain " .. string.format("%.2f", gain)
                            .. " drain " .. string.format("%.2f", drain)
                            .. " target " .. tostring(target.Prefab.Identifier)
                            .. " (" .. string.format("%.2f", target.Condition) .. ")"
                            .. " source " .. tostring(source.Prefab.Identifier)
                            .. " (" .. string.format("%.2f", source.Condition) .. ")")
                    end

                    if target.Condition >= recipe.fullCondition then
                        LogDebug("Target reached full condition, transfer stopped: "
                            .. tostring(target.Prefab.Identifier))
                    elseif source.Condition <= 0.0 then
                        LogDebug("Source depleted, transfer stopped: "
                            .. tostring(source.Prefab.Identifier))
                    end
                end
            end
        end

        return true
    end

    local lastProcessTime = 0.0

    Hook.Add("think", MOD_NAME .. ".Update", function()
        local now = Timer.GetTime()
        local dt = now - lastProcessTime
        if dt < CONFIG.checkInterval then return end
        lastProcessTime = now
        if dt > CONFIG.maxDeltaTime then dt = CONFIG.maxDeltaTime end

        for container, state in pairs(activeContainers) do
            if container.Removed then
                -- 安全网: item.removed 未触发时清理残留项
                activeContainers[container] = nil
            elseif not ProcessContainer(container, state, now, dt) then
                -- 容器内配方物品全部离开: 修剪出激活集
                activeContainers[container] = nil
                LogDebug("Container deactivated: " .. tostring(container.Prefab.Identifier))
            end
        end
    end)
end
