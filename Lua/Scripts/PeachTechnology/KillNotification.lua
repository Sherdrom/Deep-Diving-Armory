local NotificationDuration = 4.0
local BaseFontScale = 1.1
local Spacing = 35
local RightPadding = 20
local TopOffset = -5
local TextPadding = 3

if not CLIENT then
    return
end

local killInfos = {}
local lastThinkTime = Timer.Time
local alertedVictims = {}
local pendingKills = {}

local function GetVictimID(character)
    local id = character.ID
    if id ~= nil then
        return tostring(id)
    end
    return tostring(character)
end

local function GetCharacterName(character)
    if character == nil then
        return "Unknown"
    end

    if character.Name ~= nil and character.Name ~= "" then
        return character.Name
    end

    if character.TeamID == CharacterTeamType.Team1 then
        local name = character.Prefab.Name:ToString()
        if name ~= nil and name ~= "" then
            return name
        end
    end

    local identifier = character.Prefab.Identifier:ToString()
    if identifier ~= nil and identifier ~= "" then
        local key = "character." .. identifier
        local localized = TextManager.Get(key)
        if localized ~= nil then
            local value = localized.Value
            if value ~= nil and value ~= "" and value ~= key then
                return value
            end
        end
    end

    local prefabName = character.Prefab.Name:ToString()
    if prefabName ~= nil and prefabName ~= "" then
        return prefabName
    end

    local speciesName = character.SpeciesName:ToString()
    if speciesName ~= nil and speciesName ~= "" then
        return speciesName
    end

    local typeName = character:GetType().Name
    if typeName ~= nil and typeName ~= "" then
        return typeName
    end

    return "Unknown"
end

local function FindKiller(character)
    if character == nil or character.CharacterHealth == nil then
        return nil
    end

    local affs = character.CharacterHealth:GetAllAfflictions()
    if affs == nil then
        return nil
    end

    local enumerator = affs:GetEnumerator()
    if enumerator == nil then
        return nil
    end

    while enumerator:MoveNext() do
        local aff = enumerator.Current
        if aff ~= nil then
            local affSource = aff.Source
            if affSource ~= nil and affSource ~= character then
                return affSource
            end
        end
    end

    return nil
end

Hook.Add("character.damageLimb", "KillNotificationDamage", function(character, _, _, _, _, _, _, attacker, _)
    if attacker == nil or character == nil then
        return
    end
    if attacker == character then
        return
    end

    local victimID = GetVictimID(character)
    pendingKills[victimID] = {
        attacker = attacker,
        time = Timer.Time,
    }
end)

Hook.Add("characterDeath", "KillNotification", function(character)
    if character == nil then
        return
    end

    local victimName = GetCharacterName(character)

    if not character.IsDead then
        return
    end

    local victimID = GetVictimID(character)
    if alertedVictims[victimID] then
        return
    end

    local killer = nil
    local pk = pendingKills[victimID]
    if pk ~= nil then
        killer = pk.attacker
    end
    if killer == nil or killer == character then
        return
    end

    local killerName = GetCharacterName(killer)

    local isPlayerKill = killer.IsPlayer
    if not isPlayerKill then
        return
    end

    alertedVictims[victimID] = true

    local isVictimHuman = character.IsHuman

    local killerTeam = killer.TeamID
    local victimTeam = character.TeamID

    local isSameTeam = (killerTeam == victimTeam)

    if isVictimHuman and isSameTeam then
        table.insert(killInfos, {
            AttackerName = killerName,
            VictimName = victimName,
            RemainingTime = NotificationDuration,
            IsRed = true,
        })
        SoundPlayer.PlaySound("deep_player_death", 0.5)
    elseif isVictimHuman then
        table.insert(killInfos, {
            AttackerName = killerName,
            VictimName = victimName,
            RemainingTime = NotificationDuration,
            IsRed = false,
        })
        local isLocalKiller = (Character.Controlled == killer)
        if isLocalKiller then
            SoundPlayer.PlaySound("deep_player_kill", 0.8)
        end
    else
        table.insert(killInfos, {
            AttackerName = killerName,
            VictimName = victimName,
            RemainingTime = NotificationDuration,
            IsRed = false,
        })
    end
end)

