DDA_AAS.Armors={

    itemid = {
        isPlateCarrier = false,                     --Decided whether this is a plate carrier. Only work for outer cloth/helmet
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
        isHelmet = false,                           --Define whether this is a masked helmet, if true use masked helmet specific code
        protectionarea = {                          --Define areas of protection, only necessary for plate carriers. Define this for plates wont work.
            [LimbType.Torso] = true,                --Only add true items.
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
        targetidentifier = "gunshotwound",          --Decide what damage this will decide a valid shot. default gunshotwound.
                                                    --Use "Any" if you want to define a full-protection armor(Also work for pre-defined types)
        --custom stuff, only work if custom type
        customexpression = function(item,affliction,data)         --expression to caculate plate damage
            return item.Condition - (affliction.Strength / 100) * (data.maxcondition / data.maxhits)
        end,

    },  --Note: Sample.

    --陶瓷
    deep_plate_ceramic_4 = {
        name = "氧化铝",
        type = "ceramic",
        ricochetchance = 0.0,
        level = 4,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 60,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_6 = {
        name = "碳化硅",
        type = "ceramic",
        ricochetchance = 0.0,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 75,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_8 = {
        name = "碳化硼",
        type = "ceramic",
        ricochetchance = 0.0,
        level = 8,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 75,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
        customexpression = function(item,affliction,data)
            return 100
        end,
    },

    deep_plate_ceramic_10 = {
        name = "刚化钨",
        type = "ceramic",
        ricochetchance = 0.0,
        level = 10,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = nil,
        correctionmultiplier = 0.0,
        enablecorrection = false,
        penresistance = 0,
        maxhits = 90,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury",
        correctionmultiplier = 0.15,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        maxhits = 60,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        maxhits = 70,
        maxcondition = 100,
        ignoredamage = false,
        protectionarea = {},
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        targetidentifier = "gunshotwound",
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
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.2,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
    },--Sample

    deep_zsh_1_2_m = {
        isPlateCarrier = false,
        name = "deep_zsh_1_2_m",
        type = "composite",
        ricochetchance = 0.5,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.2,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
    },

    deep_fast_helmet_ghost = {
        isPlateCarrier = false,
        name = "deep_fast_helmet_ghost",
        type = "composite",
        ricochetchance = 0.5,
        level = 5,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.2,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
    },

    deep_Fearless_Vanguard = {
        isPlateCarrier = false,
        name = "deep_Fearless_Vanguard",
        type = "composite",
        ricochetchance = 0.6,
        level = 6,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.2,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = false,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
    },

    deep_altyn = {
        isPlateCarrier = false,
        name = "deep_altyn",
        type = "composite",
        ricochetchance = 0.7,
        level = 7,
        aftereffectmultiplier  = 0.8,
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.2,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = true,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
    },

    deep_maska = {
        isPlateCarrier = false,
        name = "deep_maska",
        type = "composite",
        ricochetchance = 0.8,
        level = 7,
        aftereffectmultiplier  = 0.6,
        correctionaffliction = "deep_bullet_injury_head",
        correctionmultiplier = 0.1,
        enablecorrection = true,
        penresistance = 0.0,
        maxhits = 0,
        maxcondition = 0,
        ignoredamage = true,
        isHelmet = true,
        protectionarea = {
            [LimbType.Head] = true,
        },
        targetidentifier = "gunshotwound",
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