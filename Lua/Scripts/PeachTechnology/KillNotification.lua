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
    local id = nil
    pcall(function()
        id = character.ID
    end)
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
        local ok, name = pcall(function()
            return character.Prefab.Name:ToString()
        end)
        if ok and name ~= nil and name ~= "" then
            return name
        end
    end

    local ok1, identifier = pcall(function()
        return character.Prefab.Identifier:ToString()
    end)
    if ok1 and identifier ~= nil and identifier ~= "" then
        local key = "character." .. identifier
        local ok2, localized = pcall(function()
            return TextManager.Get(key)
        end)
        if ok2 and localized ~= nil then
            local ok3, value = pcall(function()
                return localized.Value
            end)
            if ok3 and value ~= nil and value ~= "" and value ~= key then
                return value
            end
        end
    end

    local ok4, prefabName = pcall(function()
        return character.Prefab.Name:ToString()
    end)
    if ok4 and prefabName ~= nil and prefabName ~= "" then
        return prefabName
    end

    local ok5, speciesName = pcall(function()
        return character.SpeciesName:ToString()
    end)
    if ok5 and speciesName ~= nil and speciesName ~= "" then
        return speciesName
    end

    local ok6, typeName = pcall(function()
        return character:GetType().Name
    end)
    if ok6 and typeName ~= nil and typeName ~= "" then
        return typeName
    end

    return "Unknown"
end

