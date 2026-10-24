--[[
    WearableContainerPatch.lua
    C# 插件 WearableContainerPatch.cs 的 Lua 移植版（客户端）。

    功能：带 deep_variable_sprite 标签的 Wearable 物品处于穿着状态（物理体存在但被禁用）时，
    原版 ItemContainer.Draw 会直接跳过内部物品绘制（ClientSource/ItemContainer.cs L470）。
    本脚本通过 After 钩子补画容器内物品，位置挂在穿戴者对应肢体上。

    与 C# 版的语义对齐点：
    - Harmony Postfix == Hook.HookMethodType.After：原方法提前 return 时 After 照常执行
    - containedItems(List<ContainedItem>) 的 Lua 封送不可靠（safe descriptor 下成员访问静默 nil），
      数量/遍历改走公开 API：ContainedItemCount + Inventory.GetItemAt；
      per-slot 微调(Hide/ItemPos/Rotation)经私有方法 FindContainableItem 恢复（返回已注册的 RelatedItem 公开类）
    - 私有字段 containedSpriteDepths(float[]) 经 MakeFieldAccessible 暴露（CLR 数组有内建 descriptor，封送可靠）
    - XNA Matrix.CreateRotationZ + Vector2.Transform 改为手写 2D 旋转（纯旋转矩阵，结果一致）
    - SpriteEffects 用整型值：None=0, FlipHorizontally=1, FlipVertically=2（位不相交，加法即按位或）
]]

if not CLIENT then return end

local DEBUG_MODE = false
local function dbg(...)
    if DEBUG_MODE then print("[WearableContainerPatch]", ...) end
end

local lastDiagTime = 0
local function diagBrokenSprite(containedItem, spriteBefore, spriteAfter)
    local now = os.clock()
    if now - lastDiagTime <= 2.0 then return end
    lastDiagTime = now
    local bs = containedItem.Prefab.BrokenSprites
    dbg("diag item:", containedItem.Name,
        "cond:", containedItem.Condition, "/", containedItem.MaxCondition,
        "fakeBroken:", containedItem.FakeBroken,
        "spriteChanged:", spriteBefore ~= spriteAfter,
        "spriteBefore:", spriteBefore ~= nil and spriteBefore.Name or "nil",
        "spriteAfter:", spriteAfter ~= nil and spriteAfter.Name or "nil",
        "brokenSprites:", bs ~= nil and bs.Count or "marshaling-nil",
        "container:", containedItem.Container ~= nil and containedItem.Container.Name or "nil")
end

-- ==================== 类型注册 ====================

-- ItemContainer 私有实例字段：containedSpriteDepths(float[])
-- 注意：不要用 containedItems(List<ContainedItem>)——其元素是未注册嵌套 struct，
-- 整个 List 经 safe descriptor 的成员访问（.Count/索引）全部静默返回 nil
-- （同 NoProjectileConsume v4.6 的 List 封送教训），数量与遍历一律走公开 API
local itemContainerDescriptor = LuaUserData.RegisterType("Barotrauma.Items.Components.ItemContainer")
LuaUserData.MakeFieldAccessible(itemContainerDescriptor, "containedSpriteDepths")
-- 私有方法：返回物品 XML <Containable tags="..." hide itempos> 的解析对象(RelatedItem，公开类已自动注册)。
-- ContainedItem(嵌套 struct) 的 Hide/ItemPos/Rotation 即来源于此（ItemContainer.cs L465-468 relatedItem?.X），
-- 故 per-slot 功能经此恢复，绕开封送不可靠的 containedItems 列表
LuaUserData.MakeMethodAccessible(itemContainerDescriptor, "FindContainableItem")

-- ==================== 常量 ====================

local TARGET_TAG = "deep_variable_sprite"

