-- Exercise the production press hooks, including the unchanged condition-transfer path.
SERVER, CLIENT = true, false
Game = { IsMultiplayer = false }
local virtualType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
LuaUserData = {
    CreateStatic = function() return tostring end,
    RegisterType = function() end,
    MakeFieldAccessible = function() end,
    IsTargetType = function(value, typeName) return value.__type == typeName end,
}
Descriptors = { ["Barotrauma.Items.Components.CustomInterface"] = {} }
TextManager = { Get = function(key) return { Value = key .. " [loaded]/[total]" } end }
local callbacks, patches, now = {}, {}, 0
Hook = { Add = function(_, name, callback) callbacks[name] = callback end,
    Patch = function(name, _, _, _, callback) patches[name] = callback end, HookMethodType = { After = 1 } }
Timer = { GetTime = function() return now end }
Item = { ItemList = {} }
assert(loadfile("Lua/Scripts/PeachTechnology/ContainerConditionTransfer.lua"))()

local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 1e-6, message .. ": " .. tostring(actual))
end

local function item(id, tags, condition)
    local value = { Prefab = { Identifier = id }, Tags = tags, Condition = condition, __type = "Barotrauma.Item" }
    function value:HasTag(tag) return tags[tag] == true end
    return value
end

local function magazine(id, size, loaded, tag, ammoId, acceptLimit)
    local target = item(id, { [tag] = true, ["556mag"] = true }, loaded)
    local component = { __type = virtualType, MaxSize = size, LoadedCount = loaded, Rounds = {}, ExpectedAmmo = ammoId }
    for i = 1, loaded do component.Rounds[i] = ammoId end
    component.PushAmmoArray = function(rounds)
        for index, round in ipairs(rounds) do
            assert(round == component.ExpectedAmmo, "press loaded the wrong ammo type: " .. round)
            if component.LoadedCount < size and (not acceptLimit or index <= acceptLimit) then
                component.LoadedCount = component.LoadedCount + 1
                table.insert(component.Rounds, round)
            end
        end
        target.Condition = component.LoadedCount
    end
    target.OwnInventory = { Container = component }
    return target, component
end

local previousPress
local function start(sourceSlot, targetSlot, count)
    local interface = previousPress.GetComponentString("CustomInterface")
    for i, value in ipairs({ sourceSlot or 1, targetSlot or 1, count or 0 }) do
        interface.customInterfaceElementList[i].Signal = tostring(value)
    end
    callbacks["ContainerConditionTransfer.StartPress"](nil, 0, previousPress)
end