local function FindKiller(character)
    if character == nil or character.CharacterHealth == nil then
        return nil
    end

    local ok, affs = pcall(function()
        return character.CharacterHealth:GetAllAfflictions()
    end)
    if not ok or affs == nil then
        return nil
    end

    local ok2, enumerator = pcall(function()
        return affs:GetEnumerator()
    end)
    if not ok2 or enumerator == nil then
        return nil
    end

    local affCount = 0
    while true do
        local hasNext = false
        pcall(function()
            hasNext = enumerator:MoveNext()
        end)
        if not hasNext then
            break
        end
        local aff = enumerator.Current
        affCount = affCount + 1
        if aff ~= nil then
            local affSource = nil
            pcall(function()
                affSource = aff.Source
            end)
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

    local isPlayerKill = false
    pcall(function()
        isPlayerKill = killer.IsPlayer
    end)
    if not isPlayerKill then
        return
    end

    alertedVictims[victimID] = true

    local isVictimHuman = false
    pcall(function()
        isVictimHuman = character.IsHuman
    end)

    local killerTeam = nil
    local victimTeam = nil
    pcall(function()
        killerTeam = killer.TeamID
        victimTeam = character.TeamID
    end)

    local isSameTeam = (killerTeam == victimTeam)

    if isVictimHuman and isSameTeam then
        table.insert(killInfos, {
            AttackerName = killerName,
            VictimName = victimName,
            RemainingTime = NotificationDuration,
            IsRed = true,
        })
        pcall(function()
            SoundPlayer.PlaySound("deep_player_death", 0.5)
        end)
    elseif isVictimHuman then
        table.insert(killInfos, {
            AttackerName = killerName,
            VictimName = victimName,
            RemainingTime = NotificationDuration,
            IsRed = false,
        })
        local isLocalKiller = false
        pcall(function()
            isLocalKiller = (Character.Controlled == killer)
        end)
        if isLocalKiller then
            pcall(function()
                SoundPlayer.PlaySound("deep_player_kill", 0.8)
            end)
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

        pcall(function()
            local guiStyleDescriptor = Descriptors["Barotrauma.GUIStyle"]
            if guiStyleDescriptor ~= nil then
                pcall(function()
                    LuaUserData.MakeFieldAccessible(guiStyleDescriptor, "Font")
                    LuaUserData.MakeFieldAccessible(guiStyleDescriptor, "LargeFont")
                    LuaUserData.MakeFieldAccessible(guiStyleDescriptor, "SmallFont")
                    LuaUserData.MakeFieldAccessible(guiStyleDescriptor, "SubHeadingFont")
                end)

                local staticGUIStyle = LuaUserData.CreateStatic("Barotrauma.GUIStyle", false)
                if staticGUIStyle ~= nil then
                    if staticGUIStyle.LargeFont ~= nil then
                        font = staticGUIStyle.LargeFont
                        pcall(function()
                            if font.Value ~= nil then
                                scalableFont = font.Value
                            end
                        end)
                    elseif staticGUIStyle.Font ~= nil then
                        font = staticGUIStyle.Font
                        pcall(function()
                            if font.Value ~= nil then
                                scalableFont = font.Value
                            end
                        end)
                    end
                end
            end
        end)

        if scalableFont == nil and font == nil then
            pcall(function()
                local fontsDict = GUIStyle.Fonts
                if fontsDict ~= nil then
                    for key, value in pairs(fontsDict) do
                        local keyStr = tostring(key)
                        if keyStr == "LargeFont" or keyStr == "SubHeadingFont" or keyStr == "DigitalFont" then
                            if value ~= nil then
                                font = value
                                pcall(function()
                                    if value.Value ~= nil then
                                        scalableFont = value.Value
                                    end
                                end)
                                if scalableFont ~= nil then break end
                            end
                        end
                    end
                end
            end)
        end

        if scalableFont == nil and font == nil then
            pcall(function()
                font = GUIStyle.LargeFont
                if font ~= nil then
                    pcall(function()
                        scalableFont = font.Value
                    end)
                end
            end)
        end

        if scalableFont == nil then
            pcall(function()
                font = GUIStyle.Font
                if font ~= nil then
                    scalableFont = font.Value
                end
            end)
        end

        if scalableFont == nil then
            pcall(function()
                font = GUIStyle.SmallFont
                if font ~= nil then
                    scalableFont = font.Value
                end
            end)
        end

        local screenWidth = 0
        local screenHeight = 0
        local uiWidth = 0

        pcall(function()
            uiWidth = GUI.UIWidth
        end)

        if uiWidth == nil or uiWidth <= 0 then
            uiWidth = 1920
        end

        pcall(function()
            screenWidth = GameMain.GraphicsWidth
        end)

        if screenWidth == nil or screenWidth <= 0 then
            screenWidth = uiWidth
        end

        if screenWidth == nil or screenWidth <= 0 then
            screenWidth = 1920
        end

        pcall(function()
            screenHeight = GameMain.GraphicsHeight
        end)

        if screenHeight == nil or screenHeight <= 0 then
            screenHeight = math.floor(screenWidth * (1080 / 1920))
        end

        if screenHeight == nil or screenHeight <= 0 then
            screenHeight = 1080
        end

        local guiScale = 1.0
        pcall(function()
            guiScale = GUI.Scale
        end)
        if guiScale == nil or guiScale <= 0 then
            guiScale = 1.0
        end

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
                pcall(function()
                    local ts = scalableFont:MeasureString(text)
                    if ts ~= nil then
                        measuredWidth = ts.X
                        measuredHeight = ts.Y
                    end
                end)
            elseif font ~= nil then
                pcall(function()
                    local ts = font:MeasureString(text)
                    if ts ~= nil then
                        measuredWidth = ts.X
                        measuredHeight = ts.Y
                    end
                end)
            end

            local extraUIWidth = 0
            pcall(function()
                local uiW = GUI.UIWidth
                local gw = GameMain.GraphicsWidth
                if uiW ~= nil and gw ~= nil and uiW < gw then
                    extraUIWidth = gw - uiW
                end
            end)

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

            pcall(function()
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
                    local drawSuccess = pcall(function()
                        scalableFont.DrawString(spriteBatch,
                            text,
                            textPos,
                            textColor,
                            0,
                            Vector2(0, 0),
                            renderScale,
                            SpriteEffects.None,
                            0)
                    end)

                    if not drawSuccess then
                        pcall(function()
                            scalableFont.DrawString(spriteBatch,
                                text,
                                textPos,
                                textColor)
                        end)
                    end
                elseif font ~= nil then
                    local drawSuccess = pcall(function()
                        font.DrawString(spriteBatch,
                            text,
                            textPos,
                            textColor,
                            0,
                            Vector2(0, 0),
                            renderScale,
                            SpriteEffects.None,
                            0)
                    end)

                    if not drawSuccess then
                        pcall(function()
                            GUI.DrawString(spriteBatch,
                                textPos,
                                text, textColor, nil, 0, font)
                        end)
                    end
                else
                    local textBlock = nil

                    pcall(function()
                        local rectT = RectTransform(Vector2(position.X, position.Y), Vector2(measuredWidth, measuredHeight))
                        local richText = RichString(text)

                        textBlock = GUITextBlock(rectT, richText,
                            textColor,
                            nil,
                            Alignment.Left,
                            false,
                            "",
                            nil)

                        if textBlock ~= nil then
                            pcall(function()
                                textBlock.TextScale = renderScale
                            end)

                            local drawSuccess = pcall(function()
                                textBlock:DrawManually(spriteBatch)
                            end)

                            if not drawSuccess then
                                pcall(function()
                                    textBlock:Draw(spriteBatch)
                                end)
                            end
                        end
                    end)

                    if textBlock == nil then
                        GUI.DrawString(spriteBatch,
                            textPos,
                            text, textColor, nil, 0)
                    end
                end
            end)

            yOffset = yOffset + scaledTextHeight + math.floor(Spacing / guiScale)
            if yOffset > screenHeight - 50 then
                break
            end
        end
    end,
    Hook.HookMethodType.After
)
