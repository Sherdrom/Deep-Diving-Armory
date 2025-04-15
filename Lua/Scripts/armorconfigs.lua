DDA_AAS.Armors={

    itemid = {
        name = "something",                         --Name, not actually used in game
        type = "typename",                          --Armorplate type, available: "metal","composite","ceramic","custom"
        ricochetchance = 0.0,                       --Define ricochet chance, range 0-1, will not affect force-pen
        level = 0,                                  --Bulletproof level, range 0-10
        aftereffectmultiplier  = 0.0,               --Define damage multiplier if pen
        correctionaffliction = nil,                 --Define affliction if non-pen, TODO: Use table instead of single string
        correctionmultiplier = 0.0,                 --Define how many damage should pass to player
        enablecorrection = false,                   --Define should give non-pen affliction
        penresistance = 0.8,                        --Define pen resistance, will use to caculate remaining pen
        maxhits = 0,                                --Define how many hits this armorplate can take, use to caculate condition
        maxcondition = 0,                           --Define max condition for this armorplate, use to caculate condition
        ignoredamage = false,                       --Take damage or not.
        --custom stuff, only work if custom type
        targetidentifier = "gunshotwound",          --Decide what damage this will decide a valid shot
        customexpression = function(item,affliction,data)         --expression to caculate plate damage
            return item.Condition - (affliction.Strength / 100) * (data.maxcondition / data.maxhits)
        end,

    },  --Note: this is Sample, do not delete it

    deep_tactec = {
        name = "something",                         --Name, not actually used in game
        type = "composite",                          --Armorplate type, available: "metal","composite","ceramic","custom"
        ricochetchance = 0.0,                       --Define ricochet chance, range 0-1, will not affect force-pen
        level = 4,                                  --Bulletproof level, range 0-10
        aftereffectmultiplier  = 0.6,               --Define damage multiplier if pen
        correctionaffliction = "blunttrauma",                 --Define affliction if non-pen, TODO: Use table instead of single string
        correctionmultiplier = 0.2,                 --Define how many damage should pass to player
        enablecorrection = true,                   --Define should give non-pen affliction
        penresistance = 0.8,                        --Define pen resistance, will use to caculate remaining pen
        maxhits = 0,                                --Define how many hits this armorplate can take, use to caculate condition
        maxcondition = 0,                           --Define max condition for this armorplate, use to caculate condition
        ignoredamage = true,                       --Take damage or not.
        --custom stuff, only work if custom type
        targetidentifier = "gunshotwound",          --Decide what damage this will decide a valid shot
        customexpression = function(item,affliction,data)         --expression to caculate plate damage
            return item.Condition - (affliction.Strength / 100) * (data.maxcondition / data.maxhits)
        end,

    },  --Note: this is Sample, do not delete it


}

-- penlevel = floor(pen*10)
-- overwhelming pen : penlevel - level >= 2
-- Non-pen correction: correctionaffliction = targetaffliction * correctionmultiplier

-- composite armor condition = condition - (gunshotwound / 100) * (maxcondition / maxhits)
-- ceramic armor condition = condition - (gunshotwound / 100) * (maxcondition / condition) * (maxcondition / maxhits)
-- metal armor condition = condition - (maxcondition / maxhits), only available if allowdamage is true
-- remaining penlevel = penlevel - floor(level * penresistance)

-- All pre-defined type will only decide damage with gunshot wound is valid.