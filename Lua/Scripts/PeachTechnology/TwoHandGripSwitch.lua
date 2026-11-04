-- TwoHandGripSwitch.lua
-- 按一个可配置按键, 在 双手握持 -> 右手单持 -> 左手单持 -> 双手 之间循环切换
-- 适用于 slots="Any,RightHand+LeftHand" 配置的枪械 (原版与 mod 通用, 无需白名单)
--
-- 原理 (基于游戏源码验证):
--   Barotrauma 的"双手握持"= 物品同时注册在专用右手槽位与左手槽位
--   (CharacterInventory.TryPutItem L507-521 拾取时向两个手部槽位双写),
--   AnimController.HoldItem (L621-636) 每帧按 IsInLimbSlot 逐手执行 HandIK,
--   因此仅调整库存槽位注册即可切换握持姿态, 无需任何动画补丁。
--
-- 多人同步:
--   客户端仅发送空请求 (不含 itemId, 服务端自行解析请求者角色, 杜绝伪造),
--   专用服务端权威执行槽位变更, 经 Inventory.PutItem 的 createNetworkEvent
--   自动同步全端, 姿态由各端本地每帧计算自然跟随。
--   服务端 EnsureItemsInBothHands (BarotraumaServer ServerSource Inventory.cs L271)
--   会在库存对账时把单手持有的双手武器强制还原回双手, 此处以 Before 补丁按
--   "该角色手部存在单持武器"精确跳过; 双手态与空手时仍走原版逻辑。
--   该方法仅存在于专用服务端构建 (客户端托管 = 独立 DedicatedServer.exe 进程),
--   单人与客户端构建无此方法, 不需要补丁。
--
-- 单人: 客户端本地直接执行。
--
-- 姿态记忆与装备互斥保护:
--   每件武器通过弱键表记住最后切换的握持姿态 (会话级, 物品移除自动失效)。
--   装备一件曾被按 G 切为单持的武器时, 自动恢复其记忆姿态;
--   装备双手武器而另一手已有武器时, 原版会把占位武器挤回背包
--   (CharacterInventory.TryPutItem L492 递归挪槽), 导致第一把被卸下。
--   此处以 Inventory.PutItem Before 记录"手槽武器被移出", 并在
--   Item.Equip Before (双手武器装备完成点) 修复布局: 新武器压缩为
--   空闲手单持, 被挤武器回填原手, 实现双枪各自单持共存。
--   双手武器判定用"双槽注册"行为特征 (IsInLimbSlot 双查), 规避
--   AllowedSlots 枚举集合在 Lua 侧的算术/比较限制。
--   TryPutItem 的参数含 IEnumerable 接口类型, LuaCs 类型解析默认拒绝
--   接口 (PluginManagementService.cs L369), 故不能直接补 TryPutItem。
--
-- 部署: 放入 mod 的 Lua/Autorun/ 目录即可 (LuaCs Legacy 自动加载)。
-- 测试: 将下方 DEBUG 改为 true 可在控制台输出纯文本诊断日志。

local MOD_ID = "TwoHandGripSwitch"
local DEBUG = false
local NET_ID = "TwoHandGripSwitch"
-- 按键名, 可改为任意 Microsoft.Xna.Framework.Input.Keys 成员 (如 "B", "H", "K")
local CONFIG_KEY_NAME = "G"

local MODE_TWOHAND = 0
local MODE_RIGHT = 1
local MODE_LEFT = 2

local function Log(message)
    if DEBUG then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

-- 暴露 protected Inventory.PutItem (Inventory.cs L645)
-- character.Inventory 运行时类型是子类 CharacterInventory, MoonSharp 按运行时类型
-- 描述符解析成员, 必须对子类描述符暴露 (FindMethodRecursively 沿基类链找到
-- Inventory 的 protected PutItem 并注册到 CharacterInventory 描述符)
-- removeItem=false 时保留物品在其他槽位的注册, 且 createNetworkEvent 携带库存同步事件
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.CharacterInventory"], "PutItem")

-- 物品级姿态记忆 (弱键表: 物品被回收后条目自动失效, 零清理成本)
local gripMemory = setmetatable({}, {__mode = "k"})

-- 刚被双手武器装备挤回背包的武器记录 (单次消费, 时间窗防误伤主动卸下场景)
local evicted = nil

-- 恢复手持物品的 body 状态:
--   Inventory.PutItem (L684-686) 会禁用物品 body, 而 Holdable.Update (L1133)
--   首行检查 body.Enabled, 禁用即直接 return, 姿态/贴图驱动全部停摆
--   (角度冻结、无 HandIK、无 SetTransform, 表现为枪不可见且无法瞄准)
--   原版拾取路径由 Holdable.Equip (L594-595) 恢复: Enabled=true, PhysEnabled=false;
--   本脚本绕过拾取流程, 需手动对齐。body 字段为 public, Lua 可直接访问。
local function RestoreHeldItemBody(item)
    local body = item.body
    if body ~= nil then
        body.Enabled = true
        body.PhysEnabled = false
    end
end

