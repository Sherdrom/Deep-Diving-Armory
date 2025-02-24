if SERVER then return end

-- 状态存储表
local zoomStates = {}
local lastWheelTime = 0
local WHEEL_COOLDOWN = 0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local function settingZoom(item, deltaMultiplier)
    local zoomLevels = {
        ["zoom2x"] = {offset = 900, multiplier = 0.2},
        ["zoom2_5x"] = {offset = 900, multiplier = 0.25},
        ["zoom3x"] = {offset = 900, multiplier = 0.3},
        ["zoom6x"] = {offset = 900, multiplier = 0.6},
        ["zoom8x"] = {offset = 900, multiplier = 0.8}
    }

    local multiZoom = {
        ["zoom1-3x"] = {offset = 900, minMultiplier = 0 ,maxMultiplier = 0.3},
		["zoom1-6x"] = {offset = 900, minMultiplier = 0 ,maxMultiplier = 0.6},
		["zoom1-8x"] = {offset = 900, minMultiplier = 0 ,maxMultiplier = 0.8}
    }

    -- 优先处理multiZoom
    for tag, settings in pairs(multiZoom) do
        if item.HasTag(tag) or (item.ownInventory and item.ownInventory.FindItemByTag(tag, true)) then
            local stateKey = item.Prefab.Identifier.value
            if not zoomStates[stateKey] then
                zoomStates[stateKey] = {
                    currentMultiplier = settings.minMultiplier,
                    baseOffset = settings.offset
                }
            end
            local state = zoomStates[stateKey]
            
            -- 更新倍率并限制范围
            state.currentMultiplier = state.currentMultiplier + deltaMultiplier
            state.currentMultiplier = clamp(state.currentMultiplier,
                settings.minMultiplier,
                settings.maxMultiplier
            )

            -- 应用新偏移量
            return lerp(
                Screen.Selected.Cam.OffsetAmount,
                state.baseOffset,
                state.currentMultiplier
            )
        end
    end

    -- 处理普通zoom
    if not foundMultiZoom then
        for tag, settings in pairs(zoomLevels) do
            if item.HasTag(tag) or (item.ownInventory and item.ownInventory.FindItemByTag(tag, true)) then
                return lerp(
                    Screen.Selected.Cam.OffsetAmount,
                    settings.offset,
                    settings.multiplier
                )
            end
        end
    end
    return Screen.Selected.Cam.OffsetAmount
end

local function applyZoom(offset)
    Screen.Selected.Cam.OffsetAmount = offset
end

Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
    local currentTime = os.clock()
    if currentTime - lastWheelTime < WHEEL_COOLDOWN then return end
    
    local character = instance
    if not character or not character.Inventory then return end
    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    local item = rightHand or leftHand
    if not item or not character.AnimController.IsAiming then return end

    local offset = settingZoom(item, 0)
    if PlayerInput.MouseWheelUpClicked() then
        lastWheelTime = currentTime
        offset = settingZoom(item, -0.07) -- 调小变化幅度
    elseif PlayerInput.MouseWheelDownClicked() then
        lastWheelTime = currentTime
        offset = settingZoom(item, 0.07)
    end

    applyZoom(offset)
end, Hook.HookMethodType.After)