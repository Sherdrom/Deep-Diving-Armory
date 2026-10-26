-- ============================================================
-- SpinningBarrels.lua  手持加特林旋转枪管（纯客户端视觉）
-- ============================================================
-- 背景：SpinningBarrelSprite 是 Turret 组件专属元素，RangedWeapon
-- 不解析也不绘制该元素，因此无法通过 XML 直接给手持武器加旋转枪管。
--
-- 实现方式（移植客户端 Turret 的伪 3D 枪管算法）：
--   1. Hook.Patch Item.Draw（After，3 参重载）：对目标物品手动绘制
--      N 根枪管。绘制算法 1:1 移植自
--      ClientSource/Items/Components/Turret.cs L415-438
--      （圆周相位 SmoothStep 位移 + 黑灰明暗 + 前后半圈深度差）。
--   2. 手持态深度：复刻 ClientSource/Items/Item.cs L468-502 的
--      GetHeldItemDepth 局部函数（右上臂贴图深度 + AnimController
--      深度偏移 + 手部偏移 + 穿戴物与头部约束），并复刻 L451-466
--      的分支条件（body.Enabled / Wearable 激活 / back 参数 /
--      左右手槽位判定）。非手持态用 GetDrawDepth()。
--   3. Hook.Patch Item.Use（Before）：扣住扳机期间 Use 每帧被调用
--      （Character.cs tryUseItem L2528-2533），以此驱动枪管升速；
--      松开扳机后按减速度惯性降速。
--
-- 坐标约定（关键）：
--   - 手持物品经 PhysicsBody.Draw 渲染：屏幕位置 (DrawPos.X, -DrawPos.Y)，
--     屏幕旋转角 = -DrawRotation，body.Dir < 0 时水平镜像。
--     参考 RangedWeapon.Use L288（Dir=-1 时射向为 Rotation - Pi）。
--   - 枪管条 Sprite 竖直放置（旋转 0 时枪口朝屏幕上方），故条带旋转角
--     需在物品屏幕角基础上加 Pi/2（同 Turret 的 Rotation + PiOver2）。
--   - 伪 3D 位移方向始终取屏幕"上方"一侧（左右镜像不改变上下），
--     与 Turret 原版在未翻转时的表现一致。
--
-- 多人同步：纯客户端绘制，不产生网络事件，各客户端独立表现，
-- 物品 ID 在各客户端一致，无状态同步需求。
-- ============================================================

if not CLIENT then return end

-- ==================== 配置区 ====================

local ITEM_IDENTIFIER    = "deep_hs3000"  -- 目标物品 identifier
local BARREL_COUNT       = 6              -- 枪管数量

-- 枪管贴图：暂用原版 chaingun 的 Loaders.png 枪管条，后续可替换
local TEXTURE_PATH       = "Content/Items/Weapons/Loaders.png"
local SOURCE_RECT        = { 468, 0, 46, 296 }  -- 同 chaingun.xml SpinningBarrelSprite
local ORIGIN_RELATIVE    = { 0.1, 1.4 }         -- 同 chaingun.xml origin（相对值）

-- 枪管簇轴心：相对物品 Sprite 原点的像素偏移（物品贴图坐标系）
--   x: 贴图枪口方向为正；y: 图像向下为正。需按 deep_hs3000 贴图微调
local BARREL_PIVOT_X     = 40.0
local BARREL_PIVOT_Y     = -15.0

local SPIN_DISTANCE      = 45.0    -- 枪管伪 3D 摆动幅度（同 chaingun spinningbarreldistance，实际乘物品 Scale）
local BARREL_DEPTH_DELTA = 0.003   -- 枪管相对枪体最终绘制深度的偏移（正值浮于枪体之上）
local MAX_SPIN_SPEED     = 1800.0  -- 满转速（度/秒），1800 = 每秒 5 转
local SPIN_UP_ACCEL      = 2700.0  -- 升速加速度（度/秒^2），约 0.67 秒升满
local SPIN_DOWN_ACCEL    = 900.0   -- 松开扳机后的减速度（度/秒^2），2 秒停转
local TRIGGER_TIMEOUT    = 0.1     -- 判定"扣住扳机"的最大 Use 调用间隔（秒）
local DRAW_FRAME_CLAMP   = 0.1     -- 单帧相位推进上限（秒），防止卡顿跳变

local DEBUG_MODE         = false   -- 开启后输出加载诊断信息

