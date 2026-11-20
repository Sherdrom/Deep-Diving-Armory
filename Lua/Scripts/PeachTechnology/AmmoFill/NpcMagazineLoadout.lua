-- NpcMagazineLoadout: 指定NPC生成时为指定虚拟弹匣填充配置弹药
--
-- 实现原理:
--   Hook.Patch (After) on Barotrauma.HumanPrefab.InitializeItem:
--   引擎按ItemSet给NPC发放物品的静态方法, 每件物品调用一次,
--   参数同时携带 Character 与 HumanPrefab.
--   注意: Character.Prefab 对npcset NPC是基础 Human 预制,
--   npcset身份(如 deep_co_soldier)必须从 HumanPrefab.Identifier 读取.
--   本环境用 LuaUserData.IsTargetType 从参数表识别 HumanPrefab
--   (避免依赖具体参数名), 识别后记录 身份->角色 映射并入队(每角色一次).
--   延迟 ProcessDelay 秒(默认0.5)后在 think 中处理:
--   等待 ItemSet 物品与弹匣内部虚拟弹容器就位
--   (EntitySpawnerBudget 插件会延迟重放 InitializeItem, 该延迟一并覆盖).
--   遍历角色物品栏(AllItemsMod, 代码库已验证的迭代方式, 覆盖枪内/包内),
--   仅处理带 deep_virtualmagazine 标签的真弹匣(NewMag.xml 全部弹匣);
--   MF工厂件(VirtualizedMagazineFactory)无此标签, 永不处理:
--   1. Config.MagOverrides 命中弹匣标识符 -> 使用强制指定弹药
--   2. 否则按 Config.NpcAmmo[NPC身份] 的弹药优先级列表,
--      逐个经 IsAmmoCompatible 兼容检查, 取第一个兼容弹药
--   3. 均未命中则跳过, 弹匣保持空弹状态
--   标识符统一用 tostring(Prefab.Identifier) 读取(代码库已验证方式).
--   填充通过 LoadedAmmoIdentifiersArray 属性 setter 完成:
--   setter 内部 LoadAmmoArray 按 MaxSize 截断并拒收不兼容弹药,
--   结尾 UpdateAmmoData 同步 Condition 并触发 SyncAmmoState,
--   服务端自动 CreateServerEvent 把弹栈全量同步给客户端.
--
-- 限制说明 (多人同步):
--   本脚本仅服务端/单机加载(见 init.lua 的服务端块),
--   NPC仅由服务端生成, 弹匣状态经 VCE 服务器事件同步, 客户端只读.
--   只在NPC生成时填充一次, 不做持续监控, 也不影响玩家弹匣.
--   Team1(玩家队伍, NPC可被招募加入)不入队不填充,
--   招募发生在延迟窗口内时, 处理时的队伍检查同样拦截.
--
-- 依赖:
--   VCE (Vanilla Components Expanded) 的 VirtualizedMagazine 组件,
--   组件不存在或弹药未配置时自动跳过, 不产生副作用.

local MOD_NAME = "NpcMagazineLoadout"
-- 虚拟弹匣标签: NewMag.xml 全部弹匣均带此标签, 工厂件(MF)不带
local MAG_TAG = "deep_virtualmagazine"

local Config = {
    Debug = false,
    -- 角色入队到填充的延迟秒数: 等待物品栏与弹匣内部虚拟弹容器就位
    ProcessDelay = 0.5,
    -- 弹匣识别: item.HasTag(MAG_TAG), 无需维护弹匣名单
    -- NPC身份(HumanPrefab.Identifier) -> 弹药优先级列表:
    -- 逐个尝试, 第一个与弹匣兼容的弹药生效
    NpcAmmo = {
        deep_co_soldier = { "556x45round_tit" },
        deep_co_striker = { "556x45round_tit" },
        deep_co_heavy = { "556x45round_tit" },
        deep_co_sniper = { "556x45round_tit" },
        deep_co_grenadier = { "556x45round_tit" },
        deep_co_leader = { "556x45round_tit" },
        deep_co_blaster = { "556x45round_tit" },
    },
    -- 未配置NPC的默认弹药优先级: nil表示未配置的NPC完全不处理
    DefaultAmmo = nil,
    -- 弹匣标识符 -> 强制弹药: 优先级高于NpcAmmo, 不做兼容检查
    MagOverrides = {
        -- deep_556x45_virtual_30_stanag = "556x45round_tit",
    },
}

-- VCE组件不在游戏默认命名空间, GetComponentString按类名查不到,
-- 按代码库已验证方式(VirtualMagazineReload.lua)注册类型后遍历匹配
local VIRTUAL_COMPONENT_TYPE = "VCE_VirtualizedMagazine.VirtualizedMagazine"
local EMPTY_PREFERENCE = {}

LuaUserData.RegisterType(VIRTUAL_COMPONENT_TYPE)

local pendingCharacters = {}
local queuedCharacters = {}
local npcIdentifierByCharacter = {}

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if Config.Debug then Log(msg) end
end

-- 遍历物品组件按类型匹配虚拟弹匣组件
local function GetVirtualComponent(item)
    for comp in item.Components do
        if LuaUserData.IsTargetType(comp, VIRTUAL_COMPONENT_TYPE) then
            return comp
        end
    end
    return nil
end

