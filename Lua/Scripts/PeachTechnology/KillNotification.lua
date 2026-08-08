if not CLIENT then return end

-- 配置
--------------------------------------------------
local NotificationDuration = 4.0 -- 提示持续时间（秒）
local BaseFontScale = 1.1 -- 字体缩放
local NotificationSpacing = 35 -- 每条消息之间的距离
local TopOffset = -5 -- 距离顶部偏移
local BackgroundPadding = 3 -- 背景边框留白

-- Mod配置
--------------------------------------------------
local EnableKillNotification = true
local _, myPackage = trygetpackage("Deep-Diving-Armory")
local success, cfg = ConfigService.TryGetConfig(
        SettingBase.Boolean,
        myPackage,
        "KillNotification"
    )

-- 初始化配置
if success then
    EnableKillNotification = cfg.Value
    -- 配置发生改变
    cfg.OnValueChanged.add(function(value)
        EnableKillNotification = value.Value
        print("[Deep-Diving-Armory] KillNotification Enabled = ".. tostring(EnableKillNotification))
    end)
else
    print("[Deep-Diving-Armory] KillNotification Cannot load config.")
end

-- 数据
--------------------------------------------------
-- 正在显示的提示
local KillInfos = {}

-- 最近一次攻击者
-- key = CharacterID
-- value = Character
local LastAttackers = {}

-- 已经提示过死亡
local AlertedVictims = {}

-- 上一次Think时间
local LastThinkTime = Timer.Time

-- 工具函数
--------------------------------------------------
-- 获取角色唯一ID, 不同版本Character.ID可能不存在
--------------------------------------------------
local function GetCharacterID(character)
    if character == nil then return nil end

    if character.ID ~= nil then
        return tostring(character.ID)
    end

    return tostring(character)
end

-- 获取角色名称
-- 优先级： DisplayName Name Identifier PrefabName SpeciesName
--------------------------------------------------
local function GetCharacterName(character)

    if character == nil then return "???" end

    if character.DisplayName and character.DisplayName ~= "" then
        return character.DisplayName
    end

    if character.Name and character.Name ~= "" then
        return character.Name
    end

    if character.Prefab then
        local identifier =
            character.Prefab.Identifier:ToString()

        if identifier ~= "" then
            local key = "character." .. identifier

            local text = TextManager.Get(key)

            if text and text.Value and text.Value ~= "" and text.Value ~= key then
                return text.Value
            end
        end
    end

    if character.Prefab then
        local prefab = character.Prefab.Name:ToString()

        if prefab ~= "" then
            return prefab
        end
    end

    if character.SpeciesName then
        local species = character.SpeciesName:ToString()

        if species ~= "" then 
            return species 
        end
    end

    return "???"
end

-- Font缓存
--------------------------------------------------
local GUIStyle =
    LuaUserData.CreateStatic("Barotrauma.GUIStyle")

-- GUIStyle.Font（Lua对象）
local CachedFont = nil

-- 真正绘制字体
local CachedScalableFont = nil

-- 获取字体
--------------------------------------------------
local function CacheFont()

    if GUIStyle == nil then return end

    -- LargeFont优先
    ------------------------------------------------
    CachedFont =
        GUIStyle.LargeFont
        or GUIStyle.Font
        or GUIStyle.SmallFont

    if CachedFont then
        CachedScalableFont =
            CachedFont.Value
    end
end

CacheFont()

-- 文本尺寸缓存
-- 避免每帧MeasureString
--------------------------------------------------
local TextSizeCache = {}

-- 获取文本大小
--------------------------------------------------
local function MeasureText(text)

    -- 已缓存
    local size =
        TextSizeCache[text]

    if size then
        return size.X, size.Y
    end

    -- 默认值
    ------------------------------------------------
    local width = #text * 10
    local height = 20

    -- 测量
    ------------------------------------------------
    if CachedScalableFont then
        local measured =
            CachedScalableFont:MeasureString(text)
        if measured then
            width = measured.X
            height = measured.Y
        end
    end

    -- 写入缓存
    ------------------------------------------------
    TextSizeCache[text] = {
        X = width, Y = height
    }

    return width, height
end