local function press(contents, options)
    options = options or {}
    if previousPress then previousPress.Removed = true end
    local machine = item("ammoreload_machine", { deep_condition_transfer = true }, 100)
    local sources, targets = {}, {}
    for _, value in ipairs(contents) do
        local collection = value.Prefab.Identifier:find("^ammobox") and sources or targets
        collection[#collection + 1] = value
    end
    machine.OwnInventory = { AllItemsMod = contents, GetItemAt = function(slot)
        if slot < 6 then return sources[slot + 1] end
        return targets[slot - 5]
    end }
    local interface = { customInterfaceElementList = { {}, {}, {} } }
    machine.GetComponentString = function() return interface end
    Item.ItemList = { machine }
    previousPress = machine
    callbacks["ContainerConditionTransfer.ScanLoaded"]()
    local targetSlot = options.target or 1
    if not options.target then
        for i, value in ipairs(targets) do
            local component = value.OwnInventory and value.OwnInventory.Container
            if component and component.LoadedCount < component.MaxSize then targetSlot = i; break end
        end
    end
    if options.start ~= false and targets[targetSlot].OwnInventory then
        start(options.source, targetSlot, options.count)
    end
    return machine, sources, targets
end

local function tick()
    now = now + 0.25
    callbacks["ContainerConditionTransfer.Update"]()
end

local target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
local source = item("ammobox1", {}, 100)
press({ target, source })
for _, expected in ipairs({ 7, 15, 22, 30 }) do
    tick()
    assert(mag.LoadedCount == expected, "fractional loading time was lost: " .. mag.LoadedCount .. " expected " .. expected)
end
close(source.Condition, 100 - 1.5625, "30-round magazine cost changed")
tick()
close(source.Condition, 100 - 1.5625, "full magazine consumed resources")

local full = target
target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
press({ full, target, source })
tick()
assert(mag.LoadedCount == 7, "full magazine blocked the next magazine")

target, mag = magazine("deep_5.56x45_expansion", 60, 0, "lead_ammobox_reload_2", "5.56x45round")
source = item("ammobox1", {}, 100)
press({ target, source })
for _ = 1, 4 do tick() end
assert(mag.LoadedCount == 60)
close(source.Condition, 100 - 3.125, "60-round drum cost changed")

local cost = 1.5625 / 30
target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
source = item("ammobox1", {}, cost * 2)
press({ target, source })
tick()
assert(mag.LoadedCount == 2, "source exhaustion overfilled the magazine")
close(source.Condition, 0, "source exhaustion charged incorrectly")

target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
source = item("ammobox1", {}, cost / 2)
press({ target, source })
tick()
assert(mag.LoadedCount == 0, "created an unaffordable round")
close(source.Condition, cost / 2, "charged for an incomplete round")

for _, accepted in ipairs({ 0, 3 }) do
    target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round", accepted)
    source = item("ammobox1", {}, 100)
    press({ target, source })
    tick()
    assert(mag.LoadedCount == accepted)
    close(source.Condition, 100 - accepted * cost, "charged for rejected rounds")
end

for _, case in ipairs({
    { "ammobox1", "5.56x45round" },
    { "ammobox_7.62", "5.56x45round_tit" },
    { "ammobox_12.7", "5.56x45round_phy" },
    { "ammobox_phy_ful", "556x45round_M995" },
    { "ammobox_tun_ful", "556x45round_SSA_AP" },
    { "ammobox_du", "556x45round_depleted_uranium" },
}) do
    target, mag = magazine("deep_5.56x45", 30, 2, "lead_ammobox_reload_4", case[2])
    mag.Rounds[1], mag.Rounds[2] = "5.56x45round", "556x45round_SSA_AP"
    source = item(case[1], {}, 100)
    press({ target, source })
    tick()
    assert(mag.LoadedCount == 9, "source box could not refill a different magazine variant: " .. case[1])
    assert(mag.Rounds[1] == "5.56x45round" and mag.Rounds[2] == "556x45round_SSA_AP",
        "refill changed the existing mixed ammo stack")
    close(source.Condition, 100 - 7 * cost, "mixed magazine charged incorrectly")
end

-- Empty drums also follow the source, with the original full-drum cost and duration.
target, mag = magazine("deep_556x45_expansion_phy", 60, 0, "phy_ammobox_reload_2", "5.56x45round_tit")
source = item("ammobox_7.62", {}, 100)
press({ target, source })
for _ = 1, 4 do tick() end
assert(mag.LoadedCount == 60)
close(source.Condition, 100 - 3.125, "changed ammo type changed the drum cost")

target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round_tit")
local residue, unsupported = item("ammobox1", {}, cost / 2), item("ammobox_rip", {}, 100)
local second = item("ammobox_12.7", {}, 100)
source = item("ammobox_7.62", {}, 100)
press({ target, residue, unsupported, source, second }, { source = 3 })
tick()
assert(mag.LoadedCount == 7, "multiple boxes accelerated loading or a residue blocked loading")
close(residue.Condition, cost / 2, "charged an unaffordable source")
close(unsupported.Condition, 100, "consumed an unsupported box")
close(second.Condition, 100, "consumed more than one source in a tick")
source.Condition = 0
mag.ExpectedAmmo = "5.56x45round_phy"
tick()
assert(mag.LoadedCount == 7, "silently switched to a different ammo box")
start(4)
tick()
assert(mag.LoadedCount == 14 and mag.Rounds[7] == "5.56x45round_tit"
    and mag.Rounds[8] == "5.56x45round_phy", "selected source change reset the stack")
close(second.Condition, 100 - 7 * cost, "source change charged incorrectly")

target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
press({ target, unsupported })
tick()
assert(mag.LoadedCount == 0, "unsupported box created ammo")
close(unsupported.Condition, 100, "unsupported box lost condition")

target = item("external_virtual_magazine", { lead_ammobox_reload_4 = true }, 0)
target.OwnInventory = { Container = { __type = virtualType, MaxSize = 30, LoadedCount = 0 } }
source = item("ammobox1", {}, 100)
press({ target, source })
tick()
close(target.Condition, 0, "modified an unsupported virtual magazine")
close(source.Condition, 100, "charged for an unsupported virtual magazine")

target = item("legacy_magazine", { lead_ammobox_reload_4 = true }, 0)
press({ target, second })
tick()
close(target.Condition, 0, "legacy magazine accepted the wrong box")
source = item("ammobox1", {}, 100)
press({ target, source })
tick()
close(target.Condition, 25, "legacy condition transfer changed")
close(source.Condition, 100 - 1.5625 / 4, "legacy resource cost changed")

target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
source = item("ammobox1", {}, 100)
press({ target, source }, { start = false })
tick()
assert(mag.LoadedCount == 0, "started loading before the player selected a batch")
for _, count in ipairs({ -1, 61, 1.5, "invalid" }) do
    start(1, 1, count)
    tick()
    assert(mag.LoadedCount == 0, "accepted an invalid batch size")
end
start(0, 1, 5)
tick()
assert(mag.LoadedCount == 0, "accepted an invalid source slot")
start(1, 7, 5)
tick()
assert(mag.LoadedCount == 0, "accepted an invalid target slot")
start(1, 1, 2)
tick()
tick()
assert(mag.LoadedCount == 2, "exceeded requested rounds or resumed after completion")
close(source.Condition, 100 - 2 * cost, "batch cost incorrect")

start(1, 1, 20)
tick()
assert(mag.LoadedCount == 9)
start(1, 1, 20)
for _ = 1, 3 do tick() end
assert(mag.LoadedCount == 22, "repeated start extended the active batch")
start(1, 1, 20)
tick()
callbacks["ContainerConditionTransfer.StopPress"](nil, 0, previousPress)
local stopped = mag.LoadedCount
for _ = 1, 4 do tick() end
assert(mag.LoadedCount == stopped, "stop continued loading")

target, mag = magazine("deep_5.56x45", 30, 0, "lead_ammobox_reload_4", "5.56x45round")
source = item("ammobox1", {}, 100)
local machine, sources, targets = press({ target, source })
tick()
targets[1] = nil
tick()
targets[1] = target
tick()
assert(mag.LoadedCount == 7, "removed/reinserted target resumed an old job")
start()
patches["ContainerConditionTransfer.CancelRemoved"]({ Item = machine }, { containedItem = source })
tick()
assert(mag.LoadedCount == 7, "removal callback did not cancel immediately")
start()
sources[1] = item("ammobox1", {}, 100)
tick()
assert(mag.LoadedCount == 7, "replacement source inherited a job")

Game.IsMultiplayer = true
start()
tick()
assert(mag.LoadedCount == 7, "started an unsupported multiplayer batch")
print("ok: selected ammo/batches, start/stop, resources, cancellation, bounds and legacy transfers")
