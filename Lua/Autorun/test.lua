local function HasAffliction(character, identifier, minamount)
	if character == nil or character.CharacterHealth == nil then
		return false
	end

	local aff = character.CharacterHealth.GetAffliction(identifier)
	local res = false
	if aff ~= nil then
		res = aff.Strength >= (minamount or 0.5)
	end
	return res
end

local LimbType_Head = 11        -- 头    
local LimbType_RightThigh = 15  -- 右大腿
local LimbType_LeftThigh = 16   -- 左大腿
local LimbType_LeftLeg = 7      -- 左小腿
local LimbType_RightLeg = 8     -- 右小腿
local LimbType_Legs = 14        -- 腿部（如果单个大腿不可用）

-- aff控制AI蹲下射击(26.4.1;3:40 By peach)
Hook.Patch("Barotrauma.HumanAIController","Update",function(instance)
	if HasAffliction(instance.Character, "deep_no_crouching_detect", 1) then
        instance.AnimController.Crouching = false
		end
end,Hook.HookMethodType.After)

-- aff控制AI瞄准头部射击(26.4.1;5:13 By peach)
Hook.Patch("Barotrauma.AIObjectiveCombat","Attack",{"System.Single"},function(instance)
	    local enemy = instance.Enemy
        local target = instance.character
	if HasAffliction(instance.character, "deep_aim_head_detect", 1) then
        if enemy ~= nil and target ~= nil then
            local animController = enemy.AnimController
            
            if animController ~= nil then
                -- 尝试获取头部肢体
                local headLimb = animController.GetLimb(LimbType_Head)
                
                if headLimb ~= nil then
                    -- 设置光标位置为头部世界坐标
                    target.CursorPosition = headLimb.WorldPosition
                    
                    -- 转换为潜艇相对坐标（如果在潜艇内）
                    if target.Submarine ~= nil then
                        target.CursorPosition = target.CursorPosition - target.Submarine.Position
                    end
                end
            end
	end end 
end,
    Hook.HookMethodType.After
)

-- aff控制AI瞄准大腿射击(26.4.1;15:41 By peach)
Hook.Patch("Barotrauma.AIObjectiveCombat","Attack",{"System.Single"},function(instance)
    local enemy = instance.Enemy
    local target = instance.character
    if HasAffliction(instance.character, "deep_aim_thigh_detect", 1) then
        if enemy ~= nil and target ~= nil then
            local animController = enemy.AnimController
            
            if animController ~= nil then
                -- 尝试获取大腿肢体（优先右大腿）
                local thighLimb = animController.GetLimb(LimbType_RightThigh)
                
                -- 如果右大腿不可用，尝试左大腿
                if thighLimb == nil then
                    thighLimb = animController.GetLimb(LimbType_LeftThigh)
                end
                
                -- 如果大腿都不可用，尝试腿部
                if thighLimb == nil then
                    thighLimb = animController.GetLimb(LimbType_Legs)
                end
                
                if thighLimb ~= nil then
                    -- 设置光标位置为大腿世界坐标
                    target.CursorPosition = thighLimb.WorldPosition
                    
                    -- 转换为潜艇相对坐标（如果在潜艇内）
                    if target.Submarine ~= nil then
                        target.CursorPosition = target.CursorPosition - target.Submarine.Position
                    end
                end
            end
        end
    end
end,
    Hook.HookMethodType.After
)

-- aff控制AI瞄准小腿射击(26.4.1;15:49 By peach)
Hook.Patch("Barotrauma.AIObjectiveCombat","Attack",{"System.Single"},function(instance)
    local enemy = instance.Enemy
    local target = instance.character
    if HasAffliction(instance.character, "deep_aim_legs_detect", 1) then
        if enemy ~= nil and target ~= nil then
            local animController = enemy.AnimController
            
            if animController ~= nil then
                -- 尝试获取小腿肢体（优先右腿）
                local legLimb = animController.GetLimb(LimbType_RightLeg)
                
                -- 如果右腿不可用，尝试左腿
                if legLimb == nil then
                    legLimb = animController.GetLimb(LimbType_LeftLeg)
                end
                
                -- 如果小腿都不可用，尝试腿部
                if legLimb == nil then
                    legLimb = animController.GetLimb(LimbType_Legs)
                end
                
                if legLimb ~= nil then
                    -- 设置光标位置为小腿世界坐标
                    target.CursorPosition = legLimb.WorldPosition
                    
                    -- 转换为潜艇相对坐标（如果在潜艇内）
                    if target.Submarine ~= nil then
                        target.CursorPosition = target.CursorPosition - target.Submarine.Position
                    end
                end
            end
        end
    end
end,
    Hook.HookMethodType.After
)


-- aff控制AI取消所有命令，用于交战区防止冲家(26.4.1;17:23 By peach)
local TARGET_AFFLICTION = "deep_cancel_order_detect"
-- 执行间隔（秒）
local CHECK_INTERVAL = 3
-- 上次执行时间
local lastCheckTime = 0

-- 监听游戏更新事件
Hook.Add("think", "CheckBurnAndCancelOrders", function()
    -- 获取当前时间（秒）
    local currentTime = Timer.GetTime()
    
    -- 检查是否达到执行间隔
    if currentTime - lastCheckTime < CHECK_INTERVAL then
        return -- 未达到间隔，跳过执行
    end
    
    -- 更新上次执行时间
    lastCheckTime = currentTime
    
    -- 遍历所有角色
    for _, character in pairs(Character.CharacterList) do
        -- 检查角色是否是人类
        if character.IsHuman then
            -- 检查角色是否有deep_cancel_order_detect Affliction
            local afflictionStrength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(TARGET_AFFLICTION)
            
            -- 如果有deep_cancel_order_detect Affliction且强度大于0.5
            if afflictionStrength > 0.5 then
                -- 检查角色是否有命令
                if character.CurrentOrders and #character.CurrentOrders > 0 then
                    -- 创建取消命令的命令
                    local dismissalOrder = OrderPrefab.Dismissal.CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
                    -- 设置命令，取消所有现有命令
                    character.SetOrder(dismissalOrder, true, false)
                end
            end
        end
    end
end)

-- aff控制AI抵御入侵者，用于追猎者(26.4.1;18:25 By peach)
local TARGET_AFFLICTION_HUNTING = "deep_hunting_order_detect"

-- 监听游戏更新事件
Hook.Add("think", "CheckGunshotWoundAndGiveFightOrderToAI", function()
    -- 获取当前时间（秒）
    local currentTime = Timer.GetTime()
    
    -- 检查是否达到执行间隔
    if currentTime - lastCheckTime < CHECK_INTERVAL then
        return -- 未达到间隔，跳过执行
    end
    
    -- 更新上次执行时间
    lastCheckTime = currentTime
    
    -- 遍历所有角色
    for _, character in pairs(Character.CharacterList) do
        -- 检查角色是否是人类且是AI控制
        if character.IsHuman and character.IsAIControlled then
            -- 检查角色是否有deep_hunting_order_detect Affliction（使用identifier）
            local afflictionStrength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(TARGET_AFFLICTION_HUNTING)
            
            -- 如果有deep_hunting_order_detect Affliction且强度大于0.5
            if afflictionStrength > 0.5 then
                -- 检查fightintruders命令是否存在
                if OrderPrefab.Prefabs["fightintruders"] then
                    -- 创建fightintruders命令
                    local fightOrder = OrderPrefab.Prefabs["fightintruders"].CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
                    -- 设置命令
                    character.SetOrder(fightOrder, true, false)
                end
            end
        end
    end
end)














