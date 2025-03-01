if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
-- LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.Holdable'], 'HoldPos')

-- ===== 配置参数 =====
local RELOAD_CONFIG = {
    Sound = {
        sound = Game.SoundManager.LoadSound(... .. "/weapon/shotgun/ShotgunShellInsert.ogg"),
        frequencymultiplier = 500,
        gain = 1.5
    },
    BaseDelay = 0.3,         -- 首次延迟
    DelayStep = 0.5,          -- 步长时间
    ConditionPerShell = 1,
    AutoCleanDelay = 0.2        -- 超时清理
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
        state.completeTime = Timer.GetTime()
        print("装填完成，等待清理："..itemID)
        print("state.completeTime:"..state.completeTime)
    end
end

-- ===== XML Actions =====
local function applyEffects(item)
    -- local Character = item.ParentInventory.Owner
    -- local animController = Character.AnimController
    local itemComponent = item.GetComponentString("Holdable")
    -- First status effect: Set hand's position and angle
    Timer.Wait(function()
        itemComponent.HoldPos=Vector2(30,0)
        itemComponent.AimPos=Vector2(20,-10)
        itemComponent.AimAngle=-10
    end, 50) -- 0.05 seconds delay
    -- Second status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(20,-0)
    end, 100) -- 0.2 seconds delay
    -- Third status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(80,25)
    end, 300) -- 0.4 seconds delay
end

-- ===== 核心逻辑 =====
Hook.Add("HandleShotgunReload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    -- local currentAmmoNumber = #item.OwnInventory.slots[1].items
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[0].MaxStackSize
    local currentAmmoNumber = item.condition
    local maxAmmoStackSize = item.maxCondition
    -- 初始化状态
    if not reloadStates[item.ID] then
        reloadStates[item.ID] = {
            count = 0,
            timers = {},
            maxReload = math.min(maxAmmoStackSize - currentAmmoNumber,maxAmmoStack),
            completeTime = nil
        }
        print("maxAmmoStackSize:" .. maxAmmoStackSize)
        print("currentAmmoNumber:" .. currentAmmoNumber)
        print("maxReload:" .. reloadStates[item.ID].maxReload)
    end
    
    local state = reloadStates[item.ID]
    item.IsShootable = false
    -- 终止无效装填
    if state.count >= state.maxReload then
        cancelReload(item.ID)
        return
    end
    
    -- 计算当前装填次序
    state.count = state.count + 1
    print("调用"..state.count.."次")

    -- 动态计算延迟时间
    local delay = RELOAD_CONFIG.BaseDelay + (state.count - 1) * RELOAD_CONFIG.DelayStep
    
    state.timers[state.count] = Timer.Wait(function()
    -- Apply status effects
    applyEffects(item)
    RELOAD_CONFIG.Sound.sound.play(worldPosition, RELOAD_CONFIG.Sound.gain, 1)
    print("目前的stat.count:"..state.count)

    -- 锁住开火
    Timer.Wait(function()
        item.IsShootable = true
    end, RELOAD_CONFIG.BaseDelay + state.count* RELOAD_CONFIG.DelayStep * 1000)
    
    -- 完成时清理
    if state.count >= state.maxReload then
        print("装填完成:"..state.count .. "开始清理")
        cancelReload(item.ID)
    end
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

-- ===== 当子弹被移除：开火、交换 =====
Hook.Add("HandleShotgunRemoved", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
    if not reloadStates then return end
    local currentTime = Timer.GetTime()
    
    for itemID, state in pairs(reloadStates) do
        -- 检查已完成且超时的状态
        if state.completeTime and (currentTime - state.completeTime) >= RELOAD_CONFIG.AutoCleanDelay then
            cancelReload(itemID)
            print("自动清理超时状态："..itemID)
        end
    end
end, Hook.HookMethodType.After)