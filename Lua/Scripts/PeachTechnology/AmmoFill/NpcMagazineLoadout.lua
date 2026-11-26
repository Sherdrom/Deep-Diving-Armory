-- NpcMagazineLoadout: NPC与船员(玩家初始角色/新招募)生成时为虚拟弹匣填充配置弹药
--
-- 实现原理:
--   Hook.Patch (After) on Barotrauma.HumanPrefab.InitializeItem:
--   引擎按ItemSet给NPC发放物品的静态方法, 每件物品调用一次,
--   参数同时携带 Character 与 HumanPrefab.
--   Character.Prefab 对 npcset NPC 是基础 Human 预制，因此从 humanPrefab 参数读取 NPC 身份。
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
--   通过游戏的可序列化属性写入 LoadedAmmoIdentifiersArray:
--   setter 内部 LoadAmmoArray 按 MaxSize 截断并拒收不兼容弹药,
--   结尾 UpdateAmmoData 同步 Condition 并触发 SyncAmmoState,
--   服务端自动 CreateServerEvent 把弹栈全量同步给客户端.
--
-- 限制说明 (多人同步):
--   本脚本仅服务端/单机加载(见 init.lua 的服务端块),
--   NPC仅由服务端生成, 弹匣状态经 VCE 服务器事件同步, 客户端只读.
--   两条生成路径都只在角色首次创建时填充一次, 不做持续监控:
--   NPC路径(HumanPrefab.InitializeItem): Team1不入队不填充,
--     招募发生在延迟窗口内时, 处理时的队伍检查同样拦截.
--   Job路径(Job.GiveJobItems): 玩家初始角色/新招募船员/中途加入的玩家.
--     巡回切换时船员物品栏由存档恢复, 不重发Job物品, 不会过巡回自动补满.
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
    -- 弹匣统一为NewMag.xml虚拟弹匣, 身份按 Coalition.xml/CoalitionElite.xml 的 npc identifier
    NpcAmmo = {
        deep_co_soldier = { "556x45round_tit", "762x51round_tit", "57x28round_tit" },
        deep_co_soldier_elite = { "556x45round_tit", "762x51round_tit", "57x28round_tit" },
        deep_co_striker = { "45acpround_tit" },
        deep_co_striker_elite = { "45acpround_tit" },
        deep_co_heavy = { "556x45round_tit", "57x28round_tit" },
        deep_co_heavy_elite = { "556x45round_tit", "57x28round_tit" },
        deep_co_sniper = { "338lmround_tit", "762x51round_tit", "127x99round_tit", "45acpround_tit" },
        deep_co_sniper_elite = { "338lmround_tit", "762x51round_tit", "127x99round_tit", "45acpround_tit" },
        deep_co_grenadier = { "556x45round_tit", "45acpround_tit" },
        deep_co_grenadier_elite = { "556x45round_tit", "45acpround_tit" },
        deep_co_leader = { "762x51round_tit", "556x45round_tit", "545x39round_tit", "127x99round_tit", "57x28round_tit" },
        deep_co_leader_elite = { "762x51round_tit", "556x45round_tit", "545x39round_tit", "127x99round_tit", "57x28round_tit" },
        deep_co_blaster = { "45acpround_tit" },
        deep_co_blaster_elite = { "45acpround_tit" },
        deep_co_hunter_elite = { "556x45round_tit", "762x51round_tit" },
        deep_pirate_rookie = { "9x19round_lead", "45acpround_lead", "762x39round_lead", "9x18round_lead" },
        deep_pirate_soldier = { "762x39round_lead", "545x39round", "762x63round_lead", "9x19round_lead", "45acpround_lead" },
        deep_pirate_soldier_elite = { "762x39round_lead", "545x39round", "762x63round_lead", "9x19round_lead", "45acpround_lead" },
        deep_pirate_scout = { "45acpround_lead", "9x19round_lead" },
        deep_pirate_scout_elite = { "45acpround_lead", "9x19round_lead" },
        deep_pirate_heavy = { "762x39round_lead", "545x39round", "792x57round_lead", "9x19round_lead" },
        deep_pirate_heavy_elite = { "762x39round_lead", "545x39round", "792x57round_lead", "9x19round_lead" },
        deep_pirate_leader_easy = { "556x45round", "303round_lead", "762x54rround_lead", "762x51round_lead", "45acpround_lead" },
        deep_pirate_leader_normal = { "556x45round", "303round_lead", "762x51round_lead", "762x39round_lead", "45acpround_lead" },
        deep_pirate_leader_normal_elite = { "556x45round", "303round_lead", "762x51round_lead", "762x39round_lead", "45acpround_lead" },
        deep_pirate_leader_hard = { "762x39round_lead", "303round_lead", "9x19round_tit", "45acpround_lead" },
        deep_pirate_leader_hard_elite = { "762x39round_lead", "762x54rround_lead", "762x51round_lead", "45acpround_lead" },
        deep_pirate_hunter_elite = { "9x39round_lead", "45acpround_lead" },
        deep_grizzlies_team_juggernaut = { "545x39round_phy", "9x19round_phy" },
        deep_grizzlies_team_juggernaut_elite = { "545x39round_7n39", "9x19round_phy" },
        deep_grizzlies_political_commissar = { "50swround_lead", "9x19round_phy" },
        deep_grizzlies_political_commissar_elite = { "50swround_lead", "9x19round_phy" },
        deep_grizzlies_machinegun_fort = { "762x54rround_lead", "9x19round_phy" },
        deep_grizzlies_machinegun_fort_elite = { "792x57round_lead", "9x19round_phy" },
        deep_grizzlies_heavy_gunner = { "127x99round_phy", "9x19round_phy" },
        deep_grizzlies_heavy_gunner_elite = { "9x19round_phy" },
        deep_grizzlies_heavy_gl = { "545x39round_phy", "9x19round_phy" },
        deep_grizzlies_heavy_gl_elite = { "545x39round_phy", "9x19round_phy" },
        deep_grizzlies_leader = { "545x39round_7n39", "9x19round_phy" },
        deep_grizzlies_leader_elite = { "127x99round_lead", "9x19round_phy" },
        deep_grizzlies_hunter_elite = { "9x39round_fu", "127x55round_FU" },
        deep_separatist_soldier_moderate = { "9x18round_lead", "545x39round_tit", "762x39round_tit", "556x45round_tit" },
        deep_separatist_striker_moderate = { "45acpround_lead" },
        deep_separatist_heavy_moderate = { "9x19round_tit", "45acpround_tit" },
        deep_separatist_sniper_moderate = { "338lmround_tit", "762x51round_tit", "45acpround_tit" },
        deep_separatist_grenadier_moderate = { "9x19round_tit", "45acpround_lead" },
        deep_separatist_blaster_moderate = { "45acpround_lead" },
        deep_separatist_soldier_hard = { "545x39round_phy", "338lmround_tit", "45acpround_tit" },
        deep_separatist_striker_hard = { "45acpround_lead" },
        deep_separatist_heavy_hard = { "545x39round_tit", "556x45round_tit", "45acpround_tit" },
        deep_separatist_leader_hard = { "556x45round_phy", "545x39round_tit", "762x51round_tit", "338lmround_tit", "45acpround_tit" },
        deep_separatist_sniper_hard = { "338lmround_tit", "762x51round_tit", "127x99round_tit", "45acpround_lead" },
        deep_separatist_grenadier_hard = { "57x28round_tit", "45acpround_lead" },
        deep_separatist_blaster_hard = { "45acpround_lead" },
        deep_separatist_soldier_elite = { "545x39round_phy", "338lmround_tit", "45acpround_tit" },
        deep_separatist_striker_elite = { "45acpround_lead" },
        deep_separatist_heavy_elite = { "545x39round_tit", "556x45round_tit", "45acpround_tit" },
        deep_separatist_sniper_elite = { "338lmround_tit", "762x51round_tit", "127x99round_tit", "45acpround_lead" },
        deep_separatist_grenadier_elite = { "57x28round_tit", "45acpround_lead" },
        deep_separatist_blaster_elite = { "45acpround_lead" },
        deep_separatist_leader_elite = { "556x45round_phy", "545x39round_tit", "762x51round_tit", "338lmround_tit", "45acpround_tit" },
        deep_separatist_hunter_elite = { "9x39round_du" },
        deep_ghost_Fearless_Vanguard = { "57x28round_phy", "46x30round_phy", "9x19round_FU" },
        deep_ghost_Fearless_Vanguard_elite = { "57x28round_phy", "46x30round_phy", "9x19round_FU" },
        deep_ghost_sniper = { "57x28round_phy", "338lmround_tit", "762x51round_phy" },
        deep_ghost_sniper_elite = { "57x28round_phy", "127x99round_lead", "338lmround_phy", "762x51round_M61" },
        deep_ghost_special_forces = { "57x28round_phy", "556x45round_phy" },
        deep_ghost_special_forces_elite = { "57x28round_phy", "556x45round_phy" },
        deep_ghost_hunter_elite = { "57x28round_phy", "46x30round_fu", "556x45round_phy" },
        deep_ghost_leader = { "45acpround_phy", "762x51round_phy", "556x45round_phy" },
        deep_ghost_leader_elite = { "45acpround_phy", "762x51round_phy", "556x45round_phy" },
        deep_pigcat_easy = { "545x39round" },
        deep_pigcat_medium = { "545x39round_tit", "45acpround_lead" },
        deep_pigcat_reinforce_easy = { "545x39round", "9x18round_lead" },
        deep_pigcat_contract_room_pirate = { "9x39round_du", "9x18round_lead" },
        deep_mobile_city_typhoon_shop = { "9x19round_lead" },
        deep_pigcat_team_2r4g = { "9x39round_ap" },
        deep_pigcat_team_39 = { "762x51round_M993" },
        deep_pigcat_team_50bro = { "556x45round_phy", "57x28round_phy" },
        deep_pigcat_team_alice = { "9x19round_phy" },
        deep_pigcat_team_baidi = { "9x39round_ap" },
        deep_pigcat_team_baidi_hunter = { "58x42round_ap" },
        deep_pigcat_team_baixi = { "58x42round_fu", "762x54rround_phy" },
        deep_pigcat_team_baka = { "556x45round_SSA_AP" },
        deep_pigcat_team_ben = { "9x19round_phy" },
        deep_pigcat_team_binary = { "58x42round_ap", "45acpround_phy" },
        deep_pigcat_team_cat_master = { "58x42round_du" },
        deep_pigcat_team_cifang = { "762x51round_M993", "9x19round_phy" },
        deep_pigcat_team_douzi = { "792x57round_AP" },
        deep_pigcat_team_FL = { "127x55round_FU", "50aeround_phy" },
        deep_pigcat_team_fl_hunter = { "762x51round_M993" },
        deep_pigcat_team_godfatherkeha = { "127x55round_FU", "57x28round_phy" },
        deep_pigcat_team_handong = { "57x28round_phy" },
        deep_pigcat_team_heyuanmu = { "762x51round_M993" },
        deep_pigcat_team_huohuade = { "9x39round_ap" },
        deep_pigcat_team_kuai = { "9x39round_ap" },
        deep_pigcat_team_ludao = { "762x51round_M993" },
        deep_pigcat_team_luoweier = { "127x99round_phy", "57x28round_phy" },
        deep_pigcat_team_man = { "792x57round_AP", "9x39round_ap" },
        deep_pigcat_team_mark = { "9x19round_phy" },
        deep_pigcat_team_noob = { "556x45round_SSA_AP" },
        deep_pigcat_team_peachhat = { "762x51round_M993", "9x19round_phy" },
        deep_pigcat_team_pigbig = { "9x19round_phy" },
        deep_pigcat_team_rat_snake = { "792x57round_AP" },
        deep_pigcat_team_renhan = { "9x18round_phy" },
        deep_pigcat_team_renhan_hunter = { "9x39round_ap", "50aeround_phy" },
        deep_pigcat_team_roger = { "556x45round_SSA_AP", "338lmround_AP" },
        deep_pigcat_team_ruarua = { "127x99round_phy" },
        deep_pigcat_team_taidian = { "762x51round_M993" },
        deep_pigcat_team_top = { "762x51round_M993" },
        deep_pigcat_team_tuanzi = { "762x39round_MAI_AP", "50swround_phy" },
        deep_pigcat_team_xianbei = { "9x39round_ap" },
        deep_pigcat_team_moonwolf = { "762x51round_M993" },
        deep_pigcat_team_thesun = { "762x39round_BP", "762x39round_MAI_AP" },
        deep_pigcat_team_thesun_hunter = { "762x39round_BP", "762x39round_MAI_AP" },
        deep_pigcat_team_xuefeng = { "792x33round_phy" },
        deep_pigcat_team_diluka = { "762x51round_depleted_uranium" },
        deep_pigcat_team_douzi_hunter = { "deep_12shell_phy" },
        deep_pigcat_team2_jiushang = { "50aeround_phy" },
        deep_pigcat_team2_xiaosong = { "50aeround_phy" },
        deep_pigcat_team2_xishen = { "762x51round_M993" },
        deep_pigcat_team_xiaochun = { "338lmround_AP" },
        deep_pigcat_team_xiaohua = { "50beowulfround_AP", "9x19round_phy" },
        deep_pigcat_team_yangpai = { "762x51round_M993" },
        deep_pigcat_team_yangtuo = { "50swround_phy" },
        deep_pigcat_team2_feiyu = { "127x99round_phy", "50aeround_phy" },
        deep_pigcat_team2_luosu = { "58x42round_ap", "45acpround_phy" },
        deep_pigcat_team2_meilisi = { "50swround_phy" },
        deep_pigcat_team2_qaz_75 = { "9x39round_ap", "50swround_phy" },
        deep_pigcat_team2_qingning = { "762x39round_MAI_AP" },
        deep_pigcat_team2_qlocks = { "50swround_phy" },
        deep_pigcat_team2_ruangutou = { "762x54rround_phy", "9x18round_phy" },
        deep_pigcat_team2_super_sitelin = { "57x28round_fu", "9x19round_phy" },
        deep_pigcat_team2_tinqianxi = { "58x42round_ap", "762x54rround_FU" },
        deep_pigcat_team2_wuming = { "762x51round_phy" },
        deep_pigcat_team2_xiaoguang = { "9x39round_ap", "9x19round_phy" },
        deep_pigcat_team2_zhuxi = { "9x39round_fu" },
        armsdealer = { "9x18round_lead" },
        bandit = { "45acpround_lead", "9x19round_lead" },
        bandit_heavy = { "762x39round_lead", "545x39round", "9x19round_lead" },
        captain = { "44mground_lead" },
        hireablecoalitionsecurityofficer = { "556x45round" },
        hireablecoalitionsecurityofficerveteran = { "556x45round" },
        hireableseparatistsecurityofficer = { "762x39round_lead" },
        hireableseparatistsecurityofficerveteran = { "762x39round_lead" },
        hrmanager = { "9x19round_lead" },
        merchantarmory = { "9x19round_lead" },
        merchantcity = { "9x19round_lead" },
        merchantmilitary = { "9x19round_lead" },
        merchantmine = { "9x19round_lead" },
        merchantoutpost = { "9x19round_lead" },
        merchantresearch = { "9x19round_lead" },
        outpostmanager = { "44mground_lead" },
        outpostmanagercoalition = { "44mground_lead" },
        outpostmanagerseparatists = { "44mground_lead" },
        reactoroperator = { "9x19round_lead" },
        securitynpccoalition = { "556x45round", "9x19round_lead", "45acpround_lead" },
        securitynpcseparatists = { "545x39round", "762x39round_lead", "9x39round_lead", "9x18round_lead" },
        subupgradenpc = { "9x19round_lead" },
        watchman = { "556x45round" },
        watchmanseparatist = { "545x39round" },
    },
    -- 未配置NPC的默认弹药优先级: nil表示未配置的NPC完全不处理
    DefaultAmmo = nil,
    -- 弹匣标识符 -> 强制弹药: 优先级高于NpcAmmo/CrewAmmo, 不做兼容检查
    MagOverrides = {
        -- deep_556x45_virtual_30_stanag = "556x45round_tit",
    },
    -- Job路径(玩家初始角色/新招募船员): job标识符 -> 弹药优先级列表
    -- 每个弹匣取第一个口径兼容的弹种, 混口径职业按顺序列出全部口径
    CrewAmmo = {
        captain = { "45acpround_lead", "44mground_lead" },
        engineer = { "9x19round_lead", "45acpround_lead" },
        mechanic = { "9x19round_lead", "45acpround_lead" },
        securityofficer = { "762x39round_lead", "556x45round", "45acpround_lead" },
    },
    -- 未配置job的兜底弹药优先级: nil表示未配置的job完全不填充
    DefaultCrewAmmo = nil,
}