-- 从补丁参数表取 HumanPrefab, 返回其 npcset 身份标识符
-- 注意: 本环境ptable是userdata, 不可pairs遍历, 只能按参数名取值
local function GetNpcIdentifier(ptable)
    local prefab = ptable["humanPrefab"]
    if prefab == nil then return nil end
    return tostring(prefab.Identifier)
end

-- 选出该弹匣应填充的弹药标识符, 返回nil表示跳过
local function SelectAmmo(comp, itemIdentifier, preference)
    local ammoId = Config.MagOverrides[itemIdentifier]
    if ammoId ~= nil then return ammoId end
    if preference == nil then return nil end
    for _, candidate in ipairs(preference) do
        if comp.IsAmmoCompatible(candidate) then return candidate end
    end
    return nil
end

-- 清空并按指定弹药填满弹匣, 返回是否成功
local function ProcessMagazine(item, preference)
    local itemIdentifier = tostring(item.Prefab.Identifier)
    local comp = GetVirtualComponent(item)
    if comp == nil then
        LogDebug("no " .. VIRTUAL_COMPONENT_TYPE .. " component on " .. itemIdentifier)
        return false
    end

    local ammoId = SelectAmmo(comp, itemIdentifier, preference or EMPTY_PREFERENCE)
    if ammoId == nil then
        LogDebug("no compatible ammo for " .. itemIdentifier)
        return false
    end

    local maxSize = comp.MaxSize
    if maxSize == nil or maxSize <= 0 then
        LogDebug("invalid MaxSize on " .. itemIdentifier)
        return false
    end

    -- NPC弹匣生成时弹栈为空(无ProjectileIdentifiers配置), 直接压入即可;
    -- setter内部按MaxSize截断, 泛型Stack未注册不可直接调Clear/Push
    local rounds = {}
    for i = 1, maxSize do
        rounds[i] = ammoId
    end
    comp.LoadedAmmoIdentifiersArray = rounds
    LogDebug("filled " .. itemIdentifier .. " with " .. tostring(ammoId) .. " x" .. maxSize)
    return true
end

-- 递归收集白名单弹匣: AllItemsMod不递归, 枪内/包内弹匣需经OwnInventory下钻
local function CollectTargetMagazines(inventory, result, visited)
    if inventory == nil then return end
    for item in inventory.AllItemsMod do
        if item ~= nil and not item.Removed and not visited[item] then
            visited[item] = true
            if item.HasTag(MAG_TAG) then
                result[#result + 1] = item
            end
            if item.OwnInventory ~= nil then
                CollectTargetMagazines(item.OwnInventory, result, visited)
            end
        end
    end
end

local function ProcessCharacter(character)
    if character == nil or character.Removed then return end
    if not character.IsHuman or character.IsBot == false then return end
    if character.TeamID == CharacterTeamType.Team1 then return end
    local inventory = character.Inventory
    if inventory == nil then return end

    local identifier = npcIdentifierByCharacter[character]
        or tostring(character.Prefab.Identifier)
    local preference = Config.NpcAmmo[identifier] or Config.DefaultAmmo
    local hasOverrides = next(Config.MagOverrides) ~= nil
    if preference == nil and not hasOverrides then
        LogDebug(identifier .. " not configured, skip character")
        return
    end

    local mags = {}
    CollectTargetMagazines(inventory, mags, {})
    local filled, skipped = 0, 0
    for _, magItem in ipairs(mags) do
        if ProcessMagazine(magItem, preference) then
            filled = filled + 1
        else
            skipped = skipped + 1
        end
    end
    LogDebug(identifier .. " done, filled=" .. filled .. " skipped=" .. skipped)
end

-- 引擎按ItemSet发放物品的静态方法, 每件物品调用一次:
-- 记录npcset身份并入队(每角色仅入队一次)
Hook.Patch(
    MOD_NAME .. ".QueueOnInitializeItem",
    "Barotrauma.HumanPrefab",
    "InitializeItem",
    {
        "Barotrauma.Character",
        "Barotrauma.ContentXElement",
        "Barotrauma.Submarine",
        "Barotrauma.HumanPrefab",
        "Barotrauma.WayPoint",
        "Barotrauma.Item",
        "System.Boolean",
    },
    function(_, ptable)
        local character = ptable["character"]
        if character == nil or character.Removed then return end
        if not character.IsHuman or character.IsBot == false then return end
        if character.TeamID == CharacterTeamType.Team1 then return end

        local npcIdentifier = GetNpcIdentifier(ptable)
        if npcIdentifier ~= nil then
            npcIdentifierByCharacter[character] = npcIdentifier
            LogDebug("identity " .. npcIdentifier .. " for " .. tostring(character.Name))
        end

        if queuedCharacters[character] then return end
        queuedCharacters[character] = true
        pendingCharacters[#pendingCharacters + 1] = {
            character = character,
            dueTime = Timer.GetTime() + Config.ProcessDelay,
        }
        LogDebug("queued character " .. tostring(character.Name))
    end,
    Hook.HookMethodType.After
)

Hook.Add("think", MOD_NAME, function()
    if #pendingCharacters == 0 then return end
    local now = Timer.GetTime()
    local remaining = {}
    for _, entry in ipairs(pendingCharacters) do
        if now < entry.dueTime then
            remaining[#remaining + 1] = entry
        else
            ProcessCharacter(entry.character)
        end
    end
    pendingCharacters = remaining
end)

Hook.Add("stop", MOD_NAME, function()
    pendingCharacters = {}
    queuedCharacters = {}
    npcIdentifierByCharacter = {}
end)
