Deep_Lua.Main = {}

-- Limb convertion stuff
local limbtoslot = {
    [LimbType.Head] = {InvSlotType.Head,0},
    [LimbType.Torso] = {InvSlotType.OuterClothes,0},
    [LimbType.Waist] = {InvSlotType.OuterClothes,0},
    [LimbType.LeftArm] = {InvSlotType.OuterClothes,1},
    [LimbType.LeftForearm] = {InvSlotType.OuterClothes,1},
    [LimbType.LeftHand] = {InvSlotType.OuterClothes,1},
    [LimbType.RightArm] = {InvSlotType.OuterClothes,1},
    [LimbType.RightForearm] = {InvSlotType.OuterClothes,1},
    [LimbType.RightHand] = {InvSlotType.OuterClothes,1},
    [LimbType.LeftThigh] = {InvSlotType.OuterClothes,2},
    [LimbType.LeftLeg] = {InvSlotType.OuterClothes,nil},
    [LimbType.LeftFoot] = {InvSlotType.OuterClothes,nil},
    [LimbType.RightThigh] = {InvSlotType.OuterClothes,2},
    [LimbType.RightLeg] = {InvSlotType.OuterClothes,nil},
    [LimbType.RightFoot] = {InvSlotType.OuterClothes,nil},
}

local RicochetSound = {
    Sound = {
            ricochet = Game.SoundManager.LoadSound(DDA_AAS.Path .. "/jobgear/sound/ricochet.ogg"),
                            frequencyMultiplier = 1,
                            gain = 1,
                            range = 3000,
    }
}

--Functions
function Deep_Lua.Main.getArmor(character,targetlimb)
    if character == nil or targetlimb == nil then return nil,nil end
    local characterInv = character.Inventory                                    --Get character inv
    if characterInv == nil then return nil,nil end
    local targetinv = limbtoslot[targetlimb.type]                               --Get corresponding limb and its slot
    if targetinv == nil then return nil,nil end
    local outeritem = characterInv.GetItemInLimbSlot(targetinv[1])              --Get outer cloth(item)
    if outeritem == nil then return nil,nil end
    if outeritem.OwnInventory == nil or targetinv[2] == nil then return outeritem,nil end
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
    condition = condition - clamp(affliction.Strength / 20,1,math.huge) * (data.maxcondition / condition) * (data.maxcondition / data.maxhits)
    return condition
end

local function CaculateCompositeDamage(item,affliction,data)
    local condition = item.Condition
    condition = condition - clamp(affliction.Strength / 20,1,math.huge) * (data.maxcondition / data.maxhits)
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

function Deep_Lua.Main.PlateMain(data,item,penlevel,damagemultiplier,affliction,char,limb)
    local continue = true

    if data.isHelmet and item.GetComponentString("LightComponent").IsOn then                --If target is a masked helmet and mask was raised
        return damagemultiplier, penlevel, continue                                         --We are out, mask raised = no protection
    end
    
    local ricochet = DoChance(data.ricochetchance)                                          --Roll the dice

    if data.enablecorrection == true and data.correctionaffliction ~= nil then              --Corrections
        local prefab = AfflictionPrefab.Prefabs[data.correctionaffliction]
        local strength = affliction.Strength * data.correctionmultiplier * damagemultiplier
        local correctaffliction = prefab.Instantiate(strength, nil)
        char.CharacterHealth.ApplyAffliction(limb,correctaffliction,true,false,false)
    end

    if penlevel - data.level >= 2 then ricochet = false end                                 --Overwhelming pen, no ricochet :)

    if ricochet then                                                                        --Jackpot
        continue = false
        return 0, 0, continue
    end

    --Plate damage stuff
    if not data.ignoredamage and penlevel ~= 0 then
        if data.type == "ceramic" then
            item.Condition = CaculateCeramicDamage(item,affliction,data)
        elseif data.type == "composite" then
            item.Condition = CaculateCompositeDamage(item,affliction,data)
        elseif data.type == "metal" then
            item.Condition = CaculateMetalDamage(item,affliction,data)
        else
            item.Condition = data.customexpression(item,affliction,data)                        --Require custom expression
        end
    end

    if penlevel < data.level and item.Condition > 0 then                                    --No Pen, good condition
        continue = false
        return 0, 0, continue
    end
    if item.Condition > 0 then
        penlevel = penlevel - math.floor(data.level * data.penresistance)                   --Reamining pen
        damagemultiplier = damagemultiplier * data.aftereffectmultiplier
    end


    return damagemultiplier,penlevel,continue                                               --Damage caculation thing, work after everything is done
