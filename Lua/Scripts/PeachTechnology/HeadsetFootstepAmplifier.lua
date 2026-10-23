--[[
    HeadsetFootstepAmplifier.lua
    功能：佩戴 Deep-Diving-Armory 耳机时，
          1) 放大"其他人类角色"脚步声的音量与可闻范围；
          2) 可选调整"自己"脚步声的音量（selfVolumeMult，默认 1.0 即原版不变）；
          3) 门后穿透（hearThroughDoors 数值）：数值越高，他人脚步在门后"清晰可闻"的距离越远。
    原理：Ragdoll.PlayImpactSound 是脚步声唯一客户端入口（人类步态/生物步态/肢体落地均汇入），
          其 Before/After 钩子仅捕获"声音生产者"上下文（无 PreventExecution，原方法完整执行）；
          所有带标签的音效最终经 SoundPlayer.PlaySound(string, Vector2, float?, float?, Hull) 播放
          （原版参考：SoundPlayer.cs L485-490），在该入口按倍率覆盖 volume/range 参数。
          拦截点必须在其内部距离剔除（L515，用 range 剔除远处声音）的上游，
          否则范围扩展会被原版剔除截断；更底层的 Sound.Play 在剔除之后，无法实现范围扩展。
          门后穿透：原版闷音为二值判定（ShouldMuffleSound L1011，关闭的门在 Hull.GetApproximateDistance
          L1185-1189 直接断路），且引擎层为预烘焙缓冲区切换（SoundChannel.Muffled 在 AlMuffledBuffer 与
          AlBuffer 间切换，无连续低通频率旋钮），故数值穿透以"清晰半径"表达：0<p<1 时仅直线距离
          p*range 内解除闷音，>=1 无条件解除；LuaCs Postfix 修改返回值须通过显式 return
          （LuaPatcherService.cs L550-578 将非 void 返回值转换为原方法返回类型），
          ptable["return"] 走参数索引器对返回值无效。
    作用域：纯客户端音频逻辑，每个客户端按"本地玩家是否佩戴"独立判定，服务器零参与，单人与多人均可用。
    注意：不要在 Hook 回调内遍历 .NET 集合（List.Count 会静默返回 nil），本实现已规避。
    已知边界：1) 爬梯重甲脚步（AnimController L862/867 直接调用 PlaySound，不在 PlayImpactSound 栈内）保持原版；
              2) OpenAL 单源最大增益为 1.0，自身脚步原音量已达 1.0 的标签（如 footstep_armor）无法再放大；
              3) 门后穿透仅对命中放大的他人脚步生效（含隔舱壁/隔潜艇），水下闷音保持原版；
                 0<p<1 的清晰半径为直线距离近似，不区分门与舱壁。
]]

if not CLIENT then return end

local DEBUG_MODE = false
local CONFIG_CHECK_INTERVAL = 0.5

-- 耳机独立配置：volumeMult/rangeMult 为他人脚步的音量/范围倍率；
-- selfVolumeMult 为自己脚步的音量倍率（1.0 即原版；仅影响音量，范围对近场的自己无意义）；
-- hearThroughDoors 为门后穿透能力（0=原版闷音；0<p<1=直线距离 p*far 内门后清晰、超出仍闷音；
-- >=1=门后完全清晰；far 已含 rangeMult 扩展；水下闷音始终保留）；
-- 表顺序即同时佩戴时的优先级
local HEADSET_CONFIGS = {
    { identifier = "gssh01_headset", volumeMult = 3.0, rangeMult = 3.5, selfVolumeMult = 2.0, hearThroughDoors = 0.2 },
    { identifier = "m32_headset",    volumeMult = 2.0, rangeMult = 3.0, selfVolumeMult = 1.0, hearThroughDoors = 0.4 },
    { identifier = "walker_headset", volumeMult = 2.0, rangeMult = 3.0, selfVolumeMult = 0.5, hearThroughDoors = 0.5 },
}