Hook.Add("think", "KillNotificationThink", function()
    local now = Timer.Time
    local dt = now - lastThinkTime
    lastThinkTime = now

    if dt > 0.1 then
        dt = 0.1
    end

    local i = 1
    while i <= #killInfos do
        killInfos[i].RemainingTime = killInfos[i].RemainingTime - dt
        if killInfos[i].RemainingTime <= 0 then
            table.remove(killInfos, i)
        else
            i = i + 1
        end
    end

    for victimID, data in pairs(pendingKills) do
        if Timer.Time - data.time > 10.0 then
            pendingKills[victimID] = nil
        end
    end
end)

Hook.Patch(
    "Barotrauma.GUI",
    "Draw",
    { "Barotrauma.Camera", "Microsoft.Xna.Framework.Graphics.SpriteBatch" },
    function(_, ptable)
        if #killInfos == 0 then
            return
        end

        local spriteBatch = ptable["spriteBatch"]
        if spriteBatch == nil then
            return
        end

        local font = nil
        local scalableFont = nil

        local staticGUIStyle = LuaUserData.CreateStatic("Barotrauma.GUIStyle")
        if staticGUIStyle ~= nil then
            if staticGUIStyle.LargeFont ~= nil then
                font = staticGUIStyle.LargeFont
                if font.Value ~= nil then
                    scalableFont = font.Value
                end
            elseif staticGUIStyle.Font ~= nil then
                font = staticGUIStyle.Font
                if font.Value ~= nil then
                    scalableFont = font.Value
                end
            end
        end

        if scalableFont == nil and font == nil and staticGUIStyle ~= nil then
            local fontsDict = staticGUIStyle.Fonts
            if fontsDict ~= nil then
                for key, value in pairs(fontsDict) do
                    local keyStr = tostring(key)
                    if keyStr == "LargeFont" or keyStr == "SubHeadingFont" or keyStr == "DigitalFont" then
                        if value ~= nil then
                            font = value
                            if value.Value ~= nil then
                                scalableFont = value.Value
                            end
                            if scalableFont ~= nil then break end
                        end
                    end
                end
            end
        end

        if scalableFont == nil and staticGUIStyle ~= nil then
            font = staticGUIStyle.Font
            if font ~= nil then
                scalableFont = font.Value
            end
        end

        if scalableFont == nil and staticGUIStyle ~= nil then
            font = staticGUIStyle.SmallFont
            if font ~= nil then
                scalableFont = font.Value
            end
        end

        local screenWidth = 0
        local screenHeight = 0
        local uiWidth = 0

        local gameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")

        uiWidth = GUI.UIWidth

        if uiWidth == nil or uiWidth <= 0 then
            uiWidth = 1920
        end

        if gameMain ~= nil then
            screenWidth = gameMain.GraphicsWidth
        end

        if screenWidth == nil or screenWidth <= 0 then
            screenWidth = uiWidth
        end

        if screenWidth == nil or screenWidth <= 0 then
            screenWidth = 1920
        end

        if gameMain ~= nil then
            screenHeight = gameMain.GraphicsHeight
        end

        if screenHeight == nil or screenHeight <= 0 then
            screenHeight = math.floor(screenWidth * (1080 / 1920))
        end

        if screenHeight == nil or screenHeight <= 0 then
            screenHeight = 1080
        end

        local guiScale = 1.0
        guiScale = GUI.Scale
        if guiScale == nil or guiScale <= 0 then
            guiScale = 1.0
        end

        local guiTextBlock = LuaUserData.CreateStatic("Barotrauma.GUITextBlock")

        local scaledTextPadding = math.floor(TextPadding / guiScale)

        local yOffset = math.floor(TopOffset / guiScale)

        for _, ki in ipairs(killInfos) do
            local alpha = math.min(math.max(ki.RemainingTime / NotificationDuration, 0), 1)
            local byteAlpha = math.floor(alpha * 255)

            local textColor
            local barColor
            if ki.IsRed then
                textColor = Color(255, 60, 60, byteAlpha)
                barColor = Color(255, 60, 60, byteAlpha)
            else
                textColor = Color(255, 255, 255, byteAlpha)
                barColor = Color(255, 255, 255, byteAlpha)
            end

            local text = ki.AttackerName .. " Kill " .. ki.VictimName

            local renderScale = math.max(0.5, math.min(2.0, BaseFontScale / guiScale))

            local measuredWidth = #text * 10
            local measuredHeight = 18
            if scalableFont ~= nil then
                local ts = scalableFont:MeasureString(text)
                if ts ~= nil then
                    measuredWidth = ts.X
                    measuredHeight = ts.Y
                end
            elseif font ~= nil then
                local ts = font:MeasureString(text)
                if ts ~= nil then
                    measuredWidth = ts.X
                    measuredHeight = ts.Y
                end
            end

            local extraUIWidth = 0
            local uiW = GUI.UIWidth
            local gw = nil
            if gameMain ~= nil then
                gw = gameMain.GraphicsWidth
            end
            if uiW ~= nil and gw ~= nil and uiW < gw then
                extraUIWidth = gw - uiW
            end

            local actualScreenWidth = screenWidth - extraUIWidth
            local scaledTextWidth = measuredWidth * renderScale * GUI.xScale
            local scaledTextHeight = measuredHeight * renderScale

            local RIGHT_MARGIN = 5 * GUI.xScale
            local positionX = actualScreenWidth - scaledTextWidth - RIGHT_MARGIN

            if positionX < RIGHT_MARGIN then
                positionX = RIGHT_MARGIN
                scaledTextWidth = actualScreenWidth - RIGHT_MARGIN * 2
            end

            local position = Vector2(positionX + extraUIWidth, yOffset)

            local barWidth = 4
            local bgPadding = scaledTextPadding
            local bgX = position.X - bgPadding
            local bgY = position.Y - bgPadding
            local bgW = scaledTextWidth + bgPadding * 2
            local bgH = scaledTextHeight + bgPadding * 2

            GUI.DrawFilledRectangle(spriteBatch,
                Vector2(bgX, bgY),
                Vector2(bgW, bgH),
                Color(0, 0, 0, math.floor(200 * (byteAlpha / 255))))
            GUI.DrawFilledRectangle(spriteBatch,
                Vector2(bgX, bgY),
                Vector2(barWidth, bgH),
                barColor)

            local textPos = Vector2(position.X + 4, position.Y)

            if scalableFont ~= nil then
                scalableFont.DrawString(spriteBatch, text, textPos, textColor)
            elseif font ~= nil then
                GUI.DrawString(spriteBatch, textPos, text, textColor, nil, 0, font)
            else
                local textBlock = nil

                local rectT = RectTransform(Vector2(position.X, position.Y), Vector2(measuredWidth, measuredHeight))
                local richText = RichString(text)

                textBlock = guiTextBlock(rectT, richText,
                    textColor,
                    nil,
                    Alignment.Left,
                    false,
                    "",
                    nil)

                if textBlock ~= nil then
                    textBlock.TextScale = renderScale
                    textBlock:DrawManually(spriteBatch)
                end

                if textBlock == nil then
                    GUI.DrawString(spriteBatch,
                        textPos,
                        text, textColor, nil, 0)
                end
            end

            yOffset = yOffset + scaledTextHeight + math.floor(Spacing / guiScale)
            if yOffset > screenHeight - 50 then
                break
            end
        end
    end,
    Hook.HookMethodType.After
)
