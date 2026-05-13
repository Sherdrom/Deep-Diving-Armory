-- NoFriendlyDamage.lua (Improved Version)
-- 功能: 根据玩家身上的affliction控制对同阵营目标的伤害
-- 支持多级友军伤害控制：完全免疫 / 大幅减少 / 轻微减少 等
-- 原版优化 + 借鉴 ImmuneToImpact 的设计模式

-- ==================== 配置区域 ====================
local CONFIG = {
    DEBUG = false,                    -- 调试开关
    
    -- 友军伤害控制的 affliction 配置列表
    -- 格式: [affliction名称] = { damageMultiplier, description }
    AFFLICTION_CONFIGS = {
        ["friendly_fire"] = {
            multiplier = 0.0,         -- 完全免疫友军伤害
            desc = "完全免疫"
        },
        ["deep_noff_reduce95"] = {
            multiplier = 0.05,        -- 减少95%友军伤害
            desc = "大幅减少"
        },
        ["deep_noff_reduce75"] = {
            multiplier = 0.25,        -- 减少75%友军伤害
            desc = "中等减少"
        },
        ["deep_noff_reduce50"] = {
            multiplier = 0.5,         -- 减少50%友军伤害
            desc = "半减"
        }
    },
    
    -- 数据有效期（秒）
    MARKER_EXPIRY_TIME = 2.0,        -- 零伤害标记的有效时间
    
    -- 清理间隔（秒）
    CLEANUP_INTERVAL = 5.0           -- 定时清理间隔
}

-- ==================== 模块定义 ====================
local NoFriendlyDamage = {
    -- 运行时状态
    pendingDamages = {},             -- 待处理的伤害修改 { [characterId] = { time, multiplier } }
    lastCleanupTime = 0,             -- 上次清理时间
    
    -- 统计信息（用于调试和监控）
    stats = {
        totalChecks = 0,
        appliedModifications = 0,
        skippedAttacks = 0
    }
}

-- ==================== 工具函数 ====================

-- 调试输出（带条件判断和前缀）
local function dbg(message)
    if CONFIG.DEBUG then
        print("[NFD-DEBUG] " .. tostring(message))
    end
end

-- 判断两个角色是否同队
function NoFriendlyDamage.IsSameTeam(char1, char2)
    if char1 == nil or char2 == nil then return false end
    return (char1.TeamID == char2.TeamID) and (char1.TeamID >= 0)
end
local function GetAfflictionStrength(character, identifier)
    if character == nil or character.CharacterHealth == nil then
        return 0
    end
    
    local strength = character.CharacterHealth.GetAfflictionStrengthByIdentifier(identifier)
    return strength or 0
end

-- 查找当前生效的最高优先级友伤控制配置
function NoFriendlyDamage.FindBestConfig(attacker)
    local bestConfig = nil
    local bestStrength = 0
    
    for affId, config in pairs(CONFIG.AFFLICTION_CONFIGS) do
        local strength = GetAfflictionStrength(attacker, affId)
        
        if strength > 0.5 and strength > bestStrength then
            bestConfig = {
                afflictionId = affId,
                multiplier = config.multiplier,
                desc = config.desc,
                strength = strength
            }
            bestStrength = strength
            
            dbg("找到候选: " .. affId .. " (" .. config.desc .. ", 强度:" .. 
                string.format("%.1f", strength) .. ")")
        end
    end
    
    return bestConfig
end

-- 安全地设置零/减少伤害
local function ApplyDamageModification(attackResult, multiplier)
    if attackResult == nil or attackResult.Afflictions == nil then
        return false
    end
    
    local modifiedCount = 0
    for _, affliction in ipairs(attackResult.Afflictions) do
        if affliction ~= nil then
            local original = affliction.Strength
            affliction.Strength = original * multiplier
            modifiedCount = modifiedCount + 1
            
            dbg(string.format("  修改: %s %.1f → %.1f (×%.2f)", 
                tostring(affliction.Prefab.Identifier), 
                original, affliction.Strength, multiplier))
        end
    end
    
    return modifiedCount > 0
end

-- ==================== 核心逻辑 ====================

