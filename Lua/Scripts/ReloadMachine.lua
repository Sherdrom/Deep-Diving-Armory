--[[
Magazine Rework

Ammotype tag:  CASE SENSITIVE
lead,ti,phy,thu,tung,DU,cop
  0  1   2   3   4   5   6
magazine type tag:  CASE SENSITIVE
rifle,smg,pistol,drum,mg

]]

local ammotype = {
    ["lead"] = 0,
    ["ti"] = 1,
    ["phy"] = 2,
    ["thu"] = 3,
    ["tung"] = 4,
    ["DU"] = 5,
    ["cop"] = 6,
}

local totalslots = 8
local slots = totalslots / 2
local ActiveMachines = {}

local function identifyAmmoType(item)
    if item == nil then return -1 end
    for key,index in ammotype do                    --Result of no hard-coded stuff :(. We cant afford great performence cost so keep this table as clean as possible
        if item.HasTag(key) then return index end
    end
end

Hook.Add("Deep_UpdateReloadMachine", "Deep_UpdateReloadMachine",
    function(effect, deltaTime, item, targets, worldPosition)
        ActiveMachines[item] = {
            identifyAmmoType(item.OwnInventory.GetItemAt(0)),
            identifyAmmoType(item.OwnInventory.GetItemAt(1)),
            identifyAmmoType(item.OwnInventory.GetItemAt(2)),
            identifyAmmoType(item.OwnInventory.GetItemAt(3))
        }
    end
)

Hook.Add("Deep_Reload", "Deep_Reload",
    function(effect, deltaTime, item, targets, worldPosition)
        
    end
)