if SERVER then return end

LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')

-- ===== 配置参数 =====
local RELOAD_CONFIG = {
    Sound = {
        sound = Game.SoundManager.LoadSound(... .. "/weapon/ammo/M870Insert.ogg"),
        hangSound = Game.SoundManager.LoadSound(... .. "/weapon/ammo/M870Hang.ogg"),
        frequencymultiplier = 1,
        gain = 1.5
    },
    BaseDelay = 0.1,         -- 首次延迟
    HangDelay = 1.3,         -- 空仓挂机延迟
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
        -- print("装填状态已重置")
    end
end

-- ===== 装填完成处理 =====
local function onReloadComplete(itemID)
    local state = reloadStates[itemID]
    if state then
        -- 标记完成时间（而不是立即清理）
        state.completeTime = Timer.GetTime()
        -- print("装填完成，等待清理："..itemID)
        -- print("state.completeTime:"..state.completeTime)
    end
end

-- ===== XML Actions =====
local function applyEffects(item)
    -- local Character = item.ParentInventory.Owner
    -- local animController = Character.AnimController
    local itemComponent = item.GetComponentString("Holdable")
    -- First status effect: Set hand's position and angle
    itemComponent.HoldPos=Vector2(50,10)
    itemComponent.AimPos=Vector2(55,-10)
    itemComponent.AimAngle=-10
    -- Second status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(-20,-10)
    end, 50) -- 0.05 seconds delay
    -- Third status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(60,0)
    end, 250) -- 0.25 seconds delay
end

-- ===== 枪械归位 =====
local function resetAnimation(item)
    -- holdpos="40,-10" aimpos="55,3" handle1="-50,-20" handle2="80,30" holdangle="-35"
    local itemComponent = item.GetComponentString("Holdable")
    itemComponent.HoldPos=Vector2(40,-10)
    itemComponent.AimPos=Vector2(65,12)
    itemComponent.AimAngle=0
    itemComponent.Handle2=Vector2(60,0)
    itemComponent.Handle1=Vector2(-120,-35)
    itemComponent.HoldAngle=-35
end

local function hangAnimation(item)
    local itemComponent = item.GetComponentString("Holdable")
    RELOAD_CONFIG.Sound.hangSound.Play(item.Position, RELOAD_CONFIG.Sound.gain, RELOAD_CONFIG.Sound.frequencymultiplier)
    itemComponent.HoldPos=Vector2(50,-10)
    itemComponent.AimPos=Vector2(35,0)
    itemComponent.AimAngle=30
    itemComponent.HoldAngle=30
    -- 更改贴图
    item.Sprite.SourceRect=Rectangle(19,360,650,114)
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(50,0)
        itemComponent.Handle1=Vector2(-42,-14)
    end, 320) -- 0.32 seconds delay
    -- handle1放入一颗子弹
    Timer.Wait(function()
        itemComponent.Handle1=Vector2(20,0)
    end, 530) -- 0.53 seconds delay
    -- handle1半归位
    Timer.Wait(function()
        itemComponent.Handle1=Vector2(-11,-7)
        itemComponent.HoldAngle=-3
        itemComponent.AimAngle=10
    end, 680) -- 0.68 seconds delay
    -- handle1归位
    Timer.Wait(function()
        itemComponent.Handle1=Vector2(-42,-14)
    end, 830) -- 0.83 seconds delay
    -- 枪械回正
    Timer.Wait(function()
        itemComponent.AimPos=Vector2(35,0)
        itemComponent.AimAngle=-10
        itemComponent.HoldAngle=-35
        itemComponent.HoldPos=Vector2(50,0)
        -- 再加一个贴图回正
        item.Sprite.SourceRect=Rectangle(19,235,650,114)
    end, 880) -- 0.88 seconds delay
    -- 手回正
    Timer.Wait(function()
        itemComponent.Handle1=Vector2(-120,-35)
        itemComponent.Handle2=Vector2(60,0)
    end, 1300) -- 1.3 seconds delay
end

-- ===== 核心逻辑 =====
Hook.Add("supernovaReload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[0].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
    -- local currentAmmoCondition = item.Condition
    -- local maxAmmoCondition = item.maxCondition
    -- 初始化状态
    if not reloadStates[item.ID] then
        reloadStates[item.ID] = {
            count = 0,
            timers = {},
            maxReload = math.min(maxAmmoStack - currentAmmoNumber + 1 ,maxAmmoStack),
            completeTime = nil,
            item = item,
            needHang = false    -- 是否需要空仓挂机
        }
        -- print("maxAmmoStack:" .. maxAmmoStack)
        -- print("currentAmmoNumber:" .. currentAmmoNumber)
        -- print("maxReload:" .. reloadStates[item.ID].maxReload)
    end
    if currentAmmoNumber > maxAmmoStack then return end

    local state = reloadStates[item.ID]
    state.item = item

    -- 检查是否需要空仓上膛
    if currentAmmoNumber == 1 then
        state.needHang = true
        state.maxReload = maxAmmoStack - 1
        -- print("需要空仓上膛")
        hangAnimation(item)
        onReloadComplete(item.ID)
        return
    end

    -- 终止无效装填
    if state.count >= state.maxReload then
        cancelReload(item.ID)
        return
    end
    
    -- 计算当前装填次序
    state.count = state.count + 1
    -- print("调用"..state.count.."次")

    -- 动态计算延迟时间
    local delay = RELOAD_CONFIG.BaseDelay + (state.count - 1) * RELOAD_CONFIG.DelayStep
    if state.needHang then
        delay = delay + RELOAD_CONFIG.HangDelay
    end
    state.timers[state.count] = Timer.Wait(function()
    -- 播放动作
    applyEffects(item)
    -- 播放音效
    RELOAD_CONFIG.Sound.sound.play(item.Position, RELOAD_CONFIG.Sound.gain, RELOAD_CONFIG.Sound.frequencymultiplier)
    -- print("目前的stat.count:"..state.count)

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + state.count* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end
    Timer.Wait(function()
        -- 解锁开火同时枪械归位
        Timer.Wait(function()
            item.IsShootable = true
        end, 100)
        resetAnimation(item)
        cancelReload(item.ID)
    end, disableShootTime * 1000)
    
    -- 完成时清理
    if state.count >= state.maxReload then
        -- print("装填完成:"..state.count .. "开始清理")
        cancelReload(item.ID)
    end
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

-- ===== 当子弹被移除：开火、交换 =====
Hook.Add("supernovaRemoved", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

-- ===== 霰弹枪PumbIn =====
Hook.Add("supernovaPumbInSprite", "supernovaPumbIn", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(19,360,650,114)
end)

Hook.Add("supernovaPumbOutSprite", "supernovaPumbOut", function(_, _, item)
    item.Sprite.SourceRect=Rectangle(19,235,650,114)
end)

Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
    if not reloadStates then return end
    local currentTime = Timer.GetTime()
    
    for itemID, state in pairs(reloadStates) do
        -- 检查已完成且超时的状态
        if state.completeTime and (currentTime - state.completeTime) >= RELOAD_CONFIG.AutoCleanDelay then
            if state.needHang and state.count == 0 then
                Timer.Wait(function()
                    Timer.Wait(function()
                        state.item.IsShootable = true
                    end, 100)
                    resetAnimation(state.item)
                    cancelReload(itemID)
                end, RELOAD_CONFIG.HangDelay * 1000)      -- 空挂但只装一发的特殊处理，在这里设置空仓挂机的时间
            end
            if state.needHang then return end
            cancelReload(itemID)
            -- print("自动清理超时状态："..itemID)
        end
    end
end, Hook.HookMethodType.After)