--[[
    ChipBodyshotPenetration.lua
    碎甲芯片(chip_bodyshot)位于枪械物品栏内时, 该枪械造成的伤害穿透 +0.1(=1 级穿甲);
    拿出芯片立即失效(逐击计算, 无持久状态)。
    实现: Hook Character.ApplyAttack(Before), 从 attack.SourceItem 定位发射源枪械,
    校验芯片存在后经 ptable 注入穿透加成(与 armorMain.lua 的 Single() ptable 写法同一机制)。
    基准穿透由物品 XML 的 penetration 属性经游戏自身反序列化加载(如 mk22 的 0.1),
    Lua 不写组件属性, 天然不受任何 setvalue 影响。
    (反编译源码依据: Attack.DoDamageToLimb L732-739 在伤害时读取
     Launcher.GetComponent<RangedWeapon>().Penetration 并叠加进 ApplyAttack 的 penetration 参数)
]]

local MOD_NAME = "ChipBodyshotPenetration"
local CHIP_IDENTIFIER = "chip_bodyshot"
local GUNSMITH_TAG = "gunsmith"
local PENETRATION_BONUS = 0.1
local DEBUG = false

local function log(message)
    print("[" .. MOD_NAME .. "] " .. message)
end

local function logDebug(message)
    if DEBUG then log(message) end
end

-- 遍历枪械自身物品栏(含芯片槽), 判定是否装有碎甲芯片; 多枚按 1 枚计
local function containsChip(item)
    local inventory = item.OwnInventory
    local contained = inventory and inventory.AllItems or item.ContainedItems
    if contained == nil then return false end
    for containedItem in contained do
        if containedItem ~= nil and not containedItem.Removed
            and tostring(containedItem.Prefab.Identifier) == CHIP_IDENTIFIER then
            return true
        end
    end
    return false
end

-- 定位攻击来源对应的枪械物品: 弹丸取 Launcher, 直射类攻击取来源物品自身
local function findSourceGun(source)
    if source == nil or source.Removed then return nil end
    local projectile = source.GetComponentString("Projectile")
    local launcher = projectile and projectile.Launcher
    if launcher ~= nil and not launcher.Removed then
        return launcher
    end
    if source.GetComponentString("SwitchableRangedWeapon") ~= nil
        or source.GetComponentString("RangedWeapon") ~= nil then
        return source
    end
    return nil
end

-- ApplyAttack(Before): 命中来源为装有碎甲芯片的枪械时, 注入 +0.1 穿透
-- 仅对带 gunsmith 标签的枪械生效
local function onApplyAttack(character, ptable)
    local attack = ptable["attack"]
    if attack == nil then return end
    local gunItem = findSourceGun(attack.SourceItem)
    if gunItem == nil then return end
    if not gunItem.HasTag(GUNSMITH_TAG) then return end
    if not containsChip(gunItem) then return end
    local penetration = ptable["penetration"]
    if type(penetration) ~= "number" then return end
    ptable["penetration"] = Single(penetration + PENETRATION_BONUS)
    logDebug("Chip bonus applied: " .. tostring(gunItem.Prefab.Identifier)
        .. " penetration=" .. string.format("%.4f", penetration + PENETRATION_BONUS))
end

Hook.Patch(
    MOD_NAME,
    "Barotrauma.Character",
    "ApplyAttack",
    onApplyAttack,
    Hook.HookMethodType.Before
)

log("Initialized | chip=" .. CHIP_IDENTIFIER .. " bonus=" .. PENETRATION_BONUS)
