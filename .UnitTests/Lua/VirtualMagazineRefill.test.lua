-- Exercise the production press hooks, including the unchanged condition-transfer path.
SERVER, CLIENT = true, false
Game = { IsMultiplayer = false }
local virtualType = "VCE_VirtualizedMagazine.VirtualizedMagazine"
LuaUserData = {
    CreateStatic = function() return tostring end,
    RegisterType = function() end,
    IsTargetType = function(value, typeName) return value.__type == typeName end,
}
local callbacks, now = {}, 0
Hook = { Add = function(_, name, callback) callbacks[name] = callback end }
Timer = { GetTime = function() return now end }
Item = { ItemList = {} }
assert(loadfile("Lua/Scripts/PeachTechnology/ContainerConditionTransfer.lua"))()

local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 1e-6, message .. ": " .. tostring(actual))
end

local function item(id, tags, condition)
    local value = { Prefab = { Identifier = id }, Condition = condition, __type = "Barotrauma.Item" }
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
local function press(contents)
    if previousPress then previousPress.Removed = true end
    local machine = item("ammoreload_machine", { deep_condition_transfer = true }, 100)
    machine.OwnInventory = { AllItemsMod = contents }
    Item.ItemList = { machine }
    previousPress = machine
    callbacks["ContainerConditionTransfer.ScanLoaded"]()
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
press({ target, residue, unsupported, source, second })
tick()
assert(mag.LoadedCount == 7, "multiple boxes accelerated loading or a residue blocked loading")
close(residue.Condition, cost / 2, "charged an unaffordable source")
close(unsupported.Condition, 100, "consumed an unsupported box")
close(second.Condition, 100, "consumed more than one source in a tick")
source.Condition = 0
mag.ExpectedAmmo = "5.56x45round_phy"
tick()
assert(mag.LoadedCount == 15 and mag.Rounds[7] == "5.56x45round_tit"
    and mag.Rounds[8] == "5.56x45round_phy", "source change reset the stack or loading progress")
close(second.Condition, 100 - 8 * cost, "source change charged incorrectly")

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

print("ok: source-driven mixed ammo refill, capacity, timing, resource cost and legacy transfers")