end

--Main stuff
Hook.Patch("Barotrauma.Character", "DamageLimb", function(instance, ptable)
    local targetlimb = ptable["hitLimb"]
    if targetlimb == nil then return end
    local afflictions = ptable["afflictions"]
    local penetrationlevel = math.floor((ptable["penetration"]+0.00001)*10)
    local targetcharacter = targetlimb.character
    if not targetcharacter.IsHuman then return end
    local outercloth,innerplate = Deep_Lua.Main.getArmor(targetcharacter,targetlimb)
    local outertargetid,innertargetid
    local clothdata, platedata = nil,nil
    --find plate carrier data, if any
    if outercloth ~= nil then 
        clothdata = Deep_Lua.Armors[outercloth.Prefab.Identifier.Value]
        if clothdata ~= nil then
            outertargetid = clothdata.targetidentifier
        else
            return                                                                                              --Not valid. Bye.
        end
    end
    --find plate data, if any
    if innerplate ~= nil then
        platedata = Deep_Lua.Armors[innerplate.Prefab.Identifier.Value]
        if platedata ~= nil then
            innertargetid = platedata.targetidentifier
        end
    end

    if outertargetid == nil and innertargetid == nil then return end

    local executecloth = false
    local executeplate = false

    local clothaffliction = {Strength = 0}
    local plateaffliction = {Strength = 0}

    if outertargetid == "Any" then executecloth = true end                                                      --Force override in "Any" case
    if innertargetid == "Any" then executeplate = true end

    --let's find out if it is a valid attack
    for i in afflictions do
        if clothdata ~= nil and not executecloth and i.identifier == outertargetid then
            clothaffliction = i
            executecloth = true
        end
        if platedata~= nil and not executeplate and i.identifier == innertargetid then
            plateaffliction = i
            executeplate = true
        end
        if clothdata ~= nil and outertargetid == "Any" then                                                     --Here we add up all strength for "Any" case
            clothaffliction.Strength = clothaffliction.Strength + i.Strength                                    --We actually trick our own codes. Makesure
        end                                                                                                     --you wont use anything else than Strength
        if platedata ~= nil and innertargetid == "Any" then                                                     --in "Any" case. This var only contains
            plateaffliction.Strength = plateaffliction.Strength + i.Strength                                    --Strength in that case.
        end
    end

    if executeplate and (not clothdata.isPlateCarrier) then executeplate = false end                            --Not a valid carrier, dont execute plate

    if not executecloth and not executeplate then return end                                                    --Did u mean run even if unnecessary?

    local damagemultiplier = 1.0
    local continue = true
    --A "little" bit tooooooooooo long :(
    if executeplate then
        damagemultiplier,penetrationlevel,continue = Deep_Lua.Main.PlateMain(platedata,innerplate,penetrationlevel,damagemultiplier,plateaffliction,targetcharacter,targetlimb)
        ptable.PreventExecution = not continue
        if not continue then return end
    end
    --Note: Basically we are doing what we did again.
    if executecloth and clothdata.protectionarea[targetlimb.type] then
        damagemultiplier,penetrationlevel,continue =  Deep_Lua.Main.PlateMain(clothdata,outercloth,penetrationlevel,damagemultiplier,clothaffliction,targetcharacter,targetlimb)
        ptable.PreventExecution = not continue
        if not continue then return end
    end

    --Damage stuffs

    local decreasedpen = ptable["penetration"] - (penetrationlevel / 10)
    ptable["penetration"] = Single(ptable["penetration"] + 0.00001 - decreasedpen)
    ptable["damageMultiplier"] = Single(ptable["damageMultiplier"] * damagemultiplier)

end, Hook.HookMethodType.Before)