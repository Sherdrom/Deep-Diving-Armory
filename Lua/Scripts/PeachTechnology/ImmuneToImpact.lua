-- ImmuneToImpact.lua
-- 功能: 根据玩家身上的不同affliction减少对应比例的冲击力
-- 支持灵活配置：如 deep_immunetoimpact_90 表示减少90%冲击力
-- 原作者C#版本，转换为Lua版本以兼容LuaCsForBarotrauma

-- ==================== 调试开关 ====================
local DEBUG = false  -- 设置为 false 关闭调试信息

-- 调试输出函数
local function dbg(message)
    if DEBUG then
        print("[ImmuneToImpact-DEBUG] " .. tostring(message))
    end
end

-- ==================== 辅助函数 ====================

-- 从affliction名称解析减少百分比
-- 命名规则：deep_immunetoimpact_XX （XX = 减少的百分比，0-100）
-- 示例：deep_immunetoimpact_90 → 减少90%，保留10%
local function ParseReductionFromAfflictionName(afflictionIdentifier)
    -- 匹配模式：deep_immunetoimpact_数字
    local prefix = "deep_immunetoimpact_"
    
    if string.sub(afflictionIdentifier, 1, #prefix) ~= prefix then
        return nil
    end
    
    local numberStr = string.sub(afflictionIdentifier, #prefix + 1)
    local reductionPercent = tonumber(numberStr)
    
    if reductionPercent == nil or reductionPercent < 0 or reductionPercent > 100 then
        return nil
    end
    
    -- 转换为保留比例因子（100 - 减少百分比） / 100
    local retainFactor = (100 - reductionPercent) / 100
    
    return {
        reductionPercent = reductionPercent,  -- 减少的百分比（如90表示减少90%）
        retainFactor = retainFactor           -- 保留的因子（如0.1表示保留10%）
    }
end

-- 检查角色是否有指定affliction并返回强度
local function GetAfflictionStrength(character, identifier)
    if character == nil or character.CharacterHealth == nil then
        return 0
    end

    return character.CharacterHealth.GetAfflictionStrengthByIdentifier(identifier) or 0
end

-- 检查玩家身上所有 deep_immunetoimpact_* 类型的affliction
-- 返回最高优先级的配置（强度最高的那个）
local function FindActiveImpactReduction(character)
    local bestMatch = nil
    local bestStrength = 0
    
    -- 预定义的常见配置（用于快速匹配）
    local commonConfigs = {
        ["deep_immunetoimpact_0"] = { reductionPercent = 0, retainFactor = 1.0 },      -- 不减少
        ["deep_immunetoimpact_25"] = { reductionPercent = 25, retainFactor = 0.75 },   -- 减少25%
        ["deep_immunetoimpact_50"] = { reductionPercent = 50, retainFactor = 0.5 },     -- 减少50%
        ["deep_immunetoimpact_75"] = { reductionPercent = 75, retainFactor = 0.25 },    -- 减少75%
        ["deep_immunetoimpact_90"] = { reductionPercent = 90, retainFactor = 0.1 },     -- 减少90%
        ["deep_immunetoimpact_95"] = { reductionPercent = 95, retainFactor = 0.05 },    -- 减少95%
        ["deep_immunetoimpact_100"] = { reductionPercent = 100, retainFactor = 0.0 }    -- 完全免疫
    }
    
    -- 检查所有已知的配置
    for afflictionId, config in pairs(commonConfigs) do
        local strength = GetAfflictionStrength(character, afflictionId)
        
        if strength > 0.5 and strength > bestStrength then
            bestMatch = {
                afflictionId = afflictionId,
                config = config,
                strength = strength
            }
            bestStrength = strength
            
            dbg("FindActiveImpactReduction: 找到候选 - " .. afflictionId ..
                 " (减少" .. config.reductionPercent .. "%, 强度:" .. tostring(strength) .. ")")
        end
    end
    
    if bestMatch ~= nil then
        dbg("FindActiveImpactReduction: ✓ 最佳匹配 - " .. bestMatch.afflictionId ..
             " (减少" .. bestMatch.config.reductionPercent .. "%, 保留" ..
             (bestMatch.config.retainFactor * 100) .. "%)")
    else
        dbg("FindActiveImpactReduction: ✗ 未找到任何有效的冲击力减少affliction")
    end
    
    return bestMatch
end

-- 存储待恢复的原始值（key: attack对象地址, value: 原始值表）
local pendingRestorations = {}

-- ==================== 主逻辑 ====================

dbg("========== 开始注册 ImmuneToImpact ==========")
dbg("支持的affliction列表:")
dbg("  - deep_immunetoimpact_0   (不减少冲击力)")
dbg("  - deep_immunetoimpact_25  (减少25%冲击力)")
dbg("  - deep_immunetoimpact_50  (减少50%冲击力)")
dbg("  - deep_immunetoimpact_75  (减少75%冲击力)")
dbg("  - deep_immunetoimpact_90  (减少90%冲击力)")
dbg("  - deep_immunetoimpact_95  (减少95%冲击力)")
dbg("  - deep_immunetoimpact_100 (完全免疫冲击力)")

-- 使用 LuaUserData 让 Attack 类的私有属性可访问（类似 C# Harmony 的反射功能）
local attackDescriptor = LuaUserData.RegisterType("Barotrauma.Attack")
dbg("注册 Attack 类型: " .. tostring(attackDescriptor ~= nil))

LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetForce")
dbg("✓ TargetForce 属性已设为可访问")

LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetImpulse")
dbg("✓ TargetImpulse 属性已设为可访问")

LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetForceWorld")
dbg("✓ TargetForceWorld 属性已设为可访问")

LuaUserData.MakePropertyAccessible(attackDescriptor, "TargetImpulseWorld")
dbg("✓ TargetImpulseWorld 属性已设为可访问")

LuaUserData.MakePropertyAccessible(attackDescriptor, "ImpactMultiplier")
dbg("✓ ImpactMultiplier 属性已设为可访问")

Hook.Patch(
    "ImmuneToImpact_Before",
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
        dbg("--- [BEFORE] ApplyAttack 被触发 ---")

        if instance == nil then
            dbg("[BEFORE] 检查1失败: instance 为 nil")
            return
        end
        dbg("[BEFORE] 检查1通过: instance 存在 (名称: " .. tostring(instance.Name) .. ")")

        if not instance.IsPlayer then
            dbg("[BEFORE] 检查2失败: 不是玩家")
            return
        end
        dbg("[BEFORE] 检查2通过: 是玩家")

        -- 动态查找当前生效的冲击力减少配置
        local impactConfig = FindActiveImpactReduction(instance)
        
        if impactConfig == nil then
            dbg("[BEFORE] 检查3失败: 没有任何冲击力减少affliction")
            return
        end
        
        local activeAffliction = impactConfig.afflictionId
        local reductionFactor = impactConfig.config.retainFactor
        local reductionPercent = impactConfig.config.reductionPercent
        
        dbg("[BEFORE] 检查3通过: ✓ 生效配置 - " .. activeAffliction ..
             " (减少" .. reductionPercent .. "%, 因子×" .. tostring(reductionFactor) .. ")")

        local attack = ptable["attack"]
        if attack == nil then
            dbg("[BEFORE] 检查4失败: attack 对象为 nil")
            return
        end
        dbg("[BEFORE] 检查4通过: attack 对象存在")

        -- 保存原始值
        local originalValues = {
            TargetForce = attack.TargetForce,
            TargetImpulse = attack.TargetImpulse,
            TargetForceWorld = attack.TargetForceWorld,
            TargetImpulseWorld = attack.TargetImpulseWorld,
            ImpulseDirection = ptable["impulseDirection"],
            ReductionFactor = reductionFactor,
            AfflictionId = activeAffliction
        }

        local attackKey = tostring(attack)
        pendingRestorations[attackKey] = originalValues

        dbg("[BEFORE] 原始值 - TargetForce: " .. tostring(originalValues.TargetForce))
        dbg("[BEFORE] 原始值 - TargetImpulse: " .. tostring(originalValues.TargetImpulse))

        -- 应用减少
        attack.TargetForce = originalValues.TargetForce * reductionFactor
        attack.TargetImpulse = originalValues.TargetImpulse * reductionFactor
        attack.TargetForceWorld = originalValues.TargetForceWorld * reductionFactor
        attack.TargetImpulseWorld = originalValues.TargetImpulseWorld * reductionFactor

        if originalValues.ImpulseDirection ~= nil then
            ptable["impulseDirection"] = originalValues.ImpulseDirection * reductionFactor
        end

        dbg("[BEFORE] 修改后 - TargetForce: " .. tostring(attack.TargetForce) ..
             " (×" .. tostring(reductionFactor) .. ", 减少" .. reductionPercent .. "%)")
        dbg("[BEFORE] ✓ 冲击力已减少，等待 ApplyAttack 执行...")
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "ImmuneToImpact_After",
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
        local attack = ptable["attack"]
        if attack == nil then
            return
        end

        local attackKey = tostring(attack)
        local originalValues = pendingRestorations[attackKey]

        if originalValues ~= nil then
            attack.TargetForce = originalValues.TargetForce
            attack.TargetImpulse = originalValues.TargetImpulse
            attack.TargetForceWorld = originalValues.TargetForceWorld
            attack.TargetImpulseWorld = originalValues.TargetImpulseWorld

            if originalValues.ImpulseDirection ~= nil then
                ptable["impulseDirection"] = originalValues.ImpulseDirection
            end

            pendingRestorations[attackKey] = nil

            dbg("[AFTER] ✓ 已恢复原始值 - TargetForce: " .. tostring(originalValues.TargetForce))
            dbg("[AFTER] ✓ 配置来源: " .. tostring(originalValues.AfflictionId))
            dbg("[AFTER] ✓ Attack对象已还原，不影响后续使用")
        end
    end,
    Hook.HookMethodType.After
)

dbg("✓ Hook.Patch 注册成功！（Before + After）")