-- 脚步声判定：前缀匹配所有 footstep 变体（原版鞋类穿戴件标签含 footstep_metal_boots、
-- footstep_heels、footstep_metal_heels、footstep_armor_heavy_heels 等未逐一枚举的变体，
-- 见 PlayImpactSound L392-398 的 wearable.Sound 路径）；
-- 生物脚步（footstep_crawler 等）由 IsHuman 过滤排除，无需在此区分
local FOOTSTEP_PREFIX = "footstep"

local function IsFootstepTag(soundTag)
    return type(soundTag) == "string" and string.sub(soundTag, 1, #FOOTSTEP_PREFIX) == FOOTSTEP_PREFIX
end

-- 预转换 Identifier，避免检测循环内的重复封送
for i = 1, #HEADSET_CONFIGS do
    HEADSET_CONFIGS[i].id = Identifier(HEADSET_CONFIGS[i].identifier)
end

local activeConfig = nil
local lastCheckTime = 0

-- 当前脚步声生产者上下文：由 PlayImpactSound 的 Before/After 钩子维护，
-- PlaySound 回调借其精确区分"自己/他人"与"人类/生物"
local currentProducer = nil

-- 门后穿透标志：PlaySound 钩子为"他人人类脚步"置位，其内部 L519 的 ShouldMuffleSound
-- Postfix 消费，PlaySound 的 After 钩子复位（标志生命周期与单次 PlaySound 调用严格同栈）
local suppressMuffle = false

local function log(...)
    if DEBUG_MODE then
        print("[HeadsetFootstepAmplifier]", ...)
    end
end

local function DetectHeadset()
    local controlled = Character.Controlled
    if controlled == nil then
        return nil
    end
    for i = 1, #HEADSET_CONFIGS do
        local cfg = HEADSET_CONFIGS[i]
        if controlled:GetEquippedItem(cfg.id) ~= nil then
            return cfg
        end
    end
    return nil
end

local function CaptureProducer(instance, ptable)
    currentProducer = instance.Character
end

local function ReleaseProducer(instance, ptable)
    currentProducer = nil
end

-- 命中条件（按序短路）：本地玩家佩戴耳机、声音来自 PlayImpactSound 调用栈、
-- 标签在放大表内；他人须为人类，自己仅在配置了非 1 的 selfVolumeMult 时调整
local function OnPlaySound(instance, ptable)
    if activeConfig == nil or currentProducer == nil then
        return
    end

    local soundTag = ptable["soundTag"]
    if not IsFootstepTag(soundTag) then
        return
    end

    local controlled = Character.Controlled
    if controlled == nil then
        return
    end

    local cfg = activeConfig
    local isSelf = currentProducer == controlled
    if isSelf then
        if cfg.selfVolumeMult == nil or cfg.selfVolumeMult == 1.0 then
            return
        end
    elseif not currentProducer.IsHuman then
        return
    end

    local volume = ptable["volume"]
    local range = ptable["range"]

    -- 原版调用未传 volume/range 时，从同标签音效取原版基准值（同标签各变体的增益/范围一致）
    if volume == nil or range == nil then
        local baseSound = SoundPlayer.GetSound(soundTag)
        if baseSound == nil then
            return
        end
        volume = volume or baseSound.BaseGain
        range = range or baseSound.BaseFar
    end

    if isSelf then
        ptable["volume"] = Single(volume * cfg.selfVolumeMult)
    else
        ptable["volume"] = Single(volume * cfg.volumeMult)
        ptable["range"] = Single(range * cfg.rangeMult)
        if (cfg.hearThroughDoors or 0) > 0 then
            suppressMuffle = true
        end
    end

    log("Boost footstep: tag=" .. tostring(soundTag)
        .. " self=" .. tostring(isSelf)
        .. " producer=" .. tostring(currentProducer.Name)
        .. " volumeMult=" .. tostring(isSelf and cfg.selfVolumeMult or cfg.volumeMult)
        .. " rangeMult=" .. tostring(isSelf and "-" or cfg.rangeMult)
        .. " hearThroughDoors=" .. tostring(isSelf and "-" or cfg.hearThroughDoors))
end

-- 复位门后穿透标志（与 OnPlaySound 同签名覆盖同一重载，保证同栈生命周期）
local function ReleaseMuffleFlag(instance, ptable)
    suppressMuffle = false
end

-- 门后穿透 Postfix：按 hearThroughDoors 数值解除闷音。
-- p >= 1：无条件覆盖为不闷音（全频段清晰）；
-- 0 < p < 1：仅当听者与声源直线距离 <= p*range（range 参数已含 rangeMult 扩展）时覆盖，
--             超出半径保持原版闷音（600Hz 低通缓冲区）；
-- 水下闷音（原版 L994-999 的 lowpassHFGain 判定）通过复刻其前置计算始终保持原版。
-- 显式 return false 才会覆盖原返回值，早期 return（void）不干预（LuaPatcherService.cs L550-578）
local function SuppressMuffle(instance, ptable)
    if not suppressMuffle or currentProducer == nil or activeConfig == nil then
        return
    end
    local p = activeConfig.hearThroughDoors or 0
    local listener = Character.Controlled
    if listener == nil or p <= 0 then
        return
    end
    local lowpassHFGain = 1.0
    if listener.AnimController.HeadInWater then
        lowpassHFGain = 0.2
    end
    lowpassHFGain = lowpassHFGain * listener.LowPassMultiplier
    if lowpassHFGain < 0.5 then
        return
    end
    if p >= 1.0 then
        return false
    end
    local soundPos = ptable["soundWorldPos"]
    local listenerPos = listener.WorldPosition
    local clearRadius = p * ptable["range"]
    local dx = listenerPos.X - soundPos.X
    local dy = listenerPos.Y - soundPos.Y
    if dx * dx + dy * dy <= clearRadius * clearRadius then
        log("Door penetration: muffle suppressed (radius p=" .. tostring(p)
            .. "), producer=" .. tostring(currentProducer.Name))
        return false
    end
end

Hook.Add("think", "HeadsetFootstepAmplifier.ConfigCheck", function()
    local now = Timer.Time
    if now - lastCheckTime < CONFIG_CHECK_INTERVAL then
        return
    end
    lastCheckTime = now

    local cfg = DetectHeadset()
    if cfg ~= activeConfig then
        if cfg == nil then
            log("Headset removed, footstep boost disabled")
        else
            log("Headset active: " .. cfg.identifier
                .. " volumeMult=" .. tostring(cfg.volumeMult)
                .. " rangeMult=" .. tostring(cfg.rangeMult)
                .. " hearThroughDoors=" .. tostring(cfg.hearThroughDoors))
        end
        activeConfig = cfg
    end
end)

Hook.Patch("HeadsetFootstepAmplifier.CaptureProducer", "Barotrauma.Ragdoll", "PlayImpactSound",
    CaptureProducer, Hook.HookMethodType.Before)

Hook.Patch("HeadsetFootstepAmplifier.ReleaseProducer", "Barotrauma.Ragdoll", "PlayImpactSound",
    ReleaseProducer, Hook.HookMethodType.After)

-- 拦截点位于距离剔除的上游，覆盖 volume/range 才能同时实现音量放大与范围扩展
Hook.Patch("HeadsetFootstepAmplifier.PlaySound", "Barotrauma.SoundPlayer", "PlaySound",
    {
        "System.String",
        "Microsoft.Xna.Framework.Vector2",
        "System.Nullable`1[[System.Single]]",
        "System.Nullable`1[[System.Single]]",
        "Barotrauma.Hull",
    },
    OnPlaySound, Hook.HookMethodType.Before)

Hook.Patch("HeadsetFootstepAmplifier.ReleaseMuffleFlag", "Barotrauma.SoundPlayer", "PlaySound",
    {
        "System.String",
        "Microsoft.Xna.Framework.Vector2",
        "System.Nullable`1[[System.Single]]",
        "System.Nullable`1[[System.Single]]",
        "Barotrauma.Hull",
    },
    ReleaseMuffleFlag, Hook.HookMethodType.After)

-- 门后穿透：ShouldMuffleSound 全局唯一无重载，按名字匹配即可；
-- Postfix 通过显式 return false 覆盖原返回值（不闷音），早期 return（void）则保持原结果
Hook.Patch("HeadsetFootstepAmplifier.SuppressMuffle", "Barotrauma.SoundPlayer", "ShouldMuffleSound",
    SuppressMuffle, Hook.HookMethodType.After)