-- 按实时槽位拓扑切换握持, 无本地状态表: 物品掉落/易主后自然失效, 零清理成本
-- 返回新姿态编码, 无法切换时返回 nil
local function ApplyGripSwitch(character)
    if character == nil or character.Removed or character.IsDead then return nil end
    local inventory = character.Inventory
    if inventory == nil then return nil end

    local rightIdx = inventory:FindLimbSlot(InvSlotType.RightHand)
    local leftIdx = inventory:FindLimbSlot(InvSlotType.LeftHand)
    if rightIdx < 0 or leftIdx < 0 then return nil end

    local rightItem = inventory:GetItemAt(rightIdx)
    local leftItem = inventory:GetItemAt(leftIdx)

    if rightItem == nil and leftItem == nil then
        Log("no item in hand slots, ignored")
        return nil
    end

    if rightItem ~= nil and leftItem ~= nil and rightItem.ID == leftItem.ID then
        -- 双手态 (双槽注册同一武器): 移出后仅回写右手 -> 右手单持
        inventory:RemoveItem(rightItem)
        inventory:PutItem(rightItem, rightIdx, character, false, true)
        RestoreHeldItemBody(rightItem)
        gripMemory[rightItem] = MODE_RIGHT
        Log("two-handed -> right hand: " .. tostring(rightItem.Name))
        return MODE_RIGHT
    end

    if rightItem ~= nil and leftItem == nil then
        -- 右手单持: 移出后仅回写左手 -> 左手单持
        inventory:RemoveItem(rightItem)
        inventory:PutItem(rightItem, leftIdx, character, false, true)
        RestoreHeldItemBody(rightItem)
        gripMemory[rightItem] = MODE_LEFT
        Log("right hand -> left hand: " .. tostring(rightItem.Name))
        return MODE_LEFT
    end

    if leftItem ~= nil and rightItem == nil then
        -- 左手单持: 补右手注册 (保留左手) -> 双手握持
        inventory:PutItem(leftItem, rightIdx, character, false, true)
        RestoreHeldItemBody(leftItem)
        gripMemory[leftItem] = nil
        Log("left hand -> two-handed: " .. tostring(leftItem.Name))
        return MODE_TWOHAND
    end

    -- 两手各持不同物品: 无双手武器在场, 不动作
    Log("different items in both hands, ignored")
    return nil
end

-- 记录"手槽武器被移出"事件 (PutItem 是 TryPutItem 完成实际写入的咽喉点,
-- CharacterInventory.TryPutItem L492 把占位武器挪回背包时经此调用):
-- 门控链全部前置, 非角色库存与非移出操作在首两行退出, 常规容器操作零额外开销
Hook.Patch(MOD_ID, "Barotrauma.Inventory", "PutItem",
    { "Barotrauma.Item", "System.Int32", "Barotrauma.Character", "System.Boolean", "System.Boolean", "System.Boolean" },
    function(instance, ptable)
        local item = ptable["item"]
        if item == nil or ptable["removeItem"] ~= true then return end
        local owner = instance.Owner
        if owner == nil or not LuaUserData.IsTargetType(owner, "Barotrauma.Character") then return end
        if not instance:IsInLimbSlot(item, InvSlotType.RightHand)
            and not instance:IsInLimbSlot(item, InvSlotType.LeftHand) then
            return
        end
        evicted = { item = item, inventory = instance, clock = os.clock() }
        Log("hand weapon evicted to bag: " .. tostring(item.Name))
    end, Hook.HookMethodType.Before)

