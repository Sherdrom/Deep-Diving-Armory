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

	if not killer.IsPlayer then
		return
	end

	alertedVictims[victimID] = true

	local victimName = GetCharacterName(character)
	local killerName = GetCharacterName(killer)
	local isVictimHuman = character.IsHuman
	local isSameTeam = (killer.TeamID == character.TeamID)

	local entry = {
		AttackerName = killerName,
		VictimName = victimName,
		RemainingTime = NotificationDuration,
		IsRed = isVictimHuman and isSameTeam,
	}

	killInfos[#killInfos + 1] = entry

	if isVictimHuman and isSameTeam then
		SoundPlayer.PlaySound("deep_player_death", 0.5)
	elseif isVictimHuman and Character.Controlled == killer then
		SoundPlayer.PlaySound("deep_player_kill", 0.8)
	end
end)

local lastPendingCleanup = 0

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
			killInfos[i] = killInfos[#killInfos]
			killInfos[#killInfos] = nil
		else
			i = i + 1
		end
	end

	if now - lastPendingCleanup >= 1.0 then
		lastPendingCleanup = now
		for victimID, data in pairs(pendingKills) do
			if now - data.time > 10.0 then
				pendingKills[victimID] = nil
			end
		end
	end
end)

local StaticGUIStyle = LuaUserData.CreateStatic("Barotrauma.GUIStyle")
local GameMain = LuaUserData.CreateStatic("Barotrauma.GameMain")
local GUITextBlockType = LuaUserData.CreateStatic("Barotrauma.GUITextBlock")

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
				if keyStr == "LargeFont" or keyStr == "SubHeadingFont" or keyStr == "DigitalFont" then
					if value then
						CachedFont = value
						if value.Value then
							CachedScalableFont = value.Value
							break
						end
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

		if not CachedScalableFont then
			CachedFont = StaticGUIStyle.SmallFont
			if CachedFont and CachedFont.Value then
				CachedScalableFont = CachedFont.Value
			end
		end
	end
end

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

		local scalableFont = CachedScalableFont
		local font = CachedFont

		local uiWidth = GUI.UIWidth
		if uiWidth == nil or uiWidth <= 0 then
			uiWidth = 1920
		end

		local screenWidth = uiWidth
		if GameMain then
			screenWidth = GameMain.GraphicsWidth
		end
		if screenWidth == nil or screenWidth <= 0 then
			screenWidth = uiWidth
		end
		if screenWidth == nil or screenWidth <= 0 then
			screenWidth = 1920
		end

		local screenHeight = nil
		if GameMain then
			screenHeight = GameMain.GraphicsHeight
		end
		if screenHeight == nil or screenHeight <= 0 then
			screenHeight = math.floor(screenWidth * (1080 / 1920))
		end
		if screenHeight == nil or screenHeight <= 0 then
			screenHeight = 1080
		end

		local guiScale = GUI.Scale
		if guiScale == nil or guiScale <= 0 then
			guiScale = 1.0
		end

		local scaledTextPadding = math.floor(TextPadding / guiScale)
		local yOffset = math.floor(TopOffset / guiScale)

		local extraUIWidth = 0
		local uiW = GUI.UIWidth
		local gw = GameMain and GameMain.GraphicsWidth
		if uiW and gw and uiW < gw then
			extraUIWidth = gw - uiW
		end

		local actualScreenWidth = screenWidth - extraUIWidth
		local RIGHT_MARGIN = 5 * GUI.xScale

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
			if scalableFont then
				local ts = scalableFont:MeasureString(text)
				if ts then
					measuredWidth = ts.X
					measuredHeight = ts.Y
				end
			elseif font then
				local ts = font:MeasureString(text)
				if ts then
					measuredWidth = ts.X
					measuredHeight = ts.Y
				end
			end

			local scaledTextWidth = measuredWidth * renderScale * GUI.xScale
			local scaledTextHeight = measuredHeight * renderScale

			local positionX = actualScreenWidth - scaledTextWidth - RIGHT_MARGIN
			if positionX < RIGHT_MARGIN then
				positionX = RIGHT_MARGIN
				scaledTextWidth = actualScreenWidth - RIGHT_MARGIN * 2
			end

			local position = Vector2(positionX + extraUIWidth, yOffset)

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
				Vector2(4, bgH),
				barColor)

			local textPos = Vector2(position.X + 4, position.Y)

			if scalableFont then
				scalableFont.DrawString(spriteBatch, text, textPos, textColor)
			elseif font then
				GUI.DrawString(spriteBatch, textPos, text, textColor, nil, 0, font)
			else
				local rectT = RectTransform(Vector2(position.X, position.Y), Vector2(measuredWidth, measuredHeight))
				local richText = RichString(text)

				local textBlock = GUITextBlockType(rectT, richText,
					textColor,
					nil,
					Alignment.Left,
					false,
					"",
					nil)

				if textBlock then
					textBlock.TextScale = renderScale
					textBlock:DrawManually(spriteBatch)
				else
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