-- ==================== 枚举表 ====================
-- 复刻 GetHeldItemDepth 需要的肢体与槽位枚举（CreateEnumTable 与
-- 类型注册无关，直接反射枚举值，不影响其他脚本的类型注册状态）

local LIMB = LuaUserData.CreateEnumTable("Barotrauma.LimbType")
local SLOT = LuaUserData.CreateEnumTable("Barotrauma.InvSlotType")

-- ==================== 内部状态 ====================
-- 按物品 ID 键控；roundEnd 时清空，避免跨回合残留

local spinPhase       = {}  -- 当前旋转相位（度，0-360）
local spinSpeed       = {}  -- 当前转速（度/秒）
local lastTriggerTime = {}  -- 最近一次扣扳机时刻（Timer.Time）
local lastDrawTime    = {}  -- 最近一次绘制时刻（用于计算帧间隔）
local componentCache  = {}  -- [id] = { holdable=..., wearable=... } 组件按物品缓存

local function WipeTable(t)
    for k in pairs(t) do t[k] = nil end
end

-- ==================== 枪管 Sprite ====================

local barrelSprite = Sprite(
    TEXTURE_PATH,
    Rectangle(SOURCE_RECT[1], SOURCE_RECT[2], SOURCE_RECT[3], SOURCE_RECT[4])
)
-- origin 属性为绝对像素：chaingun.xml 的 origin="0.1,1.4" 即相对值乘以源矩形尺寸
barrelSprite.Origin = Vector2(ORIGIN_RELATIVE[1] * SOURCE_RECT[3], ORIGIN_RELATIVE[2] * SOURCE_RECT[4])

-- ==================== 手持深度复刻 ====================
-- 1:1 复刻 Item.cs L468-502 GetHeldItemDepth（局部静态函数，无法直接调用）
-- 返回值语义同原版：条件不满足时返回传入的 fallbackDepth

local LIMB_DEPTH_OFFSET = 0.000001  -- Item.cs L472 常量

local function ComputeHeldDepth(picker, isRightHand, fallbackDepth)
    local anim = picker.AnimController
    if anim == nil then return fallbackDepth end

    local depthOffset = anim.GetDepthOffset()
    -- 用上臂做参考，保证枪绘制在整条手臂之前/之后（Item.cs L474-475）
    local holdLimb = anim.GetLimb(isRightHand and LIMB.RightArm or LIMB.LeftArm)
    if holdLimb == nil or holdLimb.ActiveSprite == nil then return fallbackDepth end

    -- 右手持枪略微靠后于右手，左手持枪略微靠前于左手（Item.cs L471, L478-481）
    local depth = holdLimb.ActiveSprite.Depth + depthOffset
        + LIMB_DEPTH_OFFSET * 2.0 * (isRightHand and 1.0 or -1.0)

    -- 手臂上的穿戴物深度约束（Item.cs L482-491）
    -- 注意：MoonSharp 将未注册的 List<WearableSprite> 自动转换为 Lua 表（1 基索引），
    -- 因此用 ipairs 迭代，不能访问 .Count（同 pairs(Item.ItemList) 的既有先例）
    local wearingItems = holdLimb.WearingItems
    if wearingItems ~= nil then
        for _, ws in ipairs(wearingItems) do
            if ws ~= nil and not ws.InheritLimbDepth and ws.Sprite ~= nil then
                if isRightHand then
                    local d = ws.Sprite.Depth + LIMB_DEPTH_OFFSET
                    if d > depth then depth = d end
                else
                    local d = ws.Sprite.Depth - LIMB_DEPTH_OFFSET
                    if d < depth then depth = d end
                end
            end
        end
    end

    -- 保证枪始终绘制在头部之前（Item.cs L492-500）
    local head = anim.GetLimb(LIMB.Head)
    if head ~= nil and head.Sprite ~= nil then
        if isRightHand then
            local d = head.Sprite.Depth + depthOffset - LIMB_DEPTH_OFFSET
            if d < depth then depth = d end
        else
            local d = head.Sprite.Depth + depthOffset + LIMB_DEPTH_OFFSET
            if d > depth then depth = d end
        end
    end

    return depth
end

-- ==================== 绘制 ====================

local HALF_PI = math.pi * 0.5

local function GetComponents(item, id)
    local cached = componentCache[id]
    if cached == nil then
        cached = {
            holdable = item.GetComponentString("Holdable"),
            wearable = item.GetComponentString("Wearable")
        }
        componentCache[id] = cached
    end
    return cached