-- InvSlotType -> LimbType 映射（与 C# GetWearableLimb 的 switch 一致）。
-- 用枚举等值比较而非 table 键：MoonSharp 的枚举 userdata 作 table 键时走引用哈希，
-- 每次封送的新实例会查不到（verified 模式见 DeepHitmarker 的 limb.type == LimbType.Head）。
local function SlotToLimbType(slotType)
    if slotType == InvSlotType.Head then return LimbType.Head end
    if slotType == InvSlotType.InnerClothes or slotType == InvSlotType.OuterClothes then return LimbType.Torso end
    if slotType == InvSlotType.LeftHand then return LimbType.LeftHand end
    if slotType == InvSlotType.RightHand then return LimbType.RightHand end
    if slotType == InvSlotType.Bag then return LimbType.Torso end
    if slotType == InvSlotType.Card then return LimbType.Torso end
    if slotType == InvSlotType.HealthInterface then return LimbType.Torso end
    if slotType == InvSlotType.Headset then return LimbType.Torso end
    return LimbType.Head -- C# switch default
end

local SPRITE_EFFECT_FLIP_X = 1 -- SpriteEffects.FlipHorizontally
local SPRITE_EFFECT_FLIP_Y = 2 -- SpriteEffects.FlipVertically

-- ==================== 肢体解析（含缓存，等价 C# GetCachedLimb） ====================

local lastPickerId = -1
local lastItemId = -1
local cachedLimb = nil

local function GetWearableLimb(wearable, picker)
    local slots = wearable.AllowedSlots
    if slots == nil then return nil end

    -- List<InvSlotType> 封送：元素为已注册枚举，预期可用（同 AntiNetworkKick 的 List<Client> 模式）；
    -- 若 .Count/.索引 封送失败返回 nil，则 slots[0]=nil 落到 SlotToLimbType 的 Head 兜底，安全降级
    local count = slots.Count
    if count ~= nil and count == 0 then return nil end

    local limbType = SlotToLimbType(slots[0])

    local animController = picker.AnimController
    if animController == nil then return nil end

    return animController.GetLimb(limbType)
end

local function GetCachedLimb(item, picker, wearable)
    local pickerId = picker.ID
    local itemId = item.ID

    if lastPickerId == pickerId and lastItemId == itemId
        and cachedLimb ~= nil and not cachedLimb.Removed then
        return cachedLimb
    end

    cachedLimb = GetWearableLimb(wearable, picker)
    lastPickerId = pickerId
    lastItemId = itemId

    return cachedLimb
end

-- ==================== 绘制主体（等价 C# DrawContainedItemsForWearable） ====================