local loadedAmmoProperty = Identifier("LoadedAmmoIdentifiersArray")

local pendingCharacters = {}
local queuedCharacters = {}
local identityByCharacter = {}
local preferenceByCharacter = {}

local function Log(msg)
    print("[" .. MOD_NAME .. "] " .. tostring(msg))
end

local function LogDebug(msg)
    if Config.Debug then Log(msg) end
end

-- 从补丁参数表取 HumanPrefab, 返回其 npcset 身份标识符
-- 注意: 本环境ptable是userdata, 不可pairs遍历, 只能按参数名取值
local function GetNpcIdentifier(ptable)
    local prefab = ptable["humanPrefab"]
    if prefab == nil then return nil end
    return tostring(prefab.Identifier)
end

local function ProcessMagazine(item, preference)
    local override = Config.MagOverrides[tostring(item.Prefab.Identifier)]
    local candidates = override and { override } or preference
    local before = item.Condition
    local remaining = math.floor(item.MaxCondition) - math.floor(before)
    if not candidates or #candidates == 0 or remaining <= 0 then return false end

    local magazine = item.OwnInventory and item.OwnInventory.Container
    local property = magazine and magazine.SerializableProperties[loadedAmmoProperty]
    if not property then return false end

    -- 每个候选弹种都足以填满空位，VCE 按顺序接收第一个兼容弹种，只同步一次。
    local batches = {}
    for i, ammoId in ipairs(candidates) do
        batches[i] = string.rep(ammoId, remaining, ";")
    end
    return property:TrySetValue(magazine, table.concat(batches, ";")) and item.Condition > before
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
    if not character.IsHuman then return end
    local inventory = character.Inventory
    if inventory == nil then return end

    local identity = identityByCharacter[character] or tostring(character.Prefab.Identifier)
    local preference = preferenceByCharacter[character]

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
    LogDebug(identity .. " done, filled=" .. filled .. " skipped=" .. skipped)

    identityByCharacter[character] = nil
    preferenceByCharacter[character] = nil
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

        local identity = GetNpcIdentifier(ptable) or tostring(character.Prefab.Identifier)
        local preference = Config.NpcAmmo[identity] or Config.DefaultAmmo
        if preference == nil and next(Config.MagOverrides) == nil then
            LogDebug(identity .. " not configured, skip character")
            return
        end

        if queuedCharacters[character] then return end
        queuedCharacters[character] = true
        identityByCharacter[character] = identity
        preferenceByCharacter[character] = preference
        pendingCharacters[#pendingCharacters + 1] = {
            character = character,
            dueTime = Timer.GetTime() + Config.ProcessDelay,
        }
        LogDebug("queued character " .. tostring(character.Name) .. " (" .. identity .. ")")
    end,
    Hook.HookMethodType.After
)