end

local function DrawSpinningBarrels(item, spriteBatch, back)
    local id = item.ID
    local now = Timer.Time

    -- 1. 相位推进（帧间隔取自绘制节奏；Timer.Time 基于 Timing.TotalTime，
    --    游戏暂停时不走表，转速自然冻结）
    local lastT = lastDrawTime[id]
    local dt = 0.0
    if lastT ~= nil and now > lastT then
        dt = now - lastT
        if dt > DRAW_FRAME_CLAMP then dt = DRAW_FRAME_CLAMP end
    end
    lastDrawTime[id] = now

    local speed = spinSpeed[id] or 0.0
    local target = (now - (lastTriggerTime[id] or -1e9) < TRIGGER_TIMEOUT) and MAX_SPIN_SPEED or 0.0
    if speed < target then
        speed = math.min(target, speed + SPIN_UP_ACCEL * dt)
    elseif speed > target then
        speed = math.max(target, speed - SPIN_DOWN_ACCEL * dt)
    end
    spinSpeed[id] = speed

    local phase = spinPhase[id] or 0.0
    if speed > 0.0 then
        phase = (phase + speed * dt) % 360.0
        spinPhase[id] = phase
    end

    -- 2. 深度与朝向（复刻 Item.cs L395-451 的分支结构）
    local scale = item.Scale
    local baseDepth, baseColor, posX, posY, theta, flip
    local body = item.body
    local isHeld = false
    local isRightHand = false

    if body ~= nil then
        if not body.Enabled then return end  -- C# 动态分支条件（Item.cs L451）

        local comps = GetComponents(item, id)
        local holdable = comps.holdable
        local picker = holdable ~= nil and holdable.Picker or nil
        if picker ~= nil and picker.AnimController ~= nil then
            -- 作为穿戴物激活时不按手持绘制（Item.cs L457）
            if comps.wearable ~= nil and comps.wearable.IsActive then return end
            -- 手持物品在 back=false 批次不绘制（Item.cs L458）
            if not back then return end

            -- 左右手槽位判定（Item.cs L459-466）
            local inventory = picker.Inventory
            if inventory ~= nil then
                if inventory.GetItemInLimbSlot(SLOT.RightHand) == item then
                    isHeld = true
                    isRightHand = true
                elseif inventory.GetItemInLimbSlot(SLOT.LeftHand) == item then
                    isHeld = true
                end
            end

            if isHeld then
                baseDepth = ComputeHeldDepth(picker, isRightHand, item.GetDrawDepth())
            else
                baseDepth = item.GetDrawDepth()
            end
        else
            baseDepth = item.GetDrawDepth()
        end

        local drawPos = body.DrawPosition
        posX = drawPos.X
        posY = -drawPos.Y
        theta = body.DrawRotation
        flip = body.Dir < 0
    else
        -- 无物理体物品的静态回退：C# 静态分支以 +RotationRad 直接绘制（Item.cs L435）
        baseDepth = item.GetDrawDepth()
        local drawPos = item.DrawPosition
        posX = drawPos.X
        posY = -drawPos.Y
        theta = item.RotationRad
        flip = false
    end

    -- 颜色基准同 Turret 原版（Turret.cs L432：overrideColor ?? item.SpriteColor）
    baseColor = item.SpriteColor
    if baseColor == nil then return end

    -- 3. 枪管簇轴心（贴图偏移 -> 屏幕偏移）
    --    动态：屏幕角 = -theta，先水平镜像偏移再旋转（镜像在旋转前施加）
    --    静态：屏幕角 = +theta（与 C# 静态分支一致）
    local fx = flip and -1 or 1
    local pxs = fx * BARREL_PIVOT_X * scale
    local pys = BARREL_PIVOT_Y * scale
    local cosT = math.cos(theta)
    local sinT = math.sin(theta)
    local pivotX, pivotY
    local alphaDisp, alphaStrip
    if body ~= nil then
        pivotX = posX + pxs * cosT + pys * sinT
        pivotY = posY - pxs * sinT + pys * cosT
        alphaDisp = HALF_PI - theta
        -- 左右镜像只翻转前后，不改变圆周的上下侧，故位移角不随朝向取反；
        -- 条带旋转角需补 Pi（镜像后条带朝向反向，见 RangedWeapon.Use L288）
        alphaStrip = flip and (alphaDisp + math.pi) or alphaDisp
    else
        pivotX = posX + pxs * cosT - pys * sinT
        pivotY = posY + pxs * sinT + pys * cosT
        alphaDisp = HALF_PI + theta
        alphaStrip = alphaDisp
    end
    local cosA = math.cos(alphaDisp)
    local sinA = math.sin(alphaDisp)

    -- 4. 逐根绘制（算法移植 Turret.cs L417-438）
    local step = 360.0 / BARREL_COUNT
    for i = 0, BARREL_COUNT - 1 do
        local c = (i * step + phase) % 360.0

        -- 位移：离轴距离按 SmoothStep(|c-180|/180) 调制
        local t = math.abs(c - 180.0) / 180.0
        local mod = t * t * (3.0 - 2.0 * t)
        local d = mod * SPIN_DISTANCE * scale
        local drawX = pivotX - d * cosA
        local drawY = pivotY - d * sinA

        -- 深度：后半圈（180-360）贴枪体，前半圈（0-180）浮于其上
        local depth = baseDepth + BARREL_DEPTH_DELTA + (c > 180.0 and 0.0 or 0.001)

        -- 明暗：圆周相位偏移 90 度后映射到 黑->灰
        local bcp = c + 90.0
        if bcp >= 360.0 then bcp = bcp - 360.0 end
        local colorOffset = math.abs(bcp - 180.0) / 180.0

        -- 颜色：tint = Lerp(Black, Gray, colorOffset)；final = Lerp(枪体色, tint, 0.8)
        local tr = 128.0 * colorOffset
        local fr = baseColor.R * 0.2 + tr * 0.8
        local fg = baseColor.G * 0.2 + tr * 0.8
        local fb = baseColor.B * 0.2 + tr * 0.8
        local fa = baseColor.A * 0.2 + 255.0 * 0.8

        barrelSprite.Draw(spriteBatch,
            Vector2(drawX, drawY),
            Color(math.floor(fr + 0.5), math.floor(fg + 0.5), math.floor(fb + 0.5), math.floor(fa + 0.5)),
            alphaStrip,
            scale,
            0,
            depth)
    end
