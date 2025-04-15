DDA_AAS.Main = {}

-- Limb convertion stuff
local limbtoslot = {}
limbtoslot[LimbType.Head] = {InvSlotType.Head}
--Torso and waist
limbtoslot[LimbType.Torso] = {InvSlotType.OuterClothes,0}
limbtoslot[LimbType.Waist] = {InvSlotType.OuterClothes,0}
--Entire left arm
limbtoslot[LimbType.LeftArm] = {InvSlotType.OuterClothes,1}
limbtoslot[LimbType.LeftForearm] = {InvSlotType.OuterClothes,1}
limbtoslot[LimbType.LeftHand] = {InvSlotType.OuterClothes,1}
--Entire right arm
limbtoslot[LimbType.RightArm] = {InvSlotType.OuterClothes,1}
limbtoslot[LimbType.RightForearm] = {InvSlotType.OuterClothes,1}
limbtoslot[LimbType.RightHand] = {InvSlotType.OuterClothes,1}
--Thigh
limbtoslot[LimbType.LeftThigh] = {InvSlotType.OuterClothes,2}
limbtoslot[LimbType.RightThigh] = {InvSlotType.OuterClothes,2}

--Functions
function DDA_AAS.Main.getArmor(character,targetlimb)
    if character == nil or targetlimb == nil then return nil,nil end
    local characterInv = character.Inventory                                    --Get character inv
    local targetinv = limbtoslot[targetlimb.type]                               --Get corresponding limb and its slot
    local outeritem = characterInv.GetItemInLimbSlot(targetinv[1])              --Get outer cloth(item)
    if outeritem == nil then return nil,nil end
    if outeritem.OwnInventory == nil then return outeritem,nil end
    local inneritem = outeritem.OwnInventory.GetItemAt(targetinv[2])            --Get contained plate(item)
    return outeritem,inneritem                                                  --Return armor(item)
end

local function clamp(input,min,max)
    if input <= min then return min end
    if input >= max then return max end
    return input
end

local function CaculateCeramicDamage(item,affliction,data)
    local condition = item.Condition
    condition = condition - (affliction.Strength / 100) * (data.maxcondition / condition) * (data.maxcondition / data.maxhits)
    return condition
end

local function CaculateCompositeDamage(item,affliction,data)
    local condition = item.Condition
    condition = condition - (affliction.Strength / 100) * (data.maxcondition / data.maxhits)
    return condition
end

local function CaculateMetalDamage(item,affliction,data)
    local condition = item.Condition
    condition = condition - (data.maxcondition / data.maxhits)
    return condition
end

local function DoChance(probability)
    local probability = clamp(probability,0,1) * 100
    if probability - math.random(1,100) >= 0 then return true end
    return false
end

function DDA_AAS.Main.PlateMain(data,item,ptable,penlevel,damagemultiplier,affliction,char,limb)
    local continue = true
    local ricochet = DoChance(data.ricochetchance)                                          --Roll the dice

    if penlevel >= data.level + 2 then ricochet = false end                                 --Overwhelming pen, no ricochet :)

    if ricochet then                                                                        --Jackpot
        continue = false
        return
    end

    --Plate damage stuff
    if data.type == "ceramic" then
        item.Condition = CaculateCeramicDamage(item,affliction,data)
    elseif data.type == "composite" then
        item.Condition = CaculateCompositeDamage(item,affliction,data)
    elseif data.type == "metal" and not data.ignoredamage then
        item.Condition = CaculateMetalDamage(item,affliction,data)
    else
        item.Condition = data.customexpression(item,affliction,data)                        --Require custom expression
    end

    if data.enablecorrection == true and data.correctionaffliction ~= nil then              --Corrections
        local prefab = AfflictionPrefab.Prefabs[data.correctionaffliction]
        local strength = affliction.Strength * data.correctionmultiplier
        local correctaffliction = prefab.Instantiate(strength, nil)
        char.CharacterHealth.ApplyAffliction(limb,correctaffliction,true,false,false)
    end

    if penlevel < data.level and item.Condition > 0 then                                    --No Pen, good condition
        continue = false
        return
    else
        penlevel = penlevel - math.floor(data.level * data.penresistance)                   --Reamining pen
    end

    damagemultiplier = damagemultiplier * data.aftereffectmultiplier

    return damagemultiplier,penlevel,continue                                               --Damage caculation thing, work after everything is done
end

--Main stuff
Hook.Patch("Barotrauma.Character", "ApplyAttack", function(instance, ptable)
    local targetlimb = ptable["targetLimb"]
    if targetlimb == nil then return end
    local attackdata = ptable["attack"]
    local penetrationlevel = math.floor(ptable["penetration"]*10)
    local targetcharacter = targetlimb.character
    local outercloth,innerplate = DDA_AAS.Main.getArmor(targetcharacter,targetlimb)
    local outertargetid = "gunshotwound"
    local innertargetid = "gunshotwound"
    local clothdata, platedata = nil,nil
    --find plate carrier data, if any
    if outercloth ~= nil then 
        clothdata = DDA_AAS.Armors[outercloth.Prefab.Identifier.Value]
        if clothdata ~= nil and clothdata.type == "custom" then
            outertargetid = clothdata.targetidentifier
        end
    end
    --find plate data, if any
    if innerplate ~= nil then
        platedata = DDA_AAS.Armors[innerplate.Prefab.Identifier.Value]
        if platedata ~= nil and platedata.type == "custom" then
            innertargetid = platedata.targetidentifier
        end
    end

    local executecloth = false
    local executeplate = false

    local clothaffliction = nil
    local plateaffliction = nil

    --let's find out if it is a valid attack
    for i,v in pairs(attackdata.Afflictions) do
        if clothdata ~= nil and not executecloth and i.identifier == outertargetid then
            clothaffliction = i
            executecloth = true
        end
        if platedata~= nil and not executeplate and i.identifier == innertargetid then
            plateaffliction = i
            executeplate = true
        end
    end


    if not executecloth and not executeplate then return end                                                    --Did u mean run even if unnecessary?

    local damagemultiplier = 1.0
    local continue = true

    if executeplate then
        damagemultiplier,penetrationlevel,continue = DDA_AAS.Main.PlateMain(platedata,innerplate,ptable,penetrationlevel,damagemultiplier,plateaffliction,targetcharacter,targetlimb)
        ptable.PreventExecution = not continue
        if not continue then return end
    end

    --Note: Basically we are doing what we did again.
    if executecloth then
        damagemultiplier,penetrationlevel,continue =  DDA_AAS.Main.PlateMain(clothdata,outercloth,ptable,penetrationlevel,damagemultiplier,clothaffliction,targetcharacter,targetlimb)
        ptable.PreventExecution = not continue
        if not continue then return end
    end

    --Damage stuff

    -- Note: These codes may cause F3 Errors but they wont lead to actual issues
    --local originpen = math.floor(ptable["penetration"]*10)
    --local penperc = penetrationlevel/originpen
    --ptable["penetration"] = ptable["penetration"] * penperc
    -- End Note

    ptable["attack"].DamageMultiplier = ptable["attack"].DamageMultiplier * damagemultiplier

end, Hook.HookMethodType.Before)