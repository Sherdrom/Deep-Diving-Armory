-- =====================================================================
-- Death Equipment Recycling (死亡装备回收)
--
-- 功能:
--   当 human 角色死亡并生成遗物袋(duffelbag)时, 拦截原版 despawn 逻辑,
--   将遗物袋连同角色身上的全部物品一起转移进距离尸体最近且未装满的
--   deep_securesteelcabinet (深潜保险箱) 中。
--   场上无可用保险箱时, 完整回退原版行为 (遗物袋生成在尸体位置)。
--
-- 原版机制 (源码依据):
--   BarotraumaShared/SharedSource/Characters/Character.cs L3987-4060
--     - private void Despawn(bool createNetworkEvents = true)
--     - humans 使用 Tags.DespawnContainer ("despawncontainer" 标签,
--       即原版 duffelbag), 非 humans 使用 Params.DespawnContainer
--     - 解析链: identifier 查找 -> 标签扫描 -> metalcrate 兜底
--     - onItemContainerSpawned 回调: 添加 name/job 标签 -> 对遗传物质
--       递归触发 OnSevered -> 快照 AllItemsMod (仅顶层) 逐件入袋,
--       放不下则 Drop -> AddEntityToRemoveQueue 移除角色
--   BarotraumaShared/SharedSource/Networking/EntitySpawner.cs L301
--     - AddItemToSpawnQueue 库存目标重载 (8 参数),
--       spawnIfInventoryFull=true 时物品绝不丢失
--
-- 多人同步:
--   仅权威端执行 (单人进程或专用服务器; 现版本主机开服亦为独立服务器
--   进程, 主机玩家属于纯客户端)。物品转移通过 EntitySpawner 与
--   TryPutItem 自带的网络事件同步, 客户端零逻辑。
--
-- 边界回退 (不拦截, 原版行为原样执行):
--   - EnableDespawn 为 false 的角色
--   - 非 human / 未死亡的角色
--   - 断线死亡 (CauseOfDeathType.Disconnected, 物品需随角色保留)
--   - 带重生的 PvP 模式 (原版明确跳过遗物袋)
--   - 场上不存在可容纳的 deep_securesteelcabinet
-- =====================================================================

if not SERVER and Game.IsMultiplayer then return end

local MOD_ID = "DeathEquipmentRecycling"
local DEBUG = false

local CABINET_ID = Identifier("deep_securesteelcabinet")
local DESPAWN_CONTAINER_TAG = "despawncontainer"

-- 暴露 protected Inventory.PutItem (Inventory.cs L645): 强制入位需绕过容器
-- 限制校验, 且必须携带网络事件; ForceToSlot (L1076) 不移出原库存且不产生
-- 网络事件, 不可用于移动现有物品
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Inventory"], "PutItem")

-- 遗物袋预制体与保险箱缓存 (按回合缓存, roundStart 时失效以防内容包重载产生陈旧引用)
local despawnContainerPrefab = nil
local despawnContainerResolved = false
local cachedCabinets = nil

local function Log(message)
    if DEBUG then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

-- 原版解析链 (Character.cs L4002-4005): identifier 查找 -> despawncontainer
-- 标签扫描 -> metalcrate 兜底
-- Lua 适配说明: ItemPrefab.Tags 为 System.Collections.Immutable 的
-- ImmutableHashSet<Identifier>, 该程序集未注册到 MoonSharp, 成员无法从
-- Lua 访问; 原版标签扫描的实际产物即 duffelbag, 故以 identifier 查找等价替代
local function GetDespawnContainerPrefab()
    if not despawnContainerResolved then
        despawnContainerResolved = true
        despawnContainerPrefab = ItemPrefab.GetItemPrefab(DESPAWN_CONTAINER_TAG)
        if despawnContainerPrefab == nil then
            despawnContainerPrefab = ItemPrefab.GetItemPrefab("duffelbag")
        end
        if despawnContainerPrefab == nil then
            despawnContainerPrefab = ItemPrefab.GetItemPrefab("metalcrate")
        end
    end
    return despawnContainerPrefab
end