-- Job.GiveJobItems(character, isPvPMode, spawnPoint):
-- 玩家初始角色/新招募船员/中途加入玩家的装备发放, 每角色仅首次创建时触发.
-- 巡回切换时船员物品栏由存档恢复, 不重发Job物品, 因此不会过巡回自动补满.
-- 此路径包含玩家本体, 不做IsBot/Team1过滤.
Hook.Patch(
    MOD_NAME .. ".QueueOnGiveJobItems",
    "Barotrauma.Job",
    "GiveJobItems",
    {
        "Barotrauma.Character",
        "System.Boolean",
        "Barotrauma.WayPoint",
    },
    function(instance, ptable)
        local character = ptable["character"]
        if character == nil or character.Removed then return end
        if not character.IsHuman then return end
        if instance == nil or instance.Prefab == nil then return end
        if queuedCharacters[character] then return end

        local jobIdentifier = tostring(instance.Prefab.Identifier)
        local preference = Config.CrewAmmo[jobIdentifier] or Config.DefaultCrewAmmo
        if preference == nil and next(Config.MagOverrides) == nil then
            LogDebug("crew job " .. jobIdentifier .. " not configured, skip character")
            return
        end

        identityByCharacter[character] = "crew_" .. jobIdentifier
        preferenceByCharacter[character] = preference
        queuedCharacters[character] = true
        pendingCharacters[#pendingCharacters + 1] = {
            character = character,
            dueTime = Timer.GetTime() + Config.ProcessDelay,
        }
        LogDebug("queued crew character " .. tostring(character.Name) .. " (job " .. jobIdentifier .. ")")
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
    identityByCharacter = {}
    preferenceByCharacter = {}
end)
