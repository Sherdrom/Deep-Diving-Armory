if CLIENT then
--     Networking.Receive("IsShootable", function(message)
--         local itemID = tonumber(message.ReadString())
--         print("Server sent " .. itemID)
--        local item = Entity.FindEntityByID(itemID)
--        item.IsShootable = true
--    end)
   return
end

LuaUserData.RegisterType("Barotrauma.Items.Components.ItemContainer+SlotRestrictions")
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.ItemInventory'], 'slots')
LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Items.Components.ItemContainer'], 'slotRestrictions')

-- ===== 配置参数 =====
local RELOAD_CONFIG = {
    BaseDelay = 0.1,         -- 首次延迟
    HangDelay = 1.3,         -- 空仓挂机延迟
    DelayStep = 0.5,          -- 步长时间
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

-- ===== M870 =====
Hook.Add("M870Reload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[1].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
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
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1
    -- 检查是否有霰弹枪侧面弹药带
    if item.ownInventory and item.ownInventory.FindItemByTag("shotgun_ammo_bag", true) then
        insertCountRestriction = math.ceil(state.count/2)
    end
    -- print("insertCountRestriction:"..insertCountRestriction)
    -- print("state.timerCount:"..state.timerCount)
    if not (state.timerCount<=insertCountRestriction) then return end

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                -- if Game.IsMultiplayer then
                --     local message = Networking.Start("IsShootable")
                --     message.WriteString(item.ID)
                --     Networking.Send(message)
                -- end
                item.IsShootable = true
            end, 100)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

Hook.Add("M870Removed", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

-- ===== M4_super90 =====
Hook.Add("M4_super90Reload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[1].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
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
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1
    -- 检查是否有霰弹枪侧面弹药带
    if item.ownInventory and item.ownInventory.FindItemByTag("shotgun_ammo_bag", true) then
        insertCountRestriction = math.ceil(state.count/2)
    end
    -- print("insertCountRestriction:"..insertCountRestriction)
    -- print("state.timerCount:"..state.timerCount)
    if not (state.timerCount<=insertCountRestriction) then return end

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                -- if Game.IsMultiplayer then
                --     local message = Networking.Start("IsShootable")
                --     message.WriteString(item.ID)
                --     Networking.Send(message)
                -- end
                item.IsShootable = true
            end, 100)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

Hook.Add("M4_super90Removed", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

-- ===== M590 =====
Hook.Add("M590Reload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[1].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
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
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1
    -- 检查是否有霰弹枪侧面弹药带
    if item.ownInventory and item.ownInventory.FindItemByTag("shotgun_ammo_bag", true) then
        insertCountRestriction = math.ceil(state.count/2)
    end
    -- print("insertCountRestriction:"..insertCountRestriction)
    -- print("state.timerCount:"..state.timerCount)
    if not (state.timerCount<=insertCountRestriction) then return end

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                -- if Game.IsMultiplayer then
                --     local message = Networking.Start("IsShootable")
                --     message.WriteString(item.ID)
                --     Networking.Send(message)
                -- end
                item.IsShootable = true
            end, 100)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

Hook.Add("M590Removed", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

-- ===== M1887 =====
Hook.Add("M1887Reload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[1].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
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
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1
    -- 检查是否有霰弹枪侧面弹药带
    if item.ownInventory and item.ownInventory.FindItemByTag("shotgun_ammo_bag", true) then
        insertCountRestriction = math.ceil(state.count/2)
    end
    -- print("insertCountRestriction:"..insertCountRestriction)
    -- print("state.timerCount:"..state.timerCount)
    if not (state.timerCount<=insertCountRestriction) then return end

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                -- if Game.IsMultiplayer then
                --     local message = Networking.Start("IsShootable")
                --     message.WriteString(item.ID)
                --     Networking.Send(message)
                -- end
                item.IsShootable = true
            end, 100)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

Hook.Add("M1887Removed", "ReloadCleanup", function(_, _, item)
    cancelReload(item.ID)   --重置状态
end)

-- ===== supernova =====
Hook.Add("supernovaReload", "PrecisionReloadHandler", function(effect, deltaTime, item, targets, worldPosition, element)
    local maxAmmoStack = item.OwnInventory.Container.slotRestrictions[1].MaxStackSize
    local currentAmmoNumber = #item.OwnInventory.slots[1].items
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
    local insertCountRestriction = state.count
    state.timerCount = state.timerCount + 1
    -- 检查是否有霰弹枪侧面弹药带
    if item.ownInventory and item.ownInventory.FindItemByTag("shotgun_ammo_bag", true) then
        insertCountRestriction = math.ceil(state.count/2)
    end
    -- print("insertCountRestriction:"..insertCountRestriction)
    -- print("state.timerCount:"..state.timerCount)
    if not (state.timerCount<=insertCountRestriction) then return end

    -- 锁住开火
    local disableShootTime = RELOAD_CONFIG.BaseDelay + insertCountRestriction* RELOAD_CONFIG.DelayStep
    if state.needHang then
        disableShootTime = disableShootTime + RELOAD_CONFIG.HangDelay - 2*RELOAD_CONFIG.DelayStep
    end

    -- 只执行一次
    if state.timerCount == 1 then
        Timer.Wait(function()
            -- 解锁开火同时枪械归位
            Timer.Wait(function()
                -- if Game.IsMultiplayer then
                --     local message = Networking.Start("IsShootable")
                --     message.WriteString(item.ID)
                --     Networking.Send(message)
                -- end
                item.IsShootable = true
            end, 100)
            -- 解锁开火视为装填完成，开始清理
            cancelReload(item.ID)
        end, disableShootTime * 1000)
    end

    -- 保底使用定时器清理
    onReloadComplete(item.ID)
    end, delay * 1000)
end)

Hook.Add("supernovaRemoved", "ReloadCleanup", function(_, _, item)
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
                        -- if Game.IsMultiplayer then
                        --     local message = Networking.Start("IsShootable")
                        --     message.WriteString(state.item.ID)
                        --     Networking.Send(message)
                        -- end
                        state.item.IsShootable = true
                    end, 100)
                    cancelReload(itemID)
                end, RELOAD_CONFIG.HangDelay * 1000)      -- 空挂但只装一发的特殊处理，在这里设置空仓挂机的时间
            end
            if state.needHang then return end
            cancelReload(itemID)
            -- print("自动清理超时状态："..itemID)
        end
    end
end, Hook.HookMethodType.After)
return