end

-- ==================== Hook 注册 ====================

-- 扳机检测：扣住射击键期间 Item.Use 每帧被调用（Character.cs L2528-2533
-- -> Item.cs L3371）。挂 Item.Use 而非 RangedWeapon.Use：物品定义可能
-- 使用裸 Projectile 等组件开火（无 RangedWeapon 时后者不在调用链上），
-- Item.Use 是所有开火路径的通用入口；签名
-- Use(float, Character, Limb, Entity, Character)，hints 必须完整匹配。
Hook.Patch(
    "Barotrauma.Item", "Use",
    { "System.Single", "Barotrauma.Character", "Barotrauma.Limb", "Barotrauma.Entity", "Barotrauma.Character" },
    function(instance, ptable)
        if instance.Prefab == nil or instance.Prefab.Identifier ~= ITEM_IDENTIFIER then return end
        if DEBUG_MODE and lastTriggerTime[instance.ID] == nil then
            print("[SpinningBarrels] trigger detected on item " .. tostring(instance.ID))
        end
        lastTriggerTime[instance.ID] = Timer.Time
    end,
    Hook.HookMethodType.Before
)

-- 枪管绘制：挂在 Item.Draw 的 3 参重载上（主世界 / 手持 / 高亮批次均经此路径；
-- 带显式 overrideColor 的特殊批次如阴影黑图经 4 参重载直接调用，天然被跳过）
Hook.Patch(
    "Barotrauma.Item", "Draw",
    { "Microsoft.Xna.Framework.Graphics.SpriteBatch", "System.Boolean", "System.Boolean" },
    function(instance, ptable)
        if instance.Prefab == nil or instance.Prefab.Identifier ~= ITEM_IDENTIFIER then return end
        DrawSpinningBarrels(instance, ptable["spriteBatch"], ptable["back"])
    end,
    Hook.HookMethodType.After
)

-- 回合结束清理状态，防止物品 ID 跨回合复用导致相位串扰
Hook.Add("roundEnd", "SpinningBarrels.Reset", function()
    WipeTable(spinPhase)
    WipeTable(spinSpeed)
    WipeTable(lastTriggerTime)
    WipeTable(lastDrawTime)
    WipeTable(componentCache)
end)

if DEBUG_MODE then
    print("[SpinningBarrels] loaded, item=" .. ITEM_IDENTIFIER .. ", barrels=" .. BARREL_COUNT)
end
