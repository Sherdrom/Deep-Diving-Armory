local DeepHitMarker = {
    HitHintSize = 10,
    KillHintSize = 30,
    CrosshairDistance = 12,
    HitHintDuration = 0.25,
    KillHintDuration = 0.5,
    DebugMode = false,
}

if not CLIENT then
    return
end

local HitHintTimer = 0
local KillHintTimer = 0
local HitHintColor = Color.White
local IsHeadshot = false

local lastThinkTime = Timer.Time
local frameCount = 0
local hitCount = 0
local drawCount = 0

local function dbg(...)
    if not DeepHitMarker.DebugMode then return end
    print("[DeepHitMarker]", ...)
end

local function IsOutOfScreen(position)
    if Screen.Selected == nil or Screen.Selected.Cam == nil then
        dbg("IsOutOfScreen: Screen/Cam is nil → true")
        return true
    end
    local view = Screen.Selected.Cam.WorldView
    local result = position.X < view.X
        or position.X > view.Right
        or position.Y > view.Y
        or position.Y < view.Y - view.Height
    if result then
        dbg("IsOutOfScreen: TRUE  pos=(", position.X, ",", position.Y, ") view=(", view.X, ",", view.Y, ",", view.Width, "x", view.Height, ")")
    end
    return result
end

local function IsDefaultAttackResult(result)
    local isDefault = result.Damage == 0
        and result.Afflictions == nil
        and result.HitLimb == nil
        and result.AppliedDamageModifiers == nil
    if isDefault then
        dbg("IsDefaultAttackResult: TRUE (Damage=" .. tostring(result.Damage) .. ")")
    end
    return isDefault
end

local function DrawHint(spriteBatch, position)
    if HitHintTimer <= 0 and KillHintTimer <= 0 then
        return
    end

    drawCount = drawCount + 1
    if drawCount <= 5 or drawCount % 30 == 0 then
        dbg("DRAW#" .. drawCount .. " HitTimer=" .. string.format("%.4f", HitHintTimer) .. " KillTimer=" .. string.format("%.4f", KillHintTimer) .. " Headshot=" .. tostring(IsHeadshot) .. " pos=(" .. string.format("%.1f", position.X) .. "," .. string.format("%.1f", position.Y) .. ")")
    end

    local color = IsHeadshot and Color.Red or Color.White

    if HitHintTimer > 0 then
        HitHintColor = Color(color.R, color.G, color.B, 255)
    else
        HitHintColor = Color(color.R, color.G, color.B, 0)
    end

    local size = math.max(DeepHitMarker.HitHintSize, 1)
    local distance = math.max(DeepHitMarker.CrosshairDistance, 0)

    GUI.DrawLine(spriteBatch,
        Vector2(position.X + distance, position.Y + distance),
        Vector2(position.X + distance + size, position.Y + distance + size),
        HitHintColor, 0, 4)

    GUI.DrawLine(spriteBatch,
        Vector2(position.X - distance, position.Y + distance),
        Vector2(position.X - distance - size, position.Y + distance + size),
        HitHintColor, 0, 4)

    GUI.DrawLine(spriteBatch,
        Vector2(position.X + distance, position.Y - distance),
        Vector2(position.X + distance + size, position.Y - distance - size),
        HitHintColor, 0, 4)

    GUI.DrawLine(spriteBatch,
        Vector2(position.X - distance, position.Y - distance),
        Vector2(position.X - distance - size, position.Y - distance - size),
        HitHintColor, 0, 4)

    if KillHintTimer > 0 then
        local alpha = KillHintTimer / DeepHitMarker.KillHintDuration
        local killAlpha = math.min(alpha, 1.0) * 255
        local killColor = Color(255, 0, 0, math.floor(killAlpha))
        local killSize = math.max(DeepHitMarker.KillHintSize, 1)

        GUI.DrawRectangle(spriteBatch,
            position, killSize * 2, killSize * 2,
            math.pi / 4, killColor, 0, 2)
    end
end

