-- HeadsetTeamAutoSwitch.lua
-- 装备耳机时, 自动将耳机的频道阵营切换为佩戴者所在阵营
-- (适用于原版耳机与本 mod 耳机: gssh01_headset / m32_headset / walker_headset 等,
--  任何带 WifiComponent 的穿戴物品均通用, 无需白名单)
--
-- 原理 (基于游戏源码验证):
--   耳机的"频道阵营"= 其 WifiComponent.TeamID (CharacterTeamType: None/Team1/Team2/FriendlyNPC)。
--   原版无线电聊天按发送者与接收者的 WifiComponent.TeamID 是否一致过滤
--   (WifiComponent.CanReceive L168 / CanTransmit L197; ChatMessage.ApplyDistanceEffect L279),
--   TeamID 不一致且未开跨队通讯时互相听不到。
--   所有装备路径的咽喉点是 Item.Equip (Item.cs L3706):
--   CharacterInventory.TryPutItem 把物品写入肢体槽位后统一调用 item.Equip(character)
--   (CharacterInventory.cs L517-518), 开局自带耳机 / AI 拾取 / 玩家手动穿戴均走此路径;
--   徒手拾取 (Any 槽) 不触发 Equip, 天然限定"戴在身上"的场景。
--
-- 多人同步:
--   WifiComponent 的网络事件只序列化 Channel 与 channelMemory
--   (ServerSource WifiComponent.cs ServerEventWrite L9-12), TeamID 不做回合内网络同步;
--   无线电聊天的接收者过滤完全由服务端权威计算 (ChatMessage.ApplyDistanceEffect 由服务端
--   决定哪些角色能收到, 语音中继同样服务端判定), 因此服务端改 TeamID 即为权威结果,
--   无需任何自定义网络消息。客户端也加载本脚本时, 本地穿戴自己的耳机同样会改写本地副本,
--   两端状态自然一致。
--
-- 单人: 与服务端逻辑完全一致, 本地直接执行。
--
-- 部署: 由 init.lua dofile 加载。
-- 测试: 将下方 DEBUG 改为 true 可在控制台输出纯文本诊断日志。

local MOD_ID = "HeadsetTeamAutoSwitch"
local DEBUG = false

local function Log(message)
    if DEBUG then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

-- 装备完成点 (After): 物品已注册到肢体槽位, 按佩戴者阵营改写其 WifiComponent.TeamID。
-- 门控链全部前置, 无阵营生物与无 WifiComponent 的物品在头几行退出,
-- 常规装备操作仅多一次组件类型查找, 零额外开销。
Hook.Patch(MOD_ID, "Barotrauma.Item", "Equip", { "Barotrauma.Character" }, function(instance, ptable)
    local item = instance
    local character = ptable["character"]
    if item == nil or item.Removed
        or character == nil or character.Removed or character.IsDead then
        return
    end

    -- 无阵营生物 (怪物等) 没有"所在阵营"可切换, 直接退出
    local team = character.TeamID
    if team == CharacterTeamType.None then return end

    local wifi = item.GetComponentString("WifiComponent")
    if wifi == nil then return end

    -- 频道阵营已一致 (例如本阵营出厂耳机) 时零写入, 避免无意义的状态变更
    if wifi.TeamID ~= team then
        wifi.TeamID = team
        Log("headset channel team switched: " .. tostring(item.Name)
            .. " -> " .. tostring(team)
            .. " (wearer: " .. tostring(character.Name) .. ")")
    end
end, Hook.HookMethodType.After)
