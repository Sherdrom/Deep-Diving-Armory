Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local config = Gunsmith.Config
local selections = {}
local appliedSignatures = {}
local lastScanTime = 0
local lastOpenDebugTime = 0

local function itemIdentifier(item)
    if not item or not item.Prefab then return nil end
    return item.Prefab.Identifier.Value
end

local function weaponConfig(item)
    local identifier = itemIdentifier(item)
    if not identifier then return nil end
    return config.weapons[identifier]
end

local function platformConfig(item)
    local weapon = weaponConfig(item)
    if not weapon then return nil end
    return config.platforms[weapon.platform]
end

local function copyDefaults(platform)
    local result = {}
    for slot, partId in pairs(platform.defaults) do
        result[slot] = partId
    end
    return result
end

local function getSelection(item)
    local platform = platformConfig(item)
    if not platform then return nil end

    local itemId = tostring(item.ID)
    if not selections[itemId] then
        selections[itemId] = copyDefaults(platform)
    end
    return selections[itemId]
end

local function getPartsForSlot(slot)
    local parts = {}
    for partId, part in pairs(config.parts) do
        if part.slot == slot then
            table.insert(parts, partId)
        end
    end
    table.sort(parts)
    return parts
end

local function buildSignature(selection, platform)
    local values = {}
    for _, slot in ipairs(platform.slots) do
        table.insert(values, slot .. ":" .. tostring(selection[slot] or ""))
    end
    return table.concat(values, ",")
end

local function buildLayerSpec(selection, platform)
    local layers = {}
    for _, slot in ipairs(platform.slots) do
        local partId = selection[slot]
        local part = config.parts[partId]
        if part then
            local source = part.source
            local offset = part.offset
            table.insert(layers, table.concat({
                partId,
                part.texture,
                string.format("%d,%d,%d,%d", source.x, source.y, source.w, source.h),
                string.format("%d,%d", offset.x, offset.y),
                tostring(part.order or 0)
            }, "|"))
        end
    end
    return table.concat(layers, ";")
end

function Gunsmith.Apply(item)
    if SERVER then return end
    if not item or item.removed then return end

    local platform = platformConfig(item)
    if not platform then return end

    local selection = getSelection(item)
    local signature = buildSignature(selection, platform)
    if appliedSignatures[item] == signature then return end

    local layerSpec = buildLayerSpec(selection, platform)
    if Hook and Hook.Call then
        Hook.Call("DeepGunsmithApply", item, signature, layerSpec, platform.canvas.w, platform.canvas.h)
        appliedSignatures[item] = signature
    else
        print("[Gunsmith] Hook.Call is unavailable; cannot apply composed sprite.")
    end
end

local function cyclePart(item, slot)
    local selection = getSelection(item)
    if not selection then return end

    local parts = getPartsForSlot(slot)
    if #parts == 0 then return end

    local current = selection[slot]
    local nextIndex = 1
    for index, partId in ipairs(parts) do
        if partId == current then
            nextIndex = index + 1
            break
        end
    end
    if nextIndex > #parts then nextIndex = 1 end

    selection[slot] = parts[nextIndex]
    appliedSignatures[item] = nil
    Gunsmith.Apply(item)
end

local function selectedHandWeapon(character)
    if not character or not character.Inventory then return nil end
    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    if weaponConfig(rightHand) then return rightHand end
    if weaponConfig(leftHand) then return leftHand end
    return nil
end

local function debugHeldWeapons(character)
    local currentTime = Timer.GetTime()
    if currentTime - lastOpenDebugTime < 0.5 then return end
    lastOpenDebugTime = currentTime

    if not character or not character.Inventory then
        print("[Gunsmith] G pressed, but local character/inventory is unavailable.")
        return
    end

    local rightHand = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftHand = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    local rightId = itemIdentifier(rightHand) or "none"
    local leftId = itemIdentifier(leftHand) or "none"
    print("[Gunsmith] G pressed. RightHand=" .. rightId .. ", LeftHand=" .. leftId)
end

function Gunsmith.Open(item)
    if SERVER then return end
    if not item or not platformConfig(item) then return end

    local ok, err = pcall(function()
        local platform = platformConfig(item)
        if not Hook or not Hook.Call then
            print("[Gunsmith] Hook.Call is unavailable; cannot open C# gunsmith UI.")
            return
        end

        local entries = {}
        for _, slot in ipairs(platform.slots) do
            local partId = getSelection(item)[slot]
            local part = config.parts[partId]
            local label = slot .. ": " .. (part and part.name or tostring(partId))
            table.insert(entries, slot .. "|" .. label)
        end

        print("[Gunsmith] Opening UI for " .. tostring(itemIdentifier(item)))
        Hook.Call("DeepGunsmithOpen", item, "Gunsmith: " .. itemIdentifier(item), table.concat(entries, ";"))
    end)

    if not ok then
        print("[Gunsmith] Failed to open v0 UI: " .. tostring(err))
    end
end

if CLIENT then
    Hook.Add("DeepGunsmithCycle", "DeepGunsmithCycle", function(...)
        local args = { ... }
        local item = nil
        local slot = nil

        for _, value in ipairs(args) do
            if LuaUserData.IsTargetType(value, "Barotrauma.Item") then
                item = value
            elseif type(value) == "string" then
                slot = value
            end
        end

        if item and slot then
            cyclePart(item, slot)
            Gunsmith.Open(item)
        end
    end)
end

if CLIENT then
    Hook.Patch("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
        if not PlayerInput or not Keys then return end
        local keyOk, keyHit = pcall(function() return PlayerInput.KeyHit(Keys.G) end)
        if not keyOk or not keyHit then return end

        local item = selectedHandWeapon(instance)
        if item then
            Gunsmith.Open(item)
        else
            debugHeldWeapons(instance)
        end
    end, Hook.HookMethodType.After)

    Hook.Add("think", "DeepGunsmithApplyDefaults", function()
        local currentTime = Timer.GetTime()
        if currentTime - lastScanTime < 1.0 then return end
        lastScanTime = currentTime

        if not Item or not Item.ItemList then return end
        for item in Item.ItemList do
            if weaponConfig(item) then
                Gunsmith.Apply(item)
            end
        end
    end)

    Hook.Add("item.removed", "DeepGunsmithCleanup", function(item)
        selections[tostring(item.ID)] = nil
        appliedSignatures[item] = nil
    end)
end
