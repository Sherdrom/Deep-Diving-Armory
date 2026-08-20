local patches = {}
local patchCalls = {}
local timers = {}
local accessible = {}

Hook = {
    HookMethodType = { After = "After" },
    Patch = function(identifier, className, methodName, parameterTypes, callback, patchType)
        patchCalls[#patchCalls + 1] = {
            identifier = identifier,
            className = className,
            methodName = methodName,
            parameterTypes = parameterTypes,
            patchType = patchType,
        }
        assert(patchType == Hook.HookMethodType.After)
        patches[className .. "." .. methodName] = callback
    end,
}

Timer = {
    Wait = function(callback, delay)
        assert(delay == 1)
        timers[#timers + 1] = callback
    end,
}

Descriptors = {
    ["Barotrauma.Items.Components.CustomInterface"] = {},
}
LuaUserData = {
    MakeFieldAccessible = function(descriptor, name)
        accessible.field = { descriptor, name }
    end,
    MakePropertyAccessible = function(descriptor, name)
        accessible.property = { descriptor, name }
    end,
}

dofile("Lua/Scripts/BenzeneTechnology/TacticalHelmetInterface.lua")

assert(accessible.field[1] == Descriptors["Barotrauma.Items.Components.CustomInterface"])
assert(accessible.field[2] == "customInterfaceElementList")
assert(accessible.property[1] == Descriptors["Barotrauma.Items.Components.CustomInterface"])
assert(accessible.property[2] == "DrawHudWhenEquipped")

assert(#patchCalls == 4)
local expectedPatches = {
    {
        identifier = "DeepDivingArmory.TacticalHelmetInterface.TickBoxToggled",
        className = "Barotrauma.Items.Components.CustomInterface",
        methodName = "TickBoxToggled",
        parameterTypes = {
            "Barotrauma.Items.Components.CustomInterface+CustomInterfaceElement",
            "System.Boolean",
        },
    },
    {
        identifier = "DeepDivingArmory.TacticalHelmetInterface.OnItemLoaded",
        className = "Barotrauma.Items.Components.CustomInterface",
        methodName = "OnItemLoaded",
        parameterTypes = {},
    },
    {
        identifier = "DeepDivingArmory.TacticalHelmetInterface.OnItemContained",
        className = "Barotrauma.Items.Components.ItemContainer",
        methodName = "OnItemContained",
        parameterTypes = { "Barotrauma.Item", "System.Boolean" },
    },
    {
        identifier = "DeepDivingArmory.TacticalHelmetInterface.OnItemRemoved",
        className = "Barotrauma.Items.Components.ItemContainer",
        methodName = "OnItemRemoved",
        parameterTypes = { "Barotrauma.Item" },
    },
}
for index, expected in ipairs(expectedPatches) do
    local actual = patchCalls[index]
    assert(actual.identifier == expected.identifier)
    assert(actual.className == expected.className)
    assert(actual.methodName == expected.methodName)
    assert(actual.patchType == Hook.HookMethodType.After)
    assert(#actual.parameterTypes == #expected.parameterTypes)
    for parameterIndex, parameterType in ipairs(expected.parameterTypes) do
        assert(actual.parameterTypes[parameterIndex] == parameterType)
    end
end

local function runTimers()
    local queued = timers
    timers = {}
    for _, callback in ipairs(queued) do callback() end
end

local function makeParameterTable(values)
    return setmetatable({}, { __index = values })
end

local function makeElement(state)
    return {
        State = state,
        StatusEffects = {
            { type = 2, id = "use-1" },
            { type = 3, id = "secondary" },
            { type = 2, id = "use-2" },
        },
    }
end

local function makeModule(isTactical)
    return {
        HasTag = function(tag)
            return isTactical and tag == "deep_helmet_tac"
        end,
    }
end

local function makeItem(identifier, element, slot0, interfaceTag)
    local customInterface = {
        customInterfaceElementList = { element },
        DrawHudWhenEquipped = nil,
    }
    local item = {
        Prefab = { Identifier = identifier },
        applied = {},
        slot0 = slot0,
    }
    if interfaceTag then
        item.HasTag = function(tag)
            return tag == interfaceTag
        end
    end
    item.OwnInventory = {
        GetItemAt = function(index)
            assert(index == 0)
            return item.slot0
        end,
    }
    customInterface.Item = item
    item.GetComponentString = function(name)
        assert(name == "CustomInterface")
        return customInterface
    end
    function item.ApplyStatusEffect(effect, actionType, deltaTime, character, limb, useTarget, network, checkCondition)
        assert(deltaTime == 1.0 and character == nil and limb == nil and useTarget == nil)
        assert(network == true and checkCondition == false)
        item.applied[#item.applied + 1] = { id = effect.id, effect = effect, type = actionType }
    end
    return item, customInterface
end

local toggle = patches["Barotrauma.Items.Components.CustomInterface.TickBoxToggled"]
local loaded = patches["Barotrauma.Items.Components.CustomInterface.OnItemLoaded"]
local contained = patches["Barotrauma.Items.Components.ItemContainer.OnItemContained"]
local removed = patches["Barotrauma.Items.Components.ItemContainer.OnItemRemoved"]
assert(toggle and loaded and contained and removed)

local element = makeElement(true)
local item, customInterface = makeItem("6b47", element)
loaded(customInterface)
assert(customInterface.DrawHudWhenEquipped == false, "load without a module must hide the interface")
runTimers()
assert(#item.applied == 2
    and item.applied[1].id == "use-1" and item.applied[1].type == 2
    and item.applied[2].id == "use-2" and item.applied[2].type == 2)

item.applied = {}
element.State = false
toggle(customInterface, makeParameterTable({ tickBoxElement = element }))
assert(#item.applied == 0, "toggle must be deferred")
runTimers()
assert(#item.applied == 1 and item.applied[1].id == "secondary" and item.applied[1].type == 3)

item.applied = {}
element.State = true
toggle(customInterface, makeParameterTable({ tickBoxElement = element }))
element.State = false
toggle(customInterface, makeParameterTable({ tickBoxElement = element }))
assert(#timers == 1, "pending elements must merge")
runTimers()
assert(#item.applied == 1 and item.applied[1].id == "secondary")

local tacticalModule = makeModule(true)
item.slot0 = tacticalModule
item.applied = {}
contained({ Item = item }, makeParameterTable({ containedItem = tacticalModule }))
assert(customInterface.DrawHudWhenEquipped == true, "inserting a module must show the interface")
runTimers()
assert(#item.applied == 1 and item.applied[1].id == "secondary")

item.slot0 = nil
removed({ Item = item }, makeParameterTable({ containedItem = tacticalModule }))
assert(customInterface.DrawHudWhenEquipped == false, "removing the module must hide the interface")
assert(#timers == 0, "removal must not reapply the toggle effects")

item.slot0 = makeModule(true)
removed({ Item = item }, makeParameterTable({ containedItem = tacticalModule }))
assert(customInterface.DrawHudWhenEquipped == true, "a replacement module in slot 0 must keep the interface visible")

local preloadedItem, preloadedInterface = makeItem("deep_fast_helmet", makeElement(true), makeModule(true))
loaded(preloadedInterface)
assert(preloadedInterface.DrawHudWhenEquipped == true, "a preloaded module must be detected on load")
runTimers()

local function assertMaskBridge(identifier)
    local maskElement = makeElement(true)
    local maskItem, maskInterface = makeItem(identifier, maskElement)
    loaded(maskInterface)
    assert(maskInterface.DrawHudWhenEquipped == nil, "a mask must not use tactical visibility")
    runTimers()
    assert(#maskItem.applied == 2
        and maskItem.applied[1].id == "use-1" and maskItem.applied[1].type == 2
        and maskItem.applied[2].id == "use-2" and maskItem.applied[2].type == 2,
        identifier .. " load must replay OnUse effects")

    maskItem.applied = {}
    maskElement.State = false
    toggle(maskInterface, makeParameterTable({ tickBoxElement = maskElement }))
    runTimers()
    assert(#maskItem.applied == 1 and maskItem.applied[1].id == "secondary" and maskItem.applied[1].type == 3,
        identifier .. " false toggle must replay OnSecondaryUse")

    maskItem.applied = {}
    maskElement.State = true
    toggle(maskInterface, makeParameterTable({ tickBoxElement = maskElement }))
    runTimers()
    assert(#maskItem.applied == 2
        and maskItem.applied[1].id == "use-1" and maskItem.applied[1].type == 2
        and maskItem.applied[2].id == "use-2" and maskItem.applied[2].type == 2,
        identifier .. " true toggle must replay OnUse effects")
end

assertMaskBridge("deep_altyn")
assertMaskBridge("deep_maska")

local thirdPartyTactical, thirdPartyTacticalInterface = makeItem(
    "third_party_tactical_helmet",
    makeElement(true),
    makeModule(true),
    "deep_tactical_helmet_interface"
)
loaded(thirdPartyTacticalInterface)
assert(thirdPartyTacticalInterface.DrawHudWhenEquipped == true,
    "the tactical opt-in tag must enable HUD visibility")
runTimers()
assert(#thirdPartyTactical.applied == 2
    and thirdPartyTactical.applied[1].type == 2
    and thirdPartyTactical.applied[2].type == 2,
    "the tactical opt-in tag must replay interface state")

local thirdPartyMask, thirdPartyMaskInterface = makeItem(
    "third_party_mask",
    makeElement(true),
    nil,
    "deep_tactical_mask_interface"
)
thirdPartyMaskInterface.DrawHudWhenEquipped = "unchanged"
loaded(thirdPartyMaskInterface)
assert(thirdPartyMaskInterface.DrawHudWhenEquipped == "unchanged",
    "the mask opt-in tag must not change HUD visibility")
runTimers()
assert(#thirdPartyMask.applied == 2
    and thirdPartyMask.applied[1].type == 2
    and thirdPartyMask.applied[2].type == 2,
    "the mask opt-in tag must replay interface state")

local unmarkedThirdParty, unmarkedThirdPartyInterface = makeItem(
    "third_party_unmarked",
    makeElement(true),
    makeModule(true),
    "some_other_tag"
)
loaded(unmarkedThirdPartyInterface)
assert(unmarkedThirdPartyInterface.DrawHudWhenEquipped == nil
    and #timers == 0
    and #unmarkedThirdParty.applied == 0,
    "an unmarked third-party item must remain ignored")

local testItem, testInterface = makeItem("6b47_test_18", makeElement(false), makeModule(true))
loaded(testInterface)
assert(testInterface.DrawHudWhenEquipped == true, "the loaded test helmet must use the event bridge")
runTimers()

local otherItem, otherInterface = makeItem("not_a_target", makeElement(true), tacticalModule)
loaded(otherInterface)
contained({ Item = otherItem }, makeParameterTable({ containedItem = tacticalModule }))
otherItem.slot0 = nil
removed({ Item = otherItem }, makeParameterTable({ containedItem = tacticalModule }))
assert(otherInterface.DrawHudWhenEquipped == nil and #timers == 0 and #otherItem.applied == 0)

print("TacticalHelmetInterface check OK")