Hook.Patch(
    "Barotrauma.Items.Components.RangedWeapon",
    "DrawHUD",
    {
        "Microsoft.Xna.Framework.Graphics.SpriteBatch",
        "Barotrauma.Character"
    },
    function(instance, ptable)
        frameCount = frameCount + 1
        if frameCount <= 3 then
            dbg("DrawHUD hook #" .. frameCount)
        end

        local position = PlayerInput.MousePosition

        if position == nil then
            return
        end

        if frameCount <= 3 then
            dbg("MousePosition = (" .. string.format("%.1f", position.X) .. "," .. string.format("%.1f", position.Y) .. ")")
        end

        DrawHint(ptable["spriteBatch"], position)
    end,
    Hook.HookMethodType.After
)

Hook.Patch(
    "Barotrauma.Character",
    "ApplyAttack",
    {
        "Barotrauma.Character",
        "Microsoft.Xna.Framework.Vector2",
        "Barotrauma.Attack",
        "System.Single",
        "Microsoft.Xna.Framework.Vector2",
        "System.Boolean",
        "Barotrauma.Limb",
        "System.Single"
    },
    function(instance, ptable)
        hitCount = hitCount + 1

        local attacker = ptable["attacker"]
        local result = ptable.ReturnValue

        if instance == nil then
            if hitCount <= 3 then dbg("ApplyAttack: instance is nil") end
            return
        end
        if attacker == nil then
            if hitCount <= 3 then dbg("ApplyAttack: attacker is nil") end
            return
        end

        if hitCount <= 3 then
            dbg("ApplyAttack #" .. hitCount .. " attacker=" .. tostring(attacker.Name) .. " target=" .. tostring(instance.Name) .. " Damage=" .. tostring(result.Damage))
        end

        if IsDefaultAttackResult(result) then return end

        if hitCount <= 3 then
            dbg("ApplyAttack: not default! Damage=" .. tostring(result.Damage) .. " attacker=" .. tostring(attacker.Name) .. " Controlled=" .. tostring(Character.Controlled ~= nil and Character.Controlled.Name or "nil"))
        end

        if attacker ~= Character.Controlled then
            if hitCount <= 3 then
                dbg("ApplyAttack: attacker is NOT controlled character, skipping")
            end
            return
        end

        if hitCount <= 3 then
            dbg("ApplyAttack: attacker IS controlled character!")
        end

        if IsOutOfScreen(instance.WorldPosition) then
            if hitCount <= 3 then dbg("ApplyAttack: target is out of screen") end
            return
        end

        HitHintTimer = DeepHitMarker.HitHintDuration
        dbg(">>> HIT! HitHintTimer set to " .. tostring(HitHintTimer))

        if instance.IsDead then
            KillHintTimer = DeepHitMarker.KillHintDuration
            dbg(">>> KILL! KillHintTimer set to " .. tostring(KillHintTimer))
        end

        local hitLimb = result.HitLimb
        if hitLimb ~= nil then
            dbg("HitLimb: " .. tostring(hitLimb.Name) .. " type=" .. tostring(hitLimb.type))
            if hitLimb.type == LimbType.Head then
                IsHeadshot = true
                dbg(">>> HEADSHOT!")
            else
                IsHeadshot = false
            end
        else
            dbg("HitLimb is nil")
            IsHeadshot = false
        end
    end,
    Hook.HookMethodType.After
)

Hook.Add("think", "DeepHitMarkerUpdate", function()
    local now = Timer.Time
    local dt = now - lastThinkTime
    lastThinkTime = now

    if dt > 0.1 then
        dt = 0.1
    end

    local prevHit = HitHintTimer
    local prevKill = KillHintTimer

    if HitHintTimer > 0 then
        HitHintTimer = math.max(HitHintTimer - dt, 0)
    end

    if KillHintTimer > 0 then
        KillHintTimer = math.max(KillHintTimer - dt, 0)
    end

    if prevHit > 0 and HitHintTimer == 0 then
        dbg("THINK: HitHintTimer expired")
    end
    if prevKill > 0 and KillHintTimer == 0 then
        dbg("THINK: KillHintTimer expired")
    end
end)