-- 双手武器装备完成点修复 (Item.Equip 由 TryPutItem L518 在槽位写入后调用):
--   此时新武器已双槽注册、被挤武器已在背包, 在组件装备流程前重排布局,
--   随后的原版组件 Equip 会按重排后的槽位完成 picker/body 装备态
Hook.Patch(MOD_ID, "Barotrauma.Item", "Equip", { "Barotrauma.Character" }, function(instance, ptable)
    local item = instance
    local character = ptable["character"]
    if character == nil or character.Removed or character.IsDead then return end
    local inventory = character.Inventory
    if inventory == nil then return end

    -- 双持态判定: 双槽注册同一物品 (仅双手武器装备完成会出现该拓扑)
    if not inventory:IsInLimbSlot(item, InvSlotType.RightHand)
        or not inventory:IsInLimbSlot(item, InvSlotType.LeftHand) then
        return
    end

    local memory = gripMemory[item]
    local ev = evicted
    local rightIdx = inventory:FindLimbSlot(InvSlotType.RightHand)
    local leftIdx = inventory:FindLimbSlot(InvSlotType.LeftHand)
    if rightIdx < 0 or leftIdx < 0 then return end

    -- 校验挤出记录: 同一库存 + 时间窗内 + 该武器确实被挪出双手且还在本库存
    local hasEv = false
    local evItem = nil
    if ev ~= nil and ev.inventory == inventory and os.clock() - ev.clock <= 0.5 then
        local candidate = ev.item
        if candidate ~= nil and not candidate.Removed
            and candidate.ParentInventory ~= nil
            and not inventory:IsInLimbSlot(candidate, InvSlotType.RightHand)
            and not inventory:IsInLimbSlot(candidate, InvSlotType.LeftHand) then
            hasEv = true
            evItem = candidate
        end
    end

    if memory == nil and not hasEv then return end
    evicted = nil

    -- 目标手选择: 记忆姿态优先, 否则默认新武器走左手、被挤武器回填右手
    -- (双手武器装备冲突场景: 被挤武器原本在右手, 故回填右手)
    local targetIdx, keepMode, otherIdx
    if memory == MODE_RIGHT then
        targetIdx, keepMode = rightIdx, MODE_RIGHT
    elseif memory == MODE_LEFT then
        targetIdx, keepMode = leftIdx, MODE_LEFT
    elseif hasEv then
        targetIdx, keepMode = leftIdx, MODE_LEFT
    else
        targetIdx, keepMode = rightIdx, MODE_RIGHT
    end
    otherIdx = (targetIdx == rightIdx) and leftIdx or rightIdx

    -- 重排: 新武器压缩为单持 (物品仍在装备流程内, 原版组件 Equip 紧随其后
    -- 完成 picker/body 装备态, 无需手动恢复 body)
    inventory:RemoveItem(item)
    inventory:PutItem(item, targetIdx, character, false, true)
    gripMemory[item] = keepMode
    Log("equipped weapon compressed to single hand: " .. tostring(item.Name))

    -- 被挤武器回填另一手: 调用 Item.Equip 走完整组件装备链
    -- (恢复 Holdable.Picker 与 body; 该调用重入本补丁时因非双持态直接退出)
    if hasEv then
        inventory:RemoveItem(evItem)
        inventory:PutItem(evItem, otherIdx, character, false, true)
        evItem:Equip(character)
        gripMemory[evItem] = (otherIdx == rightIdx) and MODE_RIGHT or MODE_LEFT
        Log("evicted weapon restored to hand: " .. tostring(evItem.Name))
    end
end, Hook.HookMethodType.Before)

if SERVER then
    Networking.Receive(NET_ID, function(message, client)
        if client == nil then return end
        local mode = ApplyGripSwitch(client.Character)
        if mode == nil then return end
        local reply = Networking.Start(NET_ID)
        reply.WriteByte(mode)
        Networking.Send(reply, client.Connection)
    end)

    -- 跳过服务端对账时的双手强制还原 (ServerSource Inventory.cs L271):
    --   原版双手态 (两槽同一物品) 与空手 -> 放行原版逻辑, 非本功能行为与原版一致
    --   单持武器或两手各持不同物品 -> 本脚本的切换态, 跳过还原
    -- 副作用说明: 未使用本功能的玩家若因原版交换逻辑边界产生单手持双手武器,
    --   也不再被强制还原, 但该状态本就是合法库存布局, 无功能影响
    Hook.Patch(MOD_ID, "Barotrauma.Inventory", "EnsureItemsInBothHands", { "Barotrauma.Character" }, function(instance, ptable)
        local inventory = instance
        local rightIdx = inventory:FindLimbSlot(InvSlotType.RightHand)
        local leftIdx = inventory:FindLimbSlot(InvSlotType.LeftHand)
        if rightIdx < 0 or leftIdx < 0 then return end

        local rightItem = inventory:GetItemAt(rightIdx)
        local leftItem = inventory:GetItemAt(leftIdx)
        if rightItem == nil and leftItem == nil then return end
        if rightItem ~= nil and leftItem ~= nil and rightItem.ID == leftItem.ID then return end

        ptable.PreventExecution = true
    end, Hook.HookMethodType.Before)
end

if CLIENT then
    local CONFIG_KEY = Keys[CONFIG_KEY_NAME]
    if CONFIG_KEY == nil then
        print("[" .. MOD_ID .. "] invalid key name: " .. CONFIG_KEY_NAME)
        return
    end

    local MODE_TEXT = {
        [MODE_TWOHAND] = "TwoHanded",
        [MODE_RIGHT] = "RightHand",
        [MODE_LEFT] = "LeftHand"
    }

    local function ShowGripMessage(mode)
        GUI.AddMessage("Grip: " .. (MODE_TEXT[mode] or "Unknown"), Color.White)
    end

    -- 每帧轮询按键 (同款先例: zoom.lua 的 ControlLocalPlayer After 补丁)
    Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
        if not PlayerInput.KeyHit(CONFIG_KEY) then return end
        -- 聊天/控制台等文本输入聚焦时不触发
        if GUI.KeyboardDispatcher ~= nil and GUI.KeyboardDispatcher.Subscriber ~= nil then return end

        local character = Character.Controlled
        if character == nil or character.Removed or character.IsDead then return end

        if Game.IsMultiplayer then
            -- 空消息体请求, 服务端权威执行
            Networking.Send(Networking.Start(NET_ID))
            return
        end

        local mode = ApplyGripSwitch(character)
        if mode ~= nil then
            ShowGripMessage(mode)
        end
    end, Hook.HookMethodType.After)

    -- 服务端回执 -> HUD 提示
    Networking.Receive(NET_ID, function(message)
        ShowGripMessage(message.ReadByte())
    end)
end
