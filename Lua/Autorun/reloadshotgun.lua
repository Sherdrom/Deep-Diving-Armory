if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')

-- ===== 配置参数 =====
local RELOAD_CONFIG = {
    Sound = {
        file = "weapon/shotgun/ShotgunShellInsert.ogg",
        range = 500,
        volume = 1.5
    },
    BaseDelay = 0.3,         -- 首次延迟
    DelayStep = 0.5,          -- 步长时间
    ConditionPerShell = 1,
    AutoCleanDelay = 0.5        -- 超时清理
}

-- ===== 状态跟踪器 =====
local reloadStates = {} -- 结构: { [itemID] = { count = N, timers = { ... } } }

-- ===== 重置状态跟踪器 =====
local function cancelReload(itemID)
    local state = reloadStates[itemID]
    if state then
        -- 取消所有定时器
        for _, timerID in pairs(state.timers) do
            Timer.Cancel(timerID)
        end
        reloadStates[itemID] = nil
        print("装填状态已重置")
    end
end

-- ===== 修改装填完成处理 =====
local function onReloadComplete(itemID)
    local state = reloadStates[itemID]
    if state then
        -- 标记完成时间（而不是立即清理）
        state.completeTime = os.clock()
        print("装填完成，等待清理："..itemID)
    end
end



-- ===== 核心逻辑 =====
Hook.Add("HandleShotgunReload", "PrecisionReloadHandler", function(_, _, item)
    -- local currentAmmoNumber = #item.OwnInventory.slots[1].items
    -- local maxAmmoStackSize = item.OwnInventory.Container.slotRestrictions[0].MaxStackSize
    local currentAmmoNumber = item.condition
    local maxAmmoStackSize = item.maxCondition
    -- 初始化状态
    if not reloadStates[item.ID] then
        reloadStates[item.ID] = {
            count = 0,
            timers = {},
            maxReload = maxAmmoStackSize - currentAmmoNumber,
            completeTime = 100
        }
        print("maxAmmoStackSize:" .. maxAmmoStackSize)
        print("currentAmmoNumber:" .. currentAmmoNumber)
        print("maxReload:" .. reloadStates[item.ID].maxReload)
    end
    
    local state = reloadStates[item.ID]
    
    -- 终止无效装填
    if state.count >= state.maxReload then 
        reloadStates[item.ID] = nil
        return
    end
    
    -- 计算当前装填次序
    state.count = state.count + 1
    print("调用"..state.count.."次")

    -- 动态计算延迟时间
    local delay = RELOAD_CONFIG.BaseDelay + (state.count - 1) * RELOAD_CONFIG.DelayStep
    
    state.timers[state.count] = Timer.Wait(function()
        -- 播放音效
        -- SoundPlayer.PlaySoundEffect(
        --     RELOAD_CONFIG.Sound.file,
        --     item.WorldPosition,
        --     RELOAD_CONFIG.Sound.range,
        --     RELOAD_CONFIG.Sound.volume
        -- )
    print("当前播放音频")
    -- 完成时清理
    if state.count >= state.maxReload then
        cancelReload(item.ID)
    end
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

-- ===== 当子弹被移除：开火、交换 =====
Hook.Add("HandleShotgunRemoved", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)
end)

Hook.Add("think", "magazineRetrySystem", function()
    local currentTime = os.clock()
    
    for itemID, state in pairs(reloadStates) do
        -- 检查已完成且超时的状态
        if state.completeTime and (currentTime - state.completeTime) >= RELOAD_CONFIG.AutoCleanDelay then
            cancelReload(itemID)
            print("自动清理超时状态："..itemID)
        end
    end
end)