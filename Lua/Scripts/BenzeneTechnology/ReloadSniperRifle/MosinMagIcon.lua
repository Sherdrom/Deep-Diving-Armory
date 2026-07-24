if SERVER then return end

-- 这个脚本实现了Mosin弹匣图标的动态更新功能。根据弹匣的Condition值计算剩余子弹数量，并根据配置显示对应的图标状态。想要复制这个功能到其他物品，只需要调整config中的参数和状态图标配置即可。
local config = {
    -- XML里使用的HooK名字 <LuaHook name="DeepMosinMagIcon" />.
    hookName = "DeepMosinMagIcon",

    -- 设置为nil表示多个物品标识符可以共享这个hook。
    identifier = "deep_Mosin_mag", -- 和xml里Prefab Identifier="deep_Mosin_mag"保持一致。

    maxAmmo = 5,    --总共子弹数量

    conditionPerShot = 20,  -- 每发子弹消耗的耐久度，和xml里StatusEffect type="OnUse" target="This" condition="-20"保持一致。

    emptyConditionEpsilon = 0.01, -- 当Condition小于等于这个值时，显示为0子弹。避免因为浮点数精度问题导致的显示错误。

    refreshInterval = 0.1, -- 客户端轮询间隔。用于弹匣装在枪内时实时刷新图标。

    depth = 0.65,   -- 图层深度。

    -- Index = 剩余子弹数量，Value = 对应的图标信息。
    -- 需要根据实际的图片资源调整rect参数，rect参数格式为Rectangle(x, y, width, height)，x和y是图片中该状态图标的左上角坐标，width和height是图标的宽高。
    states = {
        [5] = { rect = Rectangle(595, 70, 82, 73) },
        [4] = { rect = Rectangle(595, 70, 82, 73) },
        [3] = { rect = Rectangle(595, 70, 82, 73) },
        [2] = { rect = Rectangle(595, 70, 82, 73) },
        [1] = { rect = Rectangle(595, 70, 82, 73) },
        [0] = { rect = Rectangle(689, 73, 22, 72) }
    }
}

local lastRefreshTime = 0
local lastDisplayedAmmo = {}
local trackedItems = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function isTargetItem(item)
    if item == nil or item.Prefab == nil then return false end
    return config.identifier == nil or item.Prefab.Identifier.Value == config.identifier
end

local function getDisplayedAmmo(item)
    local condition = item.Condition or 0
    if condition <= config.emptyConditionEpsilon then return 0 end

    local rawAmmo = math.ceil(condition / config.conditionPerShot)
    return clamp(rawAmmo, 0, config.maxAmmo)
end

local function updateMosinMagIcon(item)
    if item == nil or item.OverrideInventorySprite == nil then return end
    if not isTargetItem(item) then return end

    local icon = item.OverrideInventorySprite
    local ammo = getDisplayedAmmo(item)
    local state = config.states[ammo] or config.states[0]
    if state == nil then return end

    icon.SourceRect = state.rect
    icon.Depth = state.depth or config.depth
end

local function trackItem(item)
    if not isTargetItem(item) then return end
    if item.Removed then return end

    trackedItems[item] = true
    updateMosinMagIcon(item)
end

Hook.Add(config.hookName, config.hookName, function(_, _, item)
    trackItem(item)
end)

Hook.Add("think", config.hookName .. "Think", function()
    local currentTime = Timer.GetTime()
    if currentTime - lastRefreshTime < config.refreshInterval then return end
    lastRefreshTime = currentTime

    for item in pairs(trackedItems) do
        if item.Removed or item.OverrideInventorySprite == nil then
            trackedItems[item] = nil
            lastDisplayedAmmo[item] = nil
        else
            local ammo = getDisplayedAmmo(item)
            if lastDisplayedAmmo[item] ~= ammo then
                lastDisplayedAmmo[item] = ammo
                updateMosinMagIcon(item)
            end
        end
    end
end)

Hook.Add("item.removed", config.hookName .. "Removed", function(item)
    trackedItems[item] = nil
    lastDisplayedAmmo[item] = nil
end)

Hook.Add("roundEnd", config.hookName .. "RoundEnd", function()
    trackedItems = {}
    lastDisplayedAmmo = {}
    lastRefreshTime = 0
end)

Hook.Add("roundStart", config.hookName .. "RoundStart", function()
    trackedItems = {}
    lastDisplayedAmmo = {}
    for _, item in pairs(Item.ItemList) do
        if isTargetItem(item) and not item.Removed then
            trackedItems[item] = true
            updateMosinMagIcon(item)
        end
    end
end)
