LuaUserData.RegisterType("Barotrauma.Items.Components.ItemContainer+SlotRestrictions")
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')

-- ===== 配置参数 =====
local RELOAD_CONFIG = {
    Sound = {},
    BaseDelay = 0.1,         -- 首次延迟
    OpenChamberDelay = 1.3,  -- 开仓延迟
    CloseChamberDelay = 0.5, -- 关仓延迟
    DelayStep = 1,          -- 步长时间
    ConditionPerShell = 1,
    AutoCleanDelay = 0.2        -- 超时清理
}
if not SERVER then
    RELOAD_CONFIG.Sound = {
            sound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/Weapons/M32/gunOther/Insert.ogg"),
            OpenChamberSound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/Weapons/M32/gunOther/OpenChamber.ogg"),
            CloseChamberSound = Game.SoundManager.LoadSound(Deep_Lua.Path .. "/Sound/Weapons/M32/gunOther/CloseChamber.ogg"),
            frequencymultiplier = 1,
            gain = 1.5,
            range = 500
        }
end

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
    if SERVER then return end
    -- local Character = item.ParentInventory.Owner
    -- local animController = Character.AnimController
    local itemComponent = item.GetComponentString("Holdable")
    -- First status effect: Set hand's position and angle
    itemComponent.HoldPos=Vector2(30,0)
    itemComponent.AimPos=Vector2(20,-10)
    itemComponent.AimAngle=-10
    -- Second status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(20,0)
    end, 50) -- 0.05 seconds delay
    -- Third status effect: Set handle position
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(80,25)
    end, 250) -- 0.25 seconds delay
end

local function openChamber(item)
    if SERVER then return end
    local itemComponent = item.GetComponentString("Holdable")
    SoundPlayer.PlaySound(RELOAD_CONFIG.Sound.OpenChamberSound, item.WorldPosition, RELOAD_CONFIG.Sound.gain, RELOAD_CONFIG.Sound.range, RELOAD_CONFIG.Sound.frequencymultiplier)
    itemComponent.HoldPos=Vector2(40,-10)
    itemComponent.AimPos=Vector2(35,-9)
    itemComponent.AimAngle=30
    itemComponent.HoldAngle=30
    -- 更改贴图
    item.Sprite.SourceRect=Rectangle(10,132,299,98)
    Timer.Wait(function()
        itemComponent.Handle2=Vector2(50,19)
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
        itemComponent.AimPos=Vector2(20,-10)
        itemComponent.AimAngle=-10
        itemComponent.HoldAngle=-35
        itemComponent.HoldPos=Vector2(30,0)
    end, 880) -- 0.88 seconds delay
    -- 手回正
    Timer.Wait(function()
        itemComponent.Handle1=Vector2(-50,-20)
        itemComponent.Handle2=Vector2(80,25)
    end, 1300) -- 1.3 seconds delay
end

-- ===== 枪械归位 =====
local function resetAnimation(item)
    if SERVER then return end
    -- holdpos="40,-10" aimpos="55,3" handle1="-50,-20" handle2="80,30" holdangle="-35"
    local itemComponent = item.GetComponentString("Holdable")
    SoundPlayer.PlaySound(RELOAD_CONFIG.Sound.CloseChamberSound, item.WorldPosition, RELOAD_CONFIG.Sound.gain, RELOAD_CONFIG.Sound.range, RELOAD_CONFIG.Sound.frequencymultiplier)
    item.Sprite.SourceRect=Rectangle(10,9,299,98)
    itemComponent.HoldPos=Vector2(40,-10)
    itemComponent.AimPos=Vector2(55,3)
    itemComponent.AimAngle=0
    itemComponent.Handle2=Vector2(80,30)
    itemComponent.Handle1=Vector2(-50,-20)
    itemComponent.HoldAngle=-35
end

local function currentAmmoNumber(item,maxAmmoStack)
    local currentAmmoNumber = 0
    for i = 1, maxAmmoStack do
        local slot = item.OwnInventory.slots[i]
        if slot and slot.items then
            currentAmmoNumber = currentAmmoNumber + #slot.items
        end
    end
    return currentAmmoNumber
end
-- ===== 核心逻辑 =====
Hook.Add("M32Reload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local itemContainer = item.GetComponentString("ItemContainer")
    local maxAmmoStack = itemContainer.MainContainerCapacity
    local currentAmmoNumber = currentAmmoNumber(item,maxAmmoStack)
    -- local currentAmmoCondition = item.Condition
    -- local maxAmmoCondition = item.maxCondition
    -- 初始化状态
    if not reloadStates[item.ID] then
        reloadStates[item.ID] = {
            count = 0,
            timers = {},
            timerCount = 0,
            maxReload = math.min(maxAmmoStack - currentAmmoNumber + 1 ,maxAmmoStack),
            completeTime = nil,
            item = item,
            needHang = true    -- 是否需要空仓挂机，代码复用，恒为true
        }

    end
    if currentAmmoNumber > maxAmmoStack then return end

    local state = reloadStates[item.ID]
    state.item = item

    if state.count == 0 then
        openChamber(item) -- 开仓
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
    local delay = RELOAD_CONFIG.BaseDelay + (state.count - 1) * RELOAD_CONFIG.DelayStep + RELOAD_CONFIG.OpenChamberDelay

    state.timers[state.count] = Timer.Wait(function()
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1

    if not (state.timerCount<=insertCountRestriction) then return end
    -- 播放动作
    applyEffects(item)
    -- 播放音效
    if CLIENT then SoundPlayer.PlaySound(RELOAD_CONFIG.Sound.sound, item.WorldPosition, RELOAD_CONFIG.Sound.gain, RELOAD_CONFIG.Sound.range, RELOAD_CONFIG.Sound.frequencymultiplier) end

    -- print("目前的stat.count:"..state.count)
    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    disableShootTime = disableShootTime + RELOAD_CONFIG.OpenChamberDelay + RELOAD_CONFIG.CloseChamberDelay - 2*RELOAD_CONFIG.DelayStep

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                if Game.IsSingleplayer then
                    item.Condition = 200
                end
                if SERVER then
                    item.Condition = 200
                    local property = item.SerializableProperties[Identifier("Condition")]
                    Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(property, item))
                end
            end, 100)
            resetAnimation(item)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

-- ===== 当子弹被移除：开火、交换 =====
Hook.Add("M32Removed", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

Hook.Patch("Barotrauma.Character", "Control", function(instance, ptable)
    if not reloadStates then return end
    local currentTime = Timer.GetTime()
    
    for itemID, state in pairs(reloadStates) do
        -- 检查已完成且超时的状态
        if state.completeTime and (currentTime - state.completeTime) >= RELOAD_CONFIG.AutoCleanDelay then
            if state.needHang and state.count == 0 and not state.executed then
                state.executed = true
                Timer.Wait(function()
                    Timer.Wait(function()
                        if Game.IsSingleplayer then
                            state.item.Condition = 200
                        end
                        if SERVER then
                            item.Condition = 200
                            local property = item.SerializableProperties[Identifier("Condition")]
                            Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(property, item))
                        end
                    end, 100)
                    resetAnimation(state.item)
                    cancelReload(itemID)
                end, RELOAD_CONFIG.OpenChamberDelay * 1000)      -- 空挂但只装一发的特殊处理，在这里设置空仓挂机的时间
            end
            if state.needHang then return end
            cancelReload(itemID)
            -- print("自动清理超时状态："..itemID)
        end
    end
end, Hook.HookMethodType.After)