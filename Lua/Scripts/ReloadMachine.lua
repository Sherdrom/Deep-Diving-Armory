LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.ItemContainer"], "slotRestrictions")

--[[
Magazine Rework

Ammotype tag:  CASE SENSITIVE
lead,ti,phy,thu,tung,DU,cop
  0  1   2   3   4   5   6

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


local ActiveMachines = {}

local function identifyAmmoType(item)
    if item == nil then return -1 end
    for key,index in ammotype do                    --Result of no hard-coded stuff :(. We cant afford great performence cost so keep this table as clean as possible
        if item.HasTag(key) then return index end
    end
end

Hook.Add("Deep_UpdateReloadMachine", "Deep_UpdateReloadMachine",
    function(effect, deltaTime, item, targets, worldPosition)
        local slotrestrictions = item.OwnInventory.SlotRestrictions
        local availableammo = {}
        for index = 0, #slotrestrictions / 2, 1 do
            availableammo[index] = identifyAmmoType(item.OwnInventory.GetItemAt(index))
        end
    end
)

Hook.Add("Deep_Reload", "Deep_Reload",
    function(effect, deltaTime, item, targets, worldPosition)
        
    end
)