-- 创建一条新的击杀提示
--------------------------------------------------
local function AddKillInfo(attacker, victim, colorselect)
    local text =
        attacker .. "  [Kill]  " .. victim

    KillInfos[#KillInfos + 1] = {
        Text = text,
        RemainingTime = NotificationDuration,
        colorselect = colorselect
    }

    if colorselect == 1 then
        SoundPlayer.PlaySound("deep_player_death", 0.5)
    elseif colorselect == 2 then
        SoundPlayer.PlaySound("deep_player_kill", 1.0)
    end
end

---第一部分结束
-- Part 2
-- Damage Hook
-- Death Hook
-- Think
--------------------------------------------------
-- Damage Hook
-- 记录最近一次攻击者
-- 因为很多情况下角色受到伤害以后很久才死亡，pendingKills反而容易失效。
-- LastAttackers只保存最近一次攻击者即可。
--------------------------------------------------

Hook.Add(
    "character.damageLimb",
    "KillNotificationDamage",
    function(character, _, _, _, _, _, _, attacker)
        if not EnableKillNotification then return end

        -- 参数检查
        if character == nil or attacker == nil or character.IsDead then return end

        -- -- 自己打自己
        -- if attacker == character then return end

        -- 保存最近攻击者
        local id = GetCharacterID(character)

        if id then
            LastAttackers[id] = attacker
        end
    end
)

local colorselect = 0

-- Death Hook
--------------------------------------------------
Hook.Add( "characterDeath", "KillNotification", function(character)
        if not EnableKillNotification then return end

        if character == nil then return end

        if not character.IsDead then return end

        -- 获取角色ID
        ------------------------------------------------
        local id = GetCharacterID(character)

        if id == nil then return end

        -- 防止重复提示
        ------------------------------------------------
        if AlertedVictims[id] then return end

        local killer = nil
        -- 寻找击杀者
        ------------------------------------------------
        -- CauseOfDeath.Killer
        local cod = character.CauseOfDeath
        if cod then killer = cod.Killer end
        
        -- LastAttacker
        ------------------------------------------------
        if killer == nil then
            killer = character.LastAttacker 
        end

        -- Damage缓存
        ------------------------------------------------
        if killer == nil then
            killer = LastAttackers[id]
        end

        -- 找不到击杀者
        ------------------------------------------------
        -- if killer == nil then return end

        -- 自杀
        ------------------------------------------------
        -- if killer == character then return end

        -- -- 只提示玩家击杀
        -- ------------------------------------------------
        -- if not killer.IsPlayer then return end

        -- 已提示
        ------------------------------------------------
        AlertedVictims[id] = true

        -- 获取名称
        ------------------------------------------------
        local attackerName = GetCharacterName(killer)

        local victimName = GetCharacterName(character)

        -- 是否红色（友军，宠物）
        ------------------------------------------------
        colorselect = 0 -- normal
        if character.IsOnPlayerTeam or character.IsPet then
            colorselect = 1 -- team dead
        elseif killer == Character.Controlled then
            colorselect = 2 -- character kill
        elseif killer and killer.IsOnPlayerTeam then
            colorselect = 3 -- team kill
        end

        -- 添加提示
        ------------------------------------------------
        AddKillInfo( attackerName, victimName, colorselect)
end)

-- Think
--------------------------------------------------
local CleanupTimer = 0

Hook.Add(
    "think",
    "KillNotificationThink",
    function()

        if not EnableKillNotification then
            return
        end

        -- Delta Time
        ------------------------------------------------
        local now = Timer.Time

        local dt =
            now - LastThinkTime

        LastThinkTime = now

        -- 防止卡顿导致时间过大
        ------------------------------------------------
        if dt > 0.1 then
            dt = 0.1
        end

        -- 更新提示剩余时间
        ------------------------------------------------
        for i = #KillInfos, 1, -1 do
            local info = KillInfos[i]

            info.RemainingTime =
                info.RemainingTime - dt

            if info.RemainingTime <= 0 then

                table.remove(KillInfos, i)

            end
        end

        -- 每秒清理一次缓存
        ------------------------------------------------
        CleanupTimer = CleanupTimer + dt

        if CleanupTimer < 1 then
            return
        end

        CleanupTimer = 0

        -- 清理死亡记录
        ------------------------------------------------
        for id in pairs(AlertedVictims) do
            local found = false

            for _, character in pairs(Character.CharacterList) do
                if GetCharacterID(character) == id then

                    -- 角色复活
                    ------------------------------------------------
                    if not character.IsDead then
                        found = true
                    end

                    break

                end
            end

            if not found then
                AlertedVictims[id] = nil
                LastAttackers[id] = nil
            end
        end
    end
)

