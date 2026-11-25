-- VCE Legacy 护甲框架命名空间引导(移植自 VCE Legacy)。
-- VCE.Path 指向深潜目录, 跳弹音效等资源随深潜分发, 不再依赖 VCE Legacy 模组。
-- 注意: 本模组已内置该框架, 启用深潜时应停用 VCE Legacy,
-- 否则全局 VCE 表会被覆盖且 DamageLimb 钩子双重注册(伤害计算翻倍)。

VCE = VCE or {}
VCE.Path = Deep_Lua.Path
VCE.ArmorSystem = VCE.ArmorSystem or {}

-- 基础配置表: 实际插板配置由 AliceTechnology/armorconfigs.lua 构建,
-- 在其末尾 Timer.Wait 中经 VCE.ArmorSystem.AddtoMain 注册
VCE.ArmorConfigs = VCE.ArmorConfigs or {}

VCE.HF = VCE.HF or {}
VCE.HF.clamp = math.clamp

---@param probability number
---@return boolean
VCE.HF.DoChance = function(probability)
    local probability = VCE.HF.clamp(probability, 0, 1) * 100
    if probability - math.random(1, 100) >= 0 then return true end
    return false
end

---@param vector Microsoft.Xna.Framework.Vector2
---@return number
VCE.HF.Vector2Dir = function(vector)
    return math.atan2(vector.Y, vector.X)
end