-- 保险箱缓存: 全量扫描 Item.ItemList 仅发生在回合开始与缓存未命中重建,
-- despawn 路径只遍历缓存条目 (个位数), 8000+ 物品场景不再每次全扫
local function RebuildCabinetCache()
    local cabinets = {}
    for _, item in pairs(Item.ItemList) do
        if item ~= nil and not item.Removed
            and item.Prefab ~= nil and item.Prefab.Identifier == CABINET_ID
            and item.OwnInventory ~= nil then
            cabinets[#cabinets + 1] = item
        end
    end
    cachedCabinets = cabinets
end

-- 距离尸体最近且可容纳遗物袋的保险箱 (已满跳过, 全部不可用返回 nil)
-- 缓存条目按次查询实时校验 (Removed / CanProbablyBePut), 陈旧条目自动过滤
local function ScanCabinets(worldPosition, bagPrefab)
    local nearestCabinet = nil
    local nearestDistSq = math.huge
    for i = 1, #cachedCabinets do
        local cabinet = cachedCabinets[i]
        if not cabinet.Removed and cabinet.OwnInventory:CanProbablyBePut(bagPrefab) then
            local distSq = Vector2.DistanceSquared(cabinet.WorldPosition, worldPosition)
            if distSq < nearestDistSq then
                nearestCabinet = cabinet
                nearestDistSq = distSq
            end
        end
    end
    return nearestCabinet
end

-- 查询未命中时重建一次缓存重试: 自愈回合中途新建/销毁的保险箱,
-- 仍无可用柜则返回 nil 回退原版行为
local function FindNearestCabinet(worldPosition, bagPrefab)
    if cachedCabinets == nil then
        RebuildCabinetCache()
    end
    local nearestCabinet = ScanCabinets(worldPosition, bagPrefab)
    if nearestCabinet == nil then
        RebuildCabinetCache()
        nearestCabinet = ScanCabinets(worldPosition, bagPrefab)
    end
    return nearestCabinet
end

-- 强制放入第一个空槽位 (Inventory.PutItem 无限制校验, 携带网络事件并正确
-- 移出原库存); 供 largeitem 等无法正常放入保险箱的溢出物品使用, 柜满返回 false
local function ForceIntoInventory(inventory, item, createNetworkEvents)
    for i = 0, inventory.Capacity - 1 do
        if inventory:GetItemAt(i) == nil then
            inventory:PutItem(item, i, nil, true, createNetworkEvents)
            return true
        end
    end
    return false
end

-- 镜像原版 PvP 判定 (Character.cs L3996-3997);
-- 单人下短路, 避免访问 Game.RespawnManager 触发客户端空引用
local function IsPvpWithRespawning()
    if not Game.IsMultiplayer then return false end
    local gameSession = Game.GameSession
    if gameSession == nil or gameSession.GameMode == nil then return false end
    if not LuaUserData.IsTargetType(gameSession.GameMode, "Barotrauma.PvPMode") then return false end
    return Game.RespawnManager ~= nil
end

-- 回合切换时使预制体与保险箱缓存失效
Hook.Add("roundStart", MOD_ID .. "_ResetCache", function()
    despawnContainerResolved = false
    despawnContainerPrefab = nil
    cachedCabinets = nil
end)

-- 拦截 Character.Despawn (私有方法, LuaPatcherService 以 NonPublic 绑定)
-- 调用路径: UpdateDespawn (尸体自然消失) / RespawnManager (重生清理) /
--           CampaignMode 端局结束 (仅 IsDead 角色, CampaignMode.cs L955)
Hook.Patch(
    MOD_ID,
    "Barotrauma.Character",
    "Despawn",
    function(instance, ptable)
        if instance == nil then return end
        -- 镜像 L3989: EnableDespawn 为 false 时原版直接返回
        if not instance.EnableDespawn then return end
        -- 仅处理死亡的人类角色, 其余走原版路径
        if not instance.IsHuman or not instance.IsDead then return end
        -- 镜像 L3998-4000: 断线死亡与 PvP 重生模式不生成遗物袋
        local causeOfDeath = instance.CauseOfDeath
        if causeOfDeath ~= nil and causeOfDeath.Type == CauseOfDeathType.Disconnected then return end
        if IsPvpWithRespawning() then return end
        if Entity.Spawner == nil then return end
        local bagPrefab = GetDespawnContainerPrefab()
        if bagPrefab == nil then return end
        local cabinet = FindNearestCabinet(instance.WorldPosition, bagPrefab)
        if cabinet == nil then return end

        local createNetworkEvents = ptable["createNetworkEvents"]
        ptable.PreventExecution = true
        Log("Redirecting despawn container of " .. tostring(instance.Name)
            .. " into deep_securesteelcabinet")

        -- 镜像 L4012: 生成目标从 WorldPosition 改为保险箱库存,
        -- spawnIfInventoryFull=true 保证极端时序下物品不丢失
        Entity.Spawner:AddItemToSpawnQueue(
            bagPrefab,
            cabinet.OwnInventory,
            nil,
            nil,
            function(bag)
                -- 完整镜像 onItemContainerSpawned (Character.cs L4015-4044)
                local characterInventory = instance.Inventory
                if characterInventory == nil then return end

                -- name/job 标签: 端局结束的 ID 卡清理依赖此标签链
                -- (CampaignMode.cs L965-973)
                bag:AddTag("name:" .. tostring(instance.Name))
                local info = instance.Info
                if info ~= nil and info.Job ~= nil then
                    bag:AddTag("job:" .. tostring(info.Job.Name))
                end

                local bagInventory = bag.OwnInventory
                if bagInventory == nil then return end

                -- 顶层物品快照 (AllItemsMod 非递归, 容器内物品随容器整体转移)
                local items = {}
                for _, item in pairs(characterInventory.AllItemsMod) do
                    if item ~= nil then
                        items[#items + 1] = item
                    end
                end

                -- 遗传物质递归触发 OnSevered (镜像 L4027-4032:
                -- 卸下装备时 GeneticMaterial.Update 会将其销毁, 需手动先行结算)
                for _, item in pairs(characterInventory:FindAllItems(nil, true)) do
                    if item ~= nil then
                        for _, component in pairs(item.Components) do
                            if LuaUserData.IsTargetType(component, "Barotrauma.Items.Components.GeneticMaterial") then
                                item:ApplyStatusEffects(ActionType.OnSevered, 1.0, instance)
                                break
                            end
                        end
                    end
                end

                -- 入袋; 溢出转保险箱: 正常放入失败时强制入位 (大件物品),
                -- 柜满才掉落 (原版仅掉落于尸体位置, 此处按需求增强为优先回收)
                local cabinetInventory = nil
                if cabinet ~= nil and not cabinet.Removed then
                    cabinetInventory = cabinet.OwnInventory
                end
                for i = 1, #items do
                    local item = items[i]
                    if not bagInventory:TryPutItem(item, nil, nil, createNetworkEvents) then
                        if cabinetInventory == nil then
                            item:Drop(instance, createNetworkEvents)
                        elseif not cabinetInventory:TryPutItem(item, nil, nil, createNetworkEvents) then
                            if not ForceIntoInventory(cabinetInventory, item, createNetworkEvents) then
                                item:Drop(instance, createNetworkEvents)
                            end
                        end
                    end
                end
                -- 移除角色必须在物品转移之后 (镜像 L4043)
                Entity.Spawner:AddEntityToRemoveQueue(instance)
            end,
            true,
            false,
            InvSlotType.None)
    end,
    Hook.HookMethodType.Before
)

-- DEBUG 测试命令: 快照后强制 DespawnNow, 避免迭代中修改 CharacterList
if DEBUG then
    Game.AddCommand(
        "DeathEquipmentRecycling_ForceDespawn",
        "Force despawn all dead human characters (Death Equipment Recycling test)",
        function()
            local corpses = {}
            for _, character in pairs(Character.CharacterList) do
                if character ~= nil and character.IsHuman and character.IsDead
                    and not character.Removed and character.EnableDespawn then
                    corpses[#corpses + 1] = character
                end
            end
            for i = 1, #corpses do
                corpses[i]:DespawnNow()
            end
        end,
        nil,
        false)
end