local textColor = {
    [0] = Color(255,255,255,225), -- normal
    [1] = Color(225,25,25,225), -- team dead
    [2] = Color(25,225,144,225), -- character kill
    [3] = Color(25,225,25,225) -- team kill
}

-- 第二部分结束
-- Part 3
-- GUI Draw
--------------------------------------------------
local GameMain =
    LuaUserData.CreateStatic("Barotrauma.GameMain")

-- 绘制Hook
--------------------------------------------------
Hook.Patch(
    "Barotrauma.GUI",
    "Draw",
    {
        "Barotrauma.Camera",
        "Microsoft.Xna.Framework.Graphics.SpriteBatch"
    },

    function(_,ptable)

        -- 没开启
        ------------------------------------------------
        if not EnableKillNotification then return end

        -- 没有消息
        ------------------------------------------------
        if #KillInfos == 0 then return end

        local spriteBatch = ptable["spriteBatch"]

        if spriteBatch == nil then return end

        -- GUI缩放
        ------------------------------------------------
        local scale = GUI.Scale

        if not scale or scale <= 0 then
            scale = 1
        end

        -- 屏幕尺寸
        ------------------------------------------------
        local screenWidth = GameMain.GraphicsWidth
        local screenHeight = GameMain.GraphicsHeight

        if not screenWidth or screenWidth <= 0 then
            screenWidth = 1920
        end
        if not screenHeight or screenHeight <= 0 then
            screenHeight = 1080
        end

        -- UI区域
        ------------------------------------------------
        local uiWidth = GUI.UIWidth

        if not uiWidth then
            uiWidth = screenWidth
        end

        local extraWidth =
            math.max(0, screenWidth - uiWidth)

        -- 常量
        ------------------------------------------------
        local rightMargin =
            5 * GUI.xScale

        local renderScale =
            math.max(
                0.5,
                math.min(
                    2,
                    BaseFontScale / scale
                )
            )

        local padding =
            math.floor(
                BackgroundPadding / scale
            )

        local y =
            math.floor(
                TopOffset / scale
            )

        -- 开始绘制
        ------------------------------------------------
        for _,info in ipairs(KillInfos) do
            -- Alpha
            --------------------------------------------
            local alpha =
                math.floor(
                    math.max(0,
                        math.min(255,
                        info.RemainingTime/NotificationDuration*255
                        )
                    )
                )

            -- 获取文字大小
            --------------------------------------------
            local width,height = MeasureText(info.Text)

            width = width * renderScale * GUI.xScale
            height = height * renderScale

            -- 右上角位置
            --------------------------------------------
            local x = screenWidth - extraWidth - width - rightMargin

            -- 黑色背景
            --------------------------------------------
            GUI.DrawFilledRectangle(
                spriteBatch,
                Vector2(x-padding,y-padding),
                Vector2(width+padding*2,height+padding*2),
                Color(0,0,0,alpha*0.8)
            )

            -- 左侧颜色条
            --------------------------------------------
            GUI.DrawFilledRectangle(spriteBatch,
                Vector2(x-padding,y-padding),
                Vector2(4,height+padding*2),
                textColor[info.colorselect]
            )

            -- 绘制文字
            --------------------------------------------
            if CachedScalableFont then
                CachedScalableFont.DrawString(
                    spriteBatch,
                    info.Text,
                    Vector2(x+4,y),
                    textColor[info.colorselect]
                )
            else
                GUI.DrawString(
                    spriteBatch,
                    Vector2(x+4,y),
                    info.Text,
                    textColor[info.colorselect]
                )
            end

            -- 下一条消息
            --------------------------------------------
            y = y + height + NotificationSpacing

            -- 超出屏幕停止绘制
            --------------------------------------------
            if y > screenHeight -50 then break end
        end
    end,Hook.HookMethodType.After
)

-- 第三部分结束
