local TARGET_ITEMS = {
    ["6b47"] = true,
    ["6b47_test_18"] = true,
    ["deep_fast_helmet"] = true,
    ["deep_helmet_ranger"] = true,
    ["deep_helmet_heavy_trooper"] = true,
    ["deep_helmet_sledge_hammer"] = true,
    ["deep_fast_helmet_black"] = true,
    ["deep_fast_helmet_ghost_origin"] = true,
}

local pending = setmetatable({}, { __mode = "k" })

local descriptor = Descriptors and Descriptors["Barotrauma.Items.Components.CustomInterface"]
if LuaUserData and descriptor then
    if LuaUserData.MakeFieldAccessible then
        LuaUserData.MakeFieldAccessible(descriptor, "customInterfaceElementList")
    end
    if LuaUserData.MakePropertyAccessible then
        LuaUserData.MakePropertyAccessible(descriptor, "DrawHudWhenEquipped")
    end
end

local function isTarget(item)
    local prefab = item and item.Prefab
    return prefab and TARGET_ITEMS[tostring(prefab.Identifier)] == true
end

local function each(value, callback)
    if not value then return end
    if type(value) == "table" then
        for _, entry in ipairs(value) do callback(entry) end
    else
        for entry in value do callback(entry) end
    end
end

local function syncVisibility(item, customInterface)
    if not isTarget(item) or not customInterface then return end
    local inventory = item.OwnInventory
    local module = inventory and inventory.GetItemAt and inventory.GetItemAt(0)
    local hasTac = module ~= nil and module.HasTag and module.HasTag("deep_helmet_tac") or false
    customInterface.DrawHudWhenEquipped = hasTac
end

local function applyCurrentState(item, element)
    local wanted = element.State and 2 or 3
    each(element.StatusEffects, function(effect)
        if tonumber(effect.type) == wanted then
            item.ApplyStatusEffect(effect, effect.type, 1.0, nil, nil, nil, true, false)
        end
    end)
end

local function queue(item, element)
    if not item or not element or pending[element] then return end
    pending[element] = item
    Timer.Wait(function()
        local queuedItem = pending[element]
        pending[element] = nil
        if queuedItem then applyCurrentState(queuedItem, element) end
    end, 1)
end

local function queueAll(item, customInterface)
    if not isTarget(item) or not customInterface then return end
    each(customInterface.customInterfaceElementList, function(element)
        queue(item, element)
    end)
end

local function onTickBoxToggled(instance, ptable)
    local element = ptable and ptable["tickBoxElement"]
    if isTarget(instance and instance.Item) then
        queue(instance.Item, element)
    end
end

local function onItemLoaded(instance)
    local item = instance and instance.Item
    if isTarget(item) then
        syncVisibility(item, instance)
        queueAll(item, instance)
    end
end

local function onItemContained(instance, ptable)
    local containedItem = ptable and ptable["containedItem"]
    if not containedItem or not containedItem.HasTag("deep_helmet_tac") then return end
    local item = instance and instance.Item
    if isTarget(item) then
        local customInterface = item.GetComponentString("CustomInterface")
        syncVisibility(item, customInterface)
        queueAll(item, customInterface)
    end
end

local function onItemRemoved(instance, ptable)
    local containedItem = ptable and ptable["containedItem"]
    if not containedItem or not containedItem.HasTag("deep_helmet_tac") then return end
    local item = instance and instance.Item
    if isTarget(item) then
        syncVisibility(item, item.GetComponentString("CustomInterface"))
    end
end

Hook.Patch(
    "DeepDivingArmory.TacticalHelmetInterface.TickBoxToggled",
    "Barotrauma.Items.Components.CustomInterface",
    "TickBoxToggled",
    { "Barotrauma.Items.Components.CustomInterface+CustomInterfaceElement", "System.Boolean" },
    onTickBoxToggled,
    Hook.HookMethodType.After
)

Hook.Patch(
    "DeepDivingArmory.TacticalHelmetInterface.OnItemLoaded",
    "Barotrauma.Items.Components.CustomInterface",
    "OnItemLoaded",
    {},
    onItemLoaded,
    Hook.HookMethodType.After
)

Hook.Patch(
    "DeepDivingArmory.TacticalHelmetInterface.OnItemContained",
    "Barotrauma.Items.Components.ItemContainer",
    "OnItemContained",
    { "Barotrauma.Item", "System.Boolean" },
    onItemContained,
    Hook.HookMethodType.After
)

Hook.Patch(
    "DeepDivingArmory.TacticalHelmetInterface.OnItemRemoved",
    "Barotrauma.Items.Components.ItemContainer",
    "OnItemRemoved",
    { "Barotrauma.Item" },
    onItemRemoved,
    Hook.HookMethodType.After
)
