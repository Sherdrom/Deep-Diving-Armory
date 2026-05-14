local HIT_HINT_SIZE = 10
local KILL_HINT_SIZE = 30
local CROSSHAIR_DISTANCE = 12
local HIT_HINT_DURATION = 0.25
local KILL_HINT_DURATION = 0.5
local DEBUG_MODE = false

if not CLIENT then return end

local HitHintTimer = 0
local KillHintTimer = 0
local IsHeadshot = false
local lastThinkTime = Timer.Time

local dbg
if not DEBUG_MODE then
    dbg = function() end
else
    dbg = function(...) print("[DeepHitMarker]", ...) end
end

local function IsOutOfScreen(position)
    local screen = Screen.Selected
    if screen == nil or screen.Cam == nil then return true end
    local view = screen.Cam.WorldView
    return position.X < view.X
        or position.X > view.Right
        or position.Y > view.Y
        or position.Y < view.Y - view.Height
end

local function IsDefaultAttackResult(result)
    return result.Damage == 0
        and result.Afflictions == nil
        and result.HitLimb == nil
        and result.AppliedDamageModifiers == nil
end

local function DrawHint(spriteBatch, position)
    if HitHintTimer <= 0 and KillHintTimer <= 0 then return end

    local baseColor = IsHeadshot and Color.Red or Color.White
    local hintAlpha = HitHintTimer > 0 and 255 or 0
    local hintColor = Color(baseColor.R, baseColor.G, baseColor.B, hintAlpha)
    local distance = CROSSHAIR_DISTANCE

    GUI.DrawLine(spriteBatch,
        Vector2(position.X + distance, position.Y + distance),
        Vector2(position.X + distance + HIT_HINT_SIZE, position.Y + distance + HIT_HINT_SIZE),
        hintColor, 0, 4)
    GUI.DrawLine(spriteBatch,
        Vector2(position.X - distance, position.Y + distance),
        Vector2(position.X - distance - HIT_HINT_SIZE, position.Y + distance + HIT_HINT_SIZE),
        hintColor, 0, 4)
    GUI.DrawLine(spriteBatch,
        Vector2(position.X + distance, position.Y - distance),
        Vector2(position.X + distance + HIT_HINT_SIZE, position.Y - distance - HIT_HINT_SIZE),
        hintColor, 0, 4)
    GUI.DrawLine(spriteBatch,
        Vector2(position.X - distance, position.Y - distance),
        Vector2(position.X - distance - HIT_HINT_SIZE, position.Y - distance - HIT_HINT_SIZE),
        hintColor, 0, 4)

    if KillHintTimer > 0 then
        local alpha = KillHintTimer / KILL_HINT_DURATION
        local killAlpha = alpha > 1.0 and 255 or math.floor(alpha * 255)
        local killColor = Color(255, 0, 0, killAlpha)
        GUI.DrawRectangle(spriteBatch,
            position, KILL_HINT_SIZE * 2, KILL_HINT_SIZE * 2,
            math.pi / 4, killColor, 0, 2)
    end
end

Hook.Patch("Barotrauma.Items.Components.RangedWeapon", "DrawHUD",
    { "Microsoft.Xna.Framework.Graphics.SpriteBatch", "Barotrauma.Character" },
    function(instance, ptable)
        local position = PlayerInput.MousePosition
        if position == nil then return end
        DrawHint(ptable["spriteBatch"], position)
    end,
    Hook.HookMethodType.After)

Hook.Patch("Barotrauma.Character", "ApplyAttack",
    { "Barotrauma.Character", "Microsoft.Xna.Framework.Vector2", "Barotrauma.Attack",
      "System.Single", "Microsoft.Xna.Framework.Vector2", "System.Boolean",
      "Barotrauma.Limb", "System.Single" },
    function(instance, ptable)
        local attacker = ptable["attacker"]
        if instance == nil or attacker == nil then return end

        local result = ptable.ReturnValue
        if IsDefaultAttackResult(result) then return end
        if attacker ~= Character.Controlled then return end
        if IsOutOfScreen(instance.WorldPosition) then return end

        HitHintTimer = HIT_HINT_DURATION
        if instance.IsDead then
            KillHintTimer = KILL_HINT_DURATION
        end

        IsHeadshot = false
        local hitLimb = result.HitLimb
        if hitLimb ~= nil and hitLimb.type == LimbType.Head then
            IsHeadshot = true
        end
    end,
    Hook.HookMethodType.After)

Hook.Add("think", "DeepHitMarkerUpdate", function()
    local now = Timer.Time
    local dt = now - lastThinkTime
    lastThinkTime = now
    if dt > 0.1 then dt = 0.1 end

    if HitHintTimer > 0 then
        HitHintTimer = HitHintTimer > dt and HitHintTimer - dt or 0
    end
    if KillHintTimer > 0 then
        KillHintTimer = KillHintTimer > dt and KillHintTimer - dt or 0
    end
end)