local function DrawContainedItemsForWearable(container, spriteBatch, itemDepth, picker, item, wearable)
    local limb = GetCachedLimb(item, picker, wearable)

    -- UpdateCachedTransform：肢体变换或回退到角色本体
    local basePosition, rotation, dir
    if limb ~= nil then
        basePosition = limb.DrawPosition
        rotation = limb.Rotation
        -- limb.Dir 是 float 属性（Limb.cs L516: dir==Direction.Left ? -1.0 : 1.0，恒为正负 1），
        -- 与 C# (int)limb.Dir == -1 等价的纯数值比较；Direction 枚举不在 LuaCs 默认注册表，
        -- 全局 Direction 为 nil（见 HumanAiFleeGrenade.lua L75 注释），不可用枚举比较
        dir = (limb.Dir == -1) and -1 or 1
    else
        basePosition = picker.DrawPosition
        rotation = 0.0
        dir = 1
    end

    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    -- XNA CreateRotationZ + Transform 的纯旋转结果：x' = x*cos - y*sin ; y' = x*sin + y*cos
    local function rotate(x, y)
        return x * cosR - y * sinR, x * sinR + y * cosR
    end

    local scale = item.Scale
    local containerItemPos = container.ItemPos
    local containerInterval = container.ItemInterval

    -- 变换后的基准位置与间隔（先缩放，再方向翻转，再旋转，最后平移到肢体位置）
    local posX = containerItemPos.X * scale
    local posY = containerItemPos.Y * scale
    local intervalHX, intervalHY = containerInterval.X * scale, 0.0
    local intervalVX, intervalVY = 0.0, containerInterval.Y * scale

    if dir == -1 then
        posX = -posX
        intervalHX = -intervalHX
    end

    posX, posY = rotate(posX, posY)
    intervalHX, intervalHY = rotate(intervalHX, intervalHY)
    intervalVX, intervalVY = rotate(intervalVX, intervalVY)

    posX = posX + basePosition.X
    posY = posY + basePosition.Y

    -- 翻转标记（RootContainer 优先，需 prefab 允许）
    local flippedX, flippedY = false, false
    local rootContainer = item.RootContainer
    if rootContainer ~= nil then
        flippedX = rootContainer.FlippedX and rootContainer.Prefab.CanSpriteFlipX
        flippedY = rootContainer.FlippedY and rootContainer.Prefab.CanSpriteFlipY
    else
        flippedX = item.FlippedX and item.Prefab.CanSpriteFlipX
        flippedY = item.FlippedY and item.Prefab.CanSpriteFlipY
    end

    -- 数量早退：公开 int 属性（ItemContainer.cs L247 ContainedItemCount），封送可靠
    local containedCount = container.ContainedItemCount
    if containedCount == nil or containedCount == 0 then return end

    -- 遍历：按槽位顺序扫（Inventory.GetItemAt，Inventory.cs L434，空槽返回 nil），
    -- itemIndex 为非空物品序号——C# 原版 containedItems 即"按槽位序压缩的非空物品列表"
    -- （ItemContainer.cs L478-488 按 Inventory.FindIndex 排序插入），序号语义一致
    local inventory = container.Inventory
    if inventory == nil then return end

    local capacity = inventory.Capacity
    if capacity == nil or capacity == 0 then return end

    local spriteDepths = container.containedSpriteDepths
    local spriteDepthsLen = 0
    if spriteDepths ~= nil then
        local len = spriteDepths.Length
        if len ~= nil then spriteDepthsLen = len end
    end

    local itemsPerRow = container.ItemsPerRow
    local useGridLayout = math.abs(containerInterval.X) > 0.001 and math.abs(containerInterval.Y) > 0.001
    local forcedDepth = container.ContainedSpriteDepth
    local itemSpriteDepth = (item.Sprite ~= nil) and item.Sprite.Depth or 0.0

    local itemIndex = 0
    for slotIndex = 0, capacity - 1 do
        local containedItem = inventory.GetItemAt(slotIndex)
        if containedItem ~= nil then
            -- 容器内物品 Visible=false，其 Item.Draw 每帧不执行，耐久/容器状态变化后无人重算 activeSprite，
            -- 导致 BrokenSprite 贴图不切换；绘制前手动触发引擎的状态重算（附着态->容器态->耐久态，
            -- Item.cs L189-233 SetActiveSpriteProjSpecific）， containedItem.Sprite 随之更新
            local spriteBefore = containedItem.Sprite
            containedItem.SetActiveSprite()
            if DEBUG_MODE then diagBrokenSprite(containedItem, spriteBefore, containedItem.Sprite) end

            -- C# for 循环的 i 对每条记录递增（含 Sprite 缺失/Hide 跳过者），序号语义保持一致
            local i = itemIndex
            itemIndex = itemIndex + 1

            if containedItem.Sprite ~= nil then
                -- per-slot 声明：物品 XML <Containable tags="..." hide itempos> 的解析对象
                local relatedItem = container.FindContainableItem(containedItem)
                local hidden = relatedItem ~= nil and relatedItem.Hide == true
                if not hidden then

                    -- 网格布局或线性排布（与 C# 分支一致，判断用未变换的 ItemInterval）
                    local itemPosX, itemPosY = posX, posY
                    if useGridLayout then
                        local h = i % itemsPerRow
                        local v = math.floor(i / itemsPerRow)
                        itemPosX = itemPosX + intervalHX * h + intervalVX * v
                        itemPosY = itemPosY + intervalHY * h + intervalVY * v
                    else
                        itemPosX = itemPosX + (intervalHX + intervalVX) * i
                        itemPosY = itemPosY + (intervalHY + intervalVY) * i
                    end

                    -- per-slot 位置覆盖（Vector2? 无值时封送为 nil）
                    local slotPos = relatedItem ~= nil and relatedItem.ItemPos or nil
                    if slotPos ~= nil and slotPos.X ~= nil then
                        local rx, ry = rotate(slotPos.X * dir, slotPos.Y)
                        itemPosX = rx + basePosition.X
                        itemPosY = ry + basePosition.Y
                    end

                    local sprite = containedItem.Sprite
                    local origin = sprite.Origin

                    -- 深度：容器强制深度 < per-slot 深度表 < 物品自身深度
                    local containedSpriteDepth = forcedDepth < 0.0 and sprite.Depth or forcedDepth
                    if i < spriteDepthsLen then
                        local d = spriteDepths[i]
                        if d ~= nil then containedSpriteDepth = d end
                    end

                    local finalDepth
                    if forcedDepth >= 0.0 or spriteDepthsLen > 0 then
                        finalDepth = itemDepth + (containedSpriteDepth - itemSpriteDepth) / 10000.0
                    else
                        -- 穿着态：以肢体活动贴图深度为基准（与 C# 回退链一致）
                        local wearableSpriteDepth
                        if limb ~= nil then
                            if limb.ActiveSprite ~= nil then
                                wearableSpriteDepth = limb.ActiveSprite.Depth
                            else
                                wearableSpriteDepth = limb.DrawPosition.Y * 0.0001
                            end
                        else
                            wearableSpriteDepth = picker.DrawPosition.Y * 0.0001
                        end
                        local fallbackItemDepth = (item.Sprite ~= nil) and item.Sprite.Depth or 0.5
                        finalDepth = wearableSpriteDepth + (sprite.Depth - fallbackItemDepth)
                    end

                    -- 旋转与翻转（per-slot Rotation 来自 relatedItem）
                    local spriteRotation = container.ItemRotation
                    if relatedItem ~= nil and relatedItem.Rotation ~= 0 then
                        spriteRotation = relatedItem.Rotation
                    end

                    local spriteEffects = 0
                    if dir == -1 or flippedX then spriteEffects = spriteEffects + SPRITE_EFFECT_FLIP_X end
                    if flippedY then spriteEffects = spriteEffects + SPRITE_EFFECT_FLIP_Y end

                    -- 签名 GetSpriteColor(Color? defaultColor=null, bool withHighlight=false)（Client Item.cs L138），
                    -- C# 的命名参数 withHighlight:true 在 Lua 中需补齐首参：nil -> Color? null
                    local color = containedItem.GetSpriteColor(nil, true)

                    sprite.Draw(spriteBatch,
                        Vector2(itemPosX, -itemPosY),
                        color,
                        origin,
                        -rotation,
                        containedItem.Scale,
                        spriteEffects,
                        finalDepth)
                end
            end
        end
    end

    dbg("drawn containers for", item.Name, "count", containedCount)
end

-- ==================== Hook 注册 ====================

-- ItemContainer.Draw 唯一签名 (SpriteBatch, bool, float, Color?)，名称解析无重载冲突；
-- 原版对 body 禁用的穿戴物在方法开头提前 return，After 钩子照常执行（Harmony Postfix 语义），
-- 这正是本补丁能在穿着态生效的前提。
Hook.Patch("Barotrauma.Items.Components.ItemContainer", "Draw",
    function(instance, ptable)
        local spriteBatch = ptable["spriteBatch"]
        if spriteBatch == nil then return end

        local item = instance.item
        if item == nil then return end

        local wearable = item.GetComponentString("Wearable")
        if wearable == nil or not wearable.IsActive then return end

        -- 仅穿着态（物理体存在且被禁用）触发，手持/放置态交给原版绘制
        local body = item.body
        if body == nil or body.Enabled then return end

        if not item.HasTag(TARGET_TAG) then return end

        local picker = wearable.Picker
        if picker == nil or picker.Removed then return end

        DrawContainedItemsForWearable(instance, spriteBatch, ptable["itemDepth"], picker, item, wearable)
    end,
    Hook.HookMethodType.After)

print("[WearableContainerPatch] OK!")
