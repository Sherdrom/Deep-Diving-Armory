Deep_Lua.Armors = {
    sampleitemid = {
        --Universal
        name = "something",                         --Name, not actually used in game. Optional, you can remove this if you know what is what.
        type = "typename",                          --Armorplate type, available: "metal","composite","ceramic","custom"
        ricochetchance = 0.0,                       --Define ricochet chance, range 0-1, will not affect force-pen
        level = 0,                                  --Bulletproof level, range 0-10, 10+ is also possible.(I dont think that will be useful, really)
        aftereffectmultiplier  = 0.0,               --Define damage multiplier if pen-ed
        correctionaffliction = nil,                 --Define affliction applied to user if non-pen, TODO: Use table instead of single string(Low Prior)
        correctionmultiplier = 0.0,                 --Define how many damage should pass to user
        enablecorrection = false,                   --Define should give non-pen affliction
        penresistance = 0.8,                        --Define pen resistance, will use to caculate remaining pen
        targetidentifier = {                        --Define what damage will this plate/helmet/armor protect against. For most cases gunshotwound.
            ["gunshotwound"] = true
        },
        --targetidentifier = "Any" if you want to define a full-protection armor(Also work for pre-defined types)

        --Condition caculation
        maxhits = 0,                                --Define how many hits this armorplate can take, use to caculate condition
        maxcondition = 0,                           --Define max condition for this armorplate, use to caculate condition
        ignoredamage = false,                       --Will the item take damage or not.

        --Carrier/Helmet with extra armor plate Specific
        isPlateCarrier = false,                     --Decided whether this is a plate carrier. Only work for outer cloth/helmet.
        protectionarea = {                          --Define areas of protection, only necessary for plate carriers. Define this for plates wont work.
            [LimbType.Torso] = true,                --Only add true items.
            [LimbType.Waist] = true,                --Note: This list may not up-to-date so please note we accept any limbs here. Use custom limbs at your own risk
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
            [LimbType.LeftLeg] = true,
            [LimbType.RightLeg] = true,
            [LimbType.LeftFoot] = true,
            [LimbType.RightFoot] = true,
        },

        --Masked Helmet Specific
        isHelmet = false,                           --Define whether this is a masked helmet, if true use masked helmet specific code
                                                    --Use this ONLY when you want to define a helmet with a mask. Otherwise keep this false, = a standard armor for your head.

        --Custom stuff, only work if type "custom"
        customexpression = function(item,affliction,data)         --expression to caculate plate damage
            return item.Condition - (affliction.Strength / 100) * (data.maxcondition / data.maxhits)
        end,

        --Third-Party Support
        protected = true,                           --Protected or not
        override = true,                            --Override control parameter
        forceoverride = false,                      --Force override control parameter
                                                    --Be aware what are u doing before using this parameter!

    },

    --陶瓷
    deep_plate_ceramic_4 = {
        name = "氧化铝",
        type = "ceramic",
        ricochetchance = 0.15,
        level = 4,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_5 = {
        name = "高纯度氧化铝",
        type = "ceramic",
        ricochetchance = 0.2,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_6 = {
        name = "碳化硅",
        type = "ceramic",
        ricochetchance = 0.25,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_7 = {
        name = "二硼化钛",
        type = "ceramic",
        ricochetchance = 0.3,
        level = 7,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_8 = {
        name = "碳化硼",
        type = "ceramic",
        ricochetchance = 0.35,
        level = 8,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_9 = {
        name = "氧化铍",
        type = "ceramic",
        ricochetchance = 0.4,
        level = 9,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_10 = {
        name = "刚化钨",
        type = "ceramic",
        ricochetchance = 0.45,
        level = 10,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --金属
    deep_plate_metal_3 = {
        name = "铝板",
        type = "metal",
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_4 = {
        name = "铁板",
        type = "metal",
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_5 = {
        name = "轻质钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 5,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_6 = {
        name = "45钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_7 = {
        name = "复合钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_8 = {
        name = "刚素板",
        type = "metal",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_9 = {
        name = "超重钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_10 = {
        name = "复合钨钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 10,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_4 = {
        name = "手臂铁板",
        type = "metal",
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_5 = {
        name = "手臂轻质钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 5,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_6 = {
        name = "手臂45钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_7 = {
        name = "手臂复合钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_8 = {
        name = "手臂刚素板",
        type = "metal",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_arm_9 = {
        name = "手臂超重钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_4 = {
        name = "手臂氧化铝",
        type = "ceramic",
        ricochetchance = 0.15,
        level = 4,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_5 = {
        name = "手臂高纯度氧化铝",
        type = "ceramic",
        ricochetchance = 0.2,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_6 = {
        name = "手臂碳化硅",
        type = "ceramic",
        ricochetchance = 0.25,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_7 = {
        name = "手臂二硼化钛",
        type = "ceramic",
        ricochetchance = 0.3,
        level = 7,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_8 = {
        name = "手臂碳化硼",
        type = "ceramic",
        ricochetchance = 0.35,
        level = 8,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_arm_9 = {
        name = "手臂氧化铍",
        type = "ceramic",
        ricochetchance = 0.4,
        level = 9,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_4 = {
        name = "腹股沟氧化铝",
        type = "ceramic",
        ricochetchance = 0.15,
        level = 4,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_5 = {
        name = "腹股沟高纯度氧化铝",
        type = "ceramic",
        ricochetchance = 0.2,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_6 = {
        name = "腹股沟碳化硅",
        type = "ceramic",
        ricochetchance = 0.25,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_7 = {
        name = "腹股沟二硼化钛",
        type = "ceramic",
        ricochetchance = 0.3,
        level = 7,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_8 = {
        name = "腹股沟碳化硼",
        type = "ceramic",
        ricochetchance = 0.35,
        level = 8,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_groin_9 = {
        name = "腹股沟氧化铍",
        type = "ceramic",
        ricochetchance = 0.4,
        level = 9,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 40,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_4 = {
        name = "腹股沟铁板",
        type = "metal",
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_5 = {
        name = "腹股沟轻质钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 5,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_6 = {
        name = "腹股沟45钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_7 = {
        name = "腹股沟复合钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_8 = {
        name = "腹股沟刚素板",
        type = "metal",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_metal_groin_9 = {
        name = "腹股沟超重钢",
        type = "metal",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 1.0,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

      --复合插板
    deep_plate_composite_6 = {
        name = "凯夫拉+氧化铝",
        type = "composite",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 0.5,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_7 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 0.45,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_8 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 0.4,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_9 = {
        name = "迪尼玛纤维+氧化铍",
        type = "composite",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 0.35,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_10 = {
        name = "超高分子量聚乙烯+碳化硼",
        type = "composite",
        ricochetchance = 0.0,
        level = 10,
        aftereffectmultiplier  = 0.3,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_rf3 = {
        name = "RF3",
        type = "composite",
        ricochetchance = 0.25,
        level = 9,
        aftereffectmultiplier  = 0.5,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_br6 = {
        name = "BR6",
        type = "composite",
        ricochetchance = 0.3,
        level = 10,
        aftereffectmultiplier  = 0.4,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_arm_6 = {
        name = "凯夫拉+氧化铝",
        type = "composite",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 0.5,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_arm_7 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 0.45,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_arm_8 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 0.4,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_arm_9 = {
        name = "迪尼玛纤维+氧化铍",
        type = "composite",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 0.35,
        correctionaffliction = "deep_bullet_injury_arm",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_groin_6 = {
        name = "凯夫拉+氧化铝",
        type = "composite",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 0.5,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_groin_7 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 7,
        aftereffectmultiplier  = 0.45,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_groin_8 = {
        name = "高分子量聚乙烯+碳化硅",
        type = "composite",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 0.4,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_composite_groin_9 = {
        name = "迪尼玛纤维+氧化铍",
        type = "composite",
        ricochetchance = 0.0,
        level = 9,
        aftereffectmultiplier  = 0.35,
        correctionaffliction = "deep_bullet_injury_groin",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 80,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --内衬
    deep_hpc = {
        name = "hpc插板背心",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 0,
        aftereffectmultiplier  = 1,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = false,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    thor = {
        name = "THOR",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 2,
        aftereffectmultiplier  = 0.9,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_tactec = {
        name = "TACTEC",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 2,
        aftereffectmultiplier  = 0.9,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_m1 = {
        name = "M1",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 2,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --Lv 3
    deep_6b13 = { --WARN: 6B13 is not a valid id.
        name = "6B13",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_6b23 = {
        name = "deep_6b23",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_Guardian = {
        name = "Guardian",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.9,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_osprey = {
        name = "Osprey",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_bagariy = {
        name = "deep_bagariy",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_defender = {
        name = "deep_defender",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_Obsidian = {
        name = "Obsidian",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    gen4_heavy = {
        name = "Gen 4 Heavy",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 3,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --Lv 4
    deep_6b43 = {
        name = "6B43",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_fort_t5 = {
        name = "deep_fort_t5",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 0.7,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_zhuk_6a = {
        name = "deep_zhuk_6a",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 0.6,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0,
        enablecorrection = false,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --EXO Pirate
    deep_pirate_exosuit = {
        name = "海盗外骨骼",
        type = "composite",
        isPlateCarrier = true,
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 0.9,
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0,
        enablecorrection = false,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {
            [LimbType.Torso] = true,
            [LimbType.Waist] = true,
            [LimbType.LeftArm] = true,
            [LimbType.LeftForearm] = true,
            [LimbType.LeftHand] = true,
            [LimbType.RightArm] = true,
            [LimbType.RightForearm] = true,
            [LimbType.RightHand] = true,
            [LimbType.LeftThigh] = true,
            [LimbType.RightThigh] = true,
            [LimbType.LeftLeg] = true,
            [LimbType.RightLeg] = true,
            [LimbType.LeftFoot] = true,
            [LimbType.RightFoot] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    --头盔
    deep_kiver_m = {
        isPlateCarrier = false,
        name = "deep_kiver_m",
        type = "composite",
        ricochetchance = 0.4,
        level = 4,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },--Sample

    deep_zsh_1_2_m = {
        isPlateCarrier = false,
        name = "deep_zsh_1_2_m",
        type = "composite",
        ricochetchance = 0.5,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },

    deep_fast_helmet_ghost = {
        isPlateCarrier = false,
        name = "deep_fast_helmet_ghost",
        type = "composite",
        ricochetchance = 0.5,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },

    deep_Fearless_Vanguard = {
        isPlateCarrier = false,
        name = "deep_Fearless_Vanguard",
        type = "composite",
        ricochetchance = 0.6,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.08,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },

    deep_altyn = {
        isPlateCarrier = false,
        name = "deep_altyn",
        type = "composite",
        ricochetchance = 0.7,
        level = 7,
        aftereffectmultiplier  = 0.5,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = true,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },

    deep_maska = {
        isPlateCarrier = false,
        name = "deep_maska",
        type = "composite",
        ricochetchance = 0.8,
        level = 7,
        aftereffectmultiplier  = 0.4,
        correctionaffliction = "deep_headshot_deadly",
        correctionmultiplier = 0.05,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = true,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = {
            ["gunshotwound"] = true
        },
    },

}

-- penlevel = floor(pen*10)
-- overwhelming pen : penlevel - level >= 2
-- Non-pen correction: correctionaffliction = targetaffliction * correctionmultiplier

-- composite armor condition = condition - (gunshotwound / 20 or 1(min)) * (maxcondition / maxhits)
-- ceramic armor condition = condition - (gunshotwound / 20 or 1(min)) * (maxcondition / condition) * (maxcondition / maxhits)
-- metal armor condition = condition - (maxcondition / maxhits), only available if allowdamage is true
-- remaining penlevel = penlevel - floor(level * penresistance)

-- All pre-defined type will only decide damage with gunshot wound is valid.



-- WARN: YOU SHOULD MAKE SURE YOUR CONFIG IS CORRECT BEFORE LOADING INTO MAIN CONFIG!
function Deep_Lua.Armors.AddtoMain(configtable)
    for id,config in pairs(configtable) do
        if Deep_Lua.Armors[id] == nil then goto goodend end
        if config.override ~= true then
            print("‖color:gui.yellow‖Warning: Config for " .. id .. " already exists. Please use override control parameter.‖end‖")
            goto loopend
        elseif Deep_Lua.Armors[id].protected == true and config.forceoverride ~= true then
            print("‖color:gui.yellow‖Warning: Config for " .. id .. " is protected. Skipping...‖end‖")
            goto loopend
        end
        ::goodend::                     --Green Light. All clear to go. NO VALIDATION CHECK.
        Deep_Lua.Armors[id] = config
        ::loopend::                     --Red Light. Next.
    end
end


--local TestArmors = {}

--Deep_Lua.Armors.AddtoMain(TestArmors)