-- 阶段1: 监听伤害事件，判断是否需要修改伤害
Hook.Add("character.damageLimb", "NFD.OnDamageLimb", function(
    character, worldPosition, hitLimb, afflictions, stun, 
    playSound, attackImpulse, attacker, damageMultiplier, 
    allowStacking, penetration, shouldImplode)
    
    NoFriendlyDamage.stats.totalChecks = NoFriendlyDamage.stats.totalChecks + 1
    
    -- 快速检查：攻击者或目标为空
    if attacker == nil or character == nil then
        return nil
    end
    
    -- 只处理玩家攻击者（可选优化：根据需要调整）
    if not attacker.IsHuman then
        return nil
    end
    
    -- 查找生效的友伤控制配置
    local ffdConfig = NoFriendlyDamage.FindBestConfig(attacker)
    
    if ffdConfig == nil then
        NoFriendlyDamage.stats.skippedAttacks = NoFriendlyDamage.stats.skippedAttacks + 1
        return nil
    end
    
    -- 检查队伍关系
    if not NoFriendlyDamage.IsSameTeam(attacker, character) then
        NoFriendlyDamage.stats.skippedAttacks = NoFriendlyDamage.stats.skippedAttacks + 1
        dbg("跳过: 不同队 - " .. tostring(attacker.Name) .. " → " .. tostring(character.Name))
        return nil
    end
    
    -- 设置伤害修改标记
    local charId = tostring(character.ID or "unknown")
    local currentTime = Timer.GetTime()  -- 使用高精度计时器
    
    NoFriendlyDamage.pendingDamages[charId] = {
        time = currentTime,
        multiplier = ffdConfig.multiplier,
        sourceAffliction = ffdConfig.afflictionId,
        sourceDesc = ffdConfig.desc
    }
    
    dbg(string.format("✓ 标记待处理: %s → %s (%s, ×%.2f)", 
        tostring(attacker.Name), tostring(character.Name),
        ffdConfig.desc, ffdConfig.multiplier))
    
    return nil
end)

-- 阶段2: Patch ApplyDamage 方法来实际应用伤害修改
Hook.Patch(
    "NFD_ApplyDamage",
    "Barotrauma.CharacterHealth",
    "ApplyDamage",
    function(instance, ptable)
        local attackResult = ptable["attackResult"]
        local character = instance.Character
        
        if attackResult == nil or character == nil then
            return
        end
        
        local charId = tostring(character.ID or "unknown")
        local pendingData = NoFriendlyDamage.pendingDamages[charId]
        
        if pendingData == nil then
            return
        end
        
        -- 时间有效性检查
        local currentTime = Timer.GetTime()
        if currentTime - pendingData.time > CONFIG.MARKER_EXPIRY_TIME then
            NoFriendlyDamage.pendingDamages[charId] = nil
            dbg("⏰ 标记已过期: " .. charId)
            return
        end
        
        -- 应用伤害修改
        dbg(string.format("🎯 应用伤害修改: %s (%s, ×%.2f)",
            tostring(character.Name), pendingData.sourceDesc, pendingData.multiplier))
        
        local success = ApplyDamageModification(attackResult, pendingData.multiplier)
        
        if success then
            NoFriendlyDamage.stats.appliedModifications = NoFriendlyDamage.stats.appliedModifications + 1
            dbg("✅ 修改成功!")
        else
            dbg("❌ 修改失败或无 afflictions")
        end
        
        -- 清除标记（一次性使用）
        NoFriendlyDamage.pendingDamages[charId] = nil
    end,
    Hook.HookMethodType.Before
)

-- 阶段3: 定期清理过期的数据（防止内存泄漏）
Hook.Add("think", "NFD.Cleanup", function()
    local currentTime = Timer.GetTime()
    
    -- 按固定间隔清理（不是每帧都清理）
    if currentTime - NoFriendlyDamage.lastCleanupTime < CONFIG.CLEANUP_INTERVAL then
        return
    end
    
    NoFriendlyDamage.lastCleanupTime = currentTime
    
    local toRemove = {}
    local count = 0
    
    for charId, data in pairs(NoFriendlyDamage.pendingDamages) do
        if currentTime - data.time > CONFIG.MARKER_EXPIRY_TIME * 2 then
            count = count + 1
            table.insert(toRemove, charId)
        end
    end
    
    for _, charId in ipairs(toRemove) do
        NoFriendlyDamage.pendingDamages[charId] = nil
    end
    
    if count > 0 then
        dbg("🧹 清理了 " .. count .. " 条过期数据")
    end
end)

-- ==================== 调试命令（可选） ====================
-- 可在游戏中通过控制台调用查看统计信息
function NoFriendlyDamage.GetStats()
    return {
        pendingCount = #NoFriendlyDamage.pendingDamages,
        totalChecks = NoFriendlyDamage.stats.totalChecks,
        appliedMods = NoFriendlyDamage.stats.appliedModifications,
        skipped = NoFriendlyDamage.stats.skippedAttacks
    }
end

return NoFriendlyDamage
