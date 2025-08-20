LuaUserData.RegisterType("Barotrauma.HumanPrefab")

-- 用于暂存那些先于角色创建消息到达的更新
local pendingUpdates = {}

if CLIENT and Game.IsMultiplayer then
    Networking.Receive("messageHideInThermalGoggles", function(message)
        local characterID = message.ReadUInt16()
        local shouldHide = message.ReadBoolean()

        -- 使用 Entity.FindEntityByID 高效地查找角色
        -- 因为 Character 是 Entity 的子类，所以我们可以直接使用
        local character = Entity.FindEntityByID(characterID)

        if character then
            -- 角色已存在，立即应用
            character.Params.HideInThermalGoggles = shouldHide
            print("[CLIENT]HideInThermalGoggles set to true for " .. character.Name)
        else
            -- 角色还未创建（或消息先到），先将更新任务放入队列
            pendingUpdates[characterID] = {
                shouldHide = shouldHide,
                expiryTime = Timer.GetTime() + 5.0 -- 5秒后任务过期
            }
        end
    end)

    -- 每帧检查待处理的更新队列，解决网络消息竞态问题
    Hook.Add("think", "Deep_TV_ProcessPendingUpdates", function()
        if not next(pendingUpdates) then return end

        local currentTime = Timer.GetTime()
        for characterID, updateData in pairs(pendingUpdates) do
            if currentTime > updateData.expiryTime then
                pendingUpdates[characterID] = nil -- 任务过期，移除
                print("[CLIENT]HideInThermalGoggles for " .. characterID .. " expired")
            else
                local character = Entity.FindEntityByID(characterID)
                if character then
                    character.Params.HideInThermalGoggles = updateData.shouldHide
                    print("[CLIENT]HideInThermalGoggles set to true for " .. character.Name)
                    pendingUpdates[characterID] = nil -- 任务完成，移除
                end
            end
        end
    end)
end

function NPCHideInThermalGoggles(character)
    if not character.Params.HideInThermalGoggles then
        if SERVER then
            if character.HumanPrefab and string.find(character.HumanPrefab.Tags, "HideInThermalGoggles") then
                character.Params.HideInThermalGoggles = true
                local message = Networking.Start("messageHideInThermalGoggles")
                message.WriteUInt16(character.ID)
                message.WriteBoolean(character.Params.HideInThermalGoggles)
                Networking.Send(message)
                print("[SERVER]HideInThermalGoggles set to true for " .. character.Name)
            end
        end
        if CLIENT and Game.IsSingleplayer then
            if character.HumanPrefab and string.find(character.HumanPrefab.Tags, "HideInThermalGoggles") then
                character.Params.HideInThermalGoggles = true
            end
        end
    end
end

Hook.Add("character.created", "Deep_TV", function(character)
    if not character then return end
    NPCHideInThermalGoggles(character)
end)