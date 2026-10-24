local TARGET_TYPE_ID = "deep_mobile_city_typhoon"
local NOTIFY_DURATION = 5.0
local NOTIFY_TEXT = "Typhoon Has Landed"
local NOTIFY_SOUND = "deep_player_kill"
local NOTIFY_SOUND_VOLUME = 0.8

local function findSiblingLocation(conn, currentLocation)
    for _, loc in pairs(conn.Locations) do
        if loc ~= currentLocation then
            return loc
        end
    end
    return nil
end

local function hasNoneNeighbor(currentLocation)
    for _, conn in pairs(currentLocation.Connections) do
        local sibling = findSiblingLocation(conn, currentLocation)
        if sibling ~= nil and sibling.Type.Identifier.Value == "None" then
            return true
        end
    end
    return false
end

-- ==================== CLIENT: notification + sound ====================

if CLIENT then
    local notifications = {}
    local lastThinkTime = Timer.Time

    local StaticGUIStyle = LuaUserData.CreateStatic("Barotrauma.GUIStyle")
    local GameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")

    local CachedScalableFont = nil
    local CachedFont = nil

    do
        if StaticGUIStyle then
            if StaticGUIStyle.LargeFont then
                CachedFont = StaticGUIStyle.LargeFont
                if CachedFont.Value then
                    CachedScalableFont = CachedFont.Value
                end
            end
            if not CachedScalableFont and StaticGUIStyle.Font then
                CachedFont = StaticGUIStyle.Font
                if CachedFont.Value then
                    CachedScalableFont = CachedFont.Value
                end
            end
            if not CachedScalableFont and StaticGUIStyle.Fonts then
                for key, value in pairs(StaticGUIStyle.Fonts) do
                    local keyStr = tostring(key)
                    if keyStr == "LargeFont" or keyStr == "SubHeadingFont" then
                        if value and value.Value then
                            CachedFont = value
                            CachedScalableFont = value.Value
                            break
                        end
                    end
                end
            end
            if not CachedScalableFont then
                CachedFont = StaticGUIStyle.Font
                if CachedFont and CachedFont.Value then
                    CachedScalableFont = CachedFont.Value
                end
            end
        end
    end

    Hook.Add("TyphoonCall", "TyphoonCall.Notify", function(effect, deltaTime, entity, targets, worldPosition, element)
        local campaign = Game.GameSession.Campaign
        if not campaign then
            return
        end

        local currentLocation = campaign.Map.CurrentLocation
        if not currentLocation then
            return
        end

        if not hasNoneNeighbor(currentLocation) then
            return
        end

        notifications[#notifications + 1] = {
            text = NOTIFY_TEXT,
            remainingTime = NOTIFY_DURATION,
        }

        SoundPlayer.PlaySound(NOTIFY_SOUND, NOTIFY_SOUND_VOLUME)
    end)

    Hook.Add("think", "TyphoonCall.Think", function()
        local now = Timer.Time
        local dt = now - lastThinkTime
        lastThinkTime = now

        if dt > 0.1 then
            dt = 0.1
        end

        local i = 1
        while i <= #notifications do
            notifications[i].remainingTime = notifications[i].remainingTime - dt
            if notifications[i].remainingTime <= 0 then
                notifications[i] = notifications[#notifications]
                notifications[#notifications] = nil
            else
                i = i + 1
            end
        end
    end)

    Hook.Patch(
        "Barotrauma.GUI",
        "Draw",
        { "Barotrauma.Camera", "Microsoft.Xna.Framework.Graphics.SpriteBatch" },
        function(_, ptable)
            if #notifications == 0 then
                return
            end

            local spriteBatch = ptable["spriteBatch"]
            if spriteBatch == nil then
                return
            end

            local scalableFont = CachedScalableFont
            local font = CachedFont

            local screenWidth = 1920
            if GameMain and GameMain.GraphicsWidth then
                screenWidth = GameMain.GraphicsWidth
            end
            if screenWidth == nil or screenWidth <= 0 then
                screenWidth = 1920
            end

            local screenHeight = 1080
            if GameMain and GameMain.GraphicsHeight then
                screenHeight = GameMain.GraphicsHeight
            end
            if screenHeight == nil or screenHeight <= 0 then
                screenHeight = 1080
            end

            local guiScale = GUI.Scale
            if guiScale == nil or guiScale <= 0 then
                guiScale = 1.0
            end

            local rightMargin = 5 * GUI.xScale
            local topPadding = 8
            local baseFontScale = 1.2
            local yOffset = 0

            for _, notif in ipairs(notifications) do
                local alpha = notif.remainingTime / NOTIFY_DURATION
                if alpha > 1.0 then alpha = 1.0 end
                if alpha < 0.0 then alpha = 0.0 end
                local byteAlpha = math.floor(alpha * 255)

                local textColor = Color(255, 255, 255, byteAlpha)
                local bgColor = Color(0, 0, 0, math.floor(180 * alpha))
                local barColor = Color(180, 180, 220, byteAlpha)

                local renderScale = baseFontScale / guiScale
                if renderScale > 2.0 then renderScale = 2.0 end
                if renderScale < 0.5 then renderScale = 0.5 end

                local measuredWidth = #notif.text * 12
                local measuredHeight = 22

                if scalableFont then
                    local ts = scalableFont:MeasureString(notif.text)
                    if ts then
                        measuredWidth = ts.X
                        measuredHeight = ts.Y
                    end
                elseif font then
                    local ts = font:MeasureString(notif.text)
                    if ts then
                        measuredWidth = ts.X
                        measuredHeight = ts.Y
                    end
                end

                local textW = measuredWidth * renderScale * GUI.xScale
                local textH = measuredHeight * renderScale

                local positionX = screenWidth - textW - rightMargin
                if positionX < rightMargin then
                    positionX = rightMargin
                end

                local bgPad = 6
                local bgX = positionX - bgPad
                local bgY = topPadding + yOffset - bgPad
                local bgW = textW + bgPad * 2
                local bgH = textH + bgPad * 2

                GUI.DrawFilledRectangle(spriteBatch,
                    Vector2(bgX, bgY),
                    Vector2(bgW, bgH),
                    bgColor)
                GUI.DrawFilledRectangle(spriteBatch,
                    Vector2(bgX, bgY),
                    Vector2(4, bgH),
                    barColor)

                local textPos = Vector2(positionX + 4, topPadding + yOffset)

                if scalableFont then
                    scalableFont.DrawString(spriteBatch, notif.text, textPos, textColor)
                elseif font then
                    GUI.DrawString(spriteBatch, textPos, notif.text, textColor, nil, 0, font)
                else
                    GUI.DrawString(spriteBatch, textPos, notif.text, textColor, nil, 0)
                end

                yOffset = yOffset + textH + 28
                if yOffset > screenHeight - 50 then
                    break
                end
            end
        end,
        Hook.HookMethodType.After
    )
end

-- ==================== SERVER: location change ====================

if SERVER or not Game.IsMultiplayer then
    local usedLocations = {}

    Hook.Add("TyphoonCall", "TyphoonCall.Main", function(effect, deltaTime, entity, targets, worldPosition, element)
        local campaign = Game.GameSession.Campaign
        if not campaign then
            return
        end

        local currentLocation = campaign.Map.CurrentLocation
        if not currentLocation then
            return
        end

        if usedLocations[currentLocation] then
            return
        end

        local prefabs = currentLocation.Type.Prefabs
        if not prefabs.ContainsKey(TARGET_TYPE_ID) then
            print("[TyphoonCall] Target LocationType " .. TARGET_TYPE_ID .. " not found")
            return
        end
        local targetType = prefabs[TARGET_TYPE_ID]

        local connections = currentLocation.Connections
        local noneLocations = {}
        local noneIndex = 0

        for _, conn in pairs(connections) do
            local sibling = findSiblingLocation(conn, currentLocation)
            if sibling ~= nil and sibling.Type.Identifier.Value == "None" then
                noneIndex = noneIndex + 1
                noneLocations[noneIndex] = sibling
            end
        end

        if noneIndex == 0 then
            return
        end

        local target = noneLocations[math.random(1, noneIndex)]

        if target.LocationTypeChangesBlocked then
            print("[TyphoonCall] Location type change blocked for " .. target.DisplayName.Value)
            return
        end

        usedLocations[currentLocation] = true

        target.ChangeType(campaign, targetType)

        print("[TyphoonCall] Changed location " .. target.DisplayName.Value .. " from None to " .. TARGET_TYPE_ID)
    end)
end