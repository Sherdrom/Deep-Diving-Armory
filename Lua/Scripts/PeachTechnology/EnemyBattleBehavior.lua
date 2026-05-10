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

local LimbType_Head = 11        -- 头部
local LimbType_Torso = 12       -- 躯干（默认瞄准目标）
local LimbType_RightThigh = 15  -- 右大腿
local LimbType_LeftThigh = 16   -- 左大腿
local LimbType_LeftLeg = 7      -- 左小腿
local LimbType_RightLeg = 8     -- 右小腿
local LimbType_Legs = 14        -- 腿部（备用）

-- 辅助函数：设置目标光标位置
local function SetAimTarget(target, limb)
    if target == nil or limb == nil then
        return false
    end

    -- 设置光标位置为肢体世界坐标
    target.CursorPosition = limb.WorldPosition

    -- 转换为潜艇相对坐标（如果在潜艇内）
    if target.Submarine ~= nil then
        target.CursorPosition = target.CursorPosition - target.Submarine.Position
    end

    return true
end

-- aff控制AI蹲下射击(26.4.1;3:40 By peach)
Hook.Patch("Barotrauma.HumanAIController","Update",function(instance)
	if HasAffliction(instance.Character, "deep_no_crouching_detect", 1) then
        instance.AnimController.Crouching = false
		end
end,Hook.HookMethodType.After)

-- 统一的AI瞄准控制系统(默认躯干 + Affliction优先级覆盖)
-- 优先级: deep_aim_head_detect > deep_aim_thigh_detect > deep_aim_legs_detect > 默认躯干
Hook.Patch("Barotrauma.AIObjectiveCombat","Attack",{"System.Single"},function(instance)
    local enemy = instance.Enemy
    local target = instance.character

    if enemy == nil or target == nil then
        return
    end

    local animController = enemy.AnimController
    if animController == nil then
        return
    end

    local targetLimb = nil

    -- 优先级1: 瞄准头部
    if HasAffliction(instance.character, "deep_aim_head_detect", 1) then
        targetLimb = animController.GetLimb(LimbType_Head)
    -- 优先级2: 瞄准大腿
    elseif HasAffliction(instance.character, "deep_aim_thigh_detect", 1) then
        -- 尝试获取右大腿
        targetLimb = animController.GetLimb(LimbType_RightThigh)
        -- 如果右大腿不可用，尝试左大腿
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_LeftThigh)
        end
        -- 如果大腿都不可用，尝试腿部
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_Legs)
        end
    -- 优先级3: 瞄准小腿
    elseif HasAffliction(instance.character, "deep_aim_legs_detect", 1) then
        -- 尝试获取右腿
        targetLimb = animController.GetLimb(LimbType_RightLeg)
        -- 如果右腿不可用，尝试左腿
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_LeftLeg)
        end
        -- 如果小腿都不可用，尝试腿部
        if targetLimb == nil then
            targetLimb = animController.GetLimb(LimbType_Legs)
        end
    -- 默认: 瞄准躯干
    else
        targetLimb = animController.GetLimb(LimbType_Torso)
    end

    -- 设置瞄准目标
    SetAimTarget(target, targetLimb)
end,
    Hook.HookMethodType.After
)


-- aff控制AI取消所有命令，用于交战区防止冲家(26.4.1;17:23 By peach)
local TARGET_AFFLICTION = "deep_cancel_order_detect"
-- 执行间隔（秒）
local CHECK_INTERVAL = 1
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
                    -- 创建取消命令的命令
                    local dismissalOrder = OrderPrefab.Dismissal.CreateInstance(OrderPrefab.OrderTargetType.Entity, character)
                    -- 设置命令，取消所有现有命令
                    character.SetOrder(dismissalOrder, true, false)
            end
        end
    end
end)

-- aff控制AI抵御入侵者，用于追猎者(26.4.1;18:25 By peach) 
local TARGET_AFFLICTION_HUNTING = "deep_hunting_order_detect" 
local CHECK_INTERVAL = 1.0 -- 检查间隔，单位秒
local lastCheckTime = 0 -- 上次检查时间

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
        -- 只检查角色是否是人类 
        if character.IsHuman then 
            -- 检查角色是否有deep_hunting_order_detect Affliction（使用identifier） 
            local afflictionStrength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(TARGET_AFFLICTION_HUNTING) 
            
            -- 如果有deep_hunting_order_detect Affliction且强度大于0.5 
            if afflictionStrength > 0.5 then 
                -- 检查fightintruders命令是否存在 
                if OrderPrefab.Prefabs["fightintruders"] then 
                    -- 创建fightintruders命令 
                    local fightOrder = OrderPrefab.Prefabs["fightintruders"].CreateInstance(OrderPrefab.OrderTargetType.Entity, character) 
                    -- 设置命令，使用force=true确保命令被强制设置
                    character.SetOrder(fightOrder, true, false, true) 
                    
                    -- 尝试获取AI控制器并强制重新评估目标
                    if character.AIController then
                        -- 直接尝试调用SetForcedOrder，不需要检查类型
                        -- 在Lua中，我们无法直接检查C#对象的类型，所以直接尝试调用
                        pcall(function()
                            character.AIController.SetForcedOrder(fightOrder)
                        end)
                    end
                end 
            end 
        end 
    end 
end)














