Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Validation = {}
Gunsmith.Validation = Validation

local oldPartFields = { "texture", "source", "offset", "order", "itemIdentifier" }

local function isArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" then return false end
        if key > count then count = key end
    end
    for index = 1, count do
        if value[index] == nil then return false end
    end
    return true
end

local function hasStringArray(value)
    if not isArray(value) or #value == 0 then return false end
    for _, entry in ipairs(value) do
        if type(entry) ~= "string" or entry == "" then return false end
    end
    return true
end

local function addSetValues(set, values)
    if type(values) ~= "table" then return end
    for _, value in ipairs(values) do
        set[value] = true
    end
end

local function hasAnyProvidedPart(parts, accepts)
    if type(parts) ~= "table" or type(accepts) ~= "table" then return false end
    for _, part in pairs(parts) do
        if type(part.provides) == "table" then
            for _, provided in ipairs(part.provides) do
                for _, accepted in ipairs(accepts) do
                    if provided == accepted then return true end
                end
            end
        end
    end
    return false
end

local function visualComplete(visual)
    if type(visual) ~= "table" then return false end
    local source = visual.source
    local offset = visual.offset
    return type(visual.texture) == "string" and visual.texture ~= "" and
        type(source) == "table" and type(source.x) == "number" and type(source.y) == "number" and
        type(source.w) == "number" and type(source.h) == "number" and
        type(offset) == "table" and type(offset.x) == "number" and type(offset.y) == "number"
end

local function validOptionalScale(value)
    return value == nil or (type(value) == "number" and value > 0)
end

local function validOptionalPoint(value)
    return value == nil or (type(value) == "table" and type(value.x) == "number" and type(value.y) == "number")
end

local function itemPrefabExists(identifier)
    if not identifier or identifier == "" then return true end
    if not ItemPrefab or not ItemPrefab.GetItemPrefab then return true end
    local ok, prefab = pcall(function()
        return ItemPrefab.GetItemPrefab(identifier)
    end)
    return ok and prefab ~= nil
end

local function reportPrefix(label, level)
    local prefix = "[Gunsmith][Validation]"
    if label and label ~= "" then
        prefix = prefix .. "[" .. tostring(label) .. "]"
    end
    if level then
        prefix = prefix .. "[" .. level .. "]"
    end
    return prefix
end

local function printReport(errors, warnings, label)
    for _, message in ipairs(errors) do
        print(reportPrefix(label, "ERROR") .. " " .. message)
    end
    for _, message in ipairs(warnings) do
        print(reportPrefix(label, "WARN") .. " " .. message)
    end
    print(string.format("%s %d errors, %d warnings.", reportPrefix(label), #errors, #warnings))
end

function Validation.Run(configOverride, label)
    local errors = {}
    local warnings = {}
    local config = configOverride or Gunsmith.Config

    if type(config) ~= "table" then
        table.insert(errors, "Missing Gunsmith.Config.")
        printReport(errors, warnings, label)
        return false
    end

    local platforms = config.platforms
    local weapons = config.weapons
    local parts = config.parts
    if type(platforms) ~= "table" then table.insert(errors, "Missing Gunsmith.Config.platforms.") end
    if type(weapons) ~= "table" then table.insert(errors, "Missing Gunsmith.Config.weapons.") end
    if type(parts) ~= "table" then table.insert(errors, "Missing Gunsmith.Config.parts.") end
    if #errors > 0 then
        printReport(errors, warnings, label)
        return false
    end

    local defaultParts = {}
    local acceptedTypes = {}
    local providedTypes = {}

    for platformId, platform in pairs(platforms) do
        if type(platform) ~= "table" then
            table.insert(errors, "Platform '" .. tostring(platformId) .. "' must be a table.")
        else
            if type(platform.slots) ~= "table" then table.insert(errors, "Platform '" .. platformId .. "' is missing slots.") end
            if type(platform.defaults) ~= "table" then table.insert(errors, "Platform '" .. platformId .. "' is missing defaults.") end
            if type(platform.canvas) ~= "table" or type(platform.canvas.w) ~= "number" or type(platform.canvas.h) ~= "number" then
                table.insert(errors, "Platform '" .. platformId .. "' is missing canvas.w/h.")
            end
            if not validOptionalScale(platform.visualScale) then
                table.insert(errors, "Platform '" .. platformId .. "' visualScale must be a positive number.")
            end
            if not validOptionalPoint(platform.visualOrigin) then
                table.insert(errors, "Platform '" .. platformId .. "' visualOrigin must contain numeric x/y.")
            end
            if type(platform.rootAccepts) ~= "table" then
                table.insert(errors, "Platform '" .. platformId .. "' is missing rootAccepts.")
            end

            if type(platform.slots) == "table" and type(platform.defaults) == "table" then
                local rootSlots = {}
                for _, slot in ipairs(platform.slots) do
                    rootSlots[slot] = true
                    local accepts = platform.rootAccepts and platform.rootAccepts[slot] or nil
                    if not hasStringArray(accepts) then
                        table.insert(errors, "Platform '" .. platformId .. "' root slot '" .. tostring(slot) .. "' is missing rootAccepts entry.")
                    else
                        addSetValues(acceptedTypes, accepts)
                    end
                end

                for slot, partId in pairs(platform.defaults) do
                    if not rootSlots[slot] then
                        table.insert(errors, "Platform '" .. platformId .. "' default slot '" .. tostring(slot) .. "' is not a root slot.")
                    end
                    defaultParts[partId] = true
                    local part = parts[partId]
                    if not part then
                        table.insert(errors, "Platform '" .. platformId .. "' default part '" .. tostring(partId) .. "' does not exist.")
                    elseif part.slot ~= slot then
                        table.insert(errors, "Default part '" .. tostring(partId) .. "' slot does not match '" .. tostring(slot) .. "'.")
                    end
                end
            end
        end
    end

    for weaponId, weapon in pairs(weapons) do
        local platformId = type(weapon) == "table" and weapon.platform or nil
        if type(weapon) ~= "table" or type(platformId) ~= "string" or not platforms[platformId] then
            table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' references missing platform '" .. tostring(platformId) .. "'.")
        end
        if type(weapon) == "table" and not validOptionalScale(weapon.scale) then
            table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' scale must be a positive number.")
        end
    end

    for partId, part in pairs(parts) do
        if type(part) ~= "table" then
            table.insert(errors, "Part '" .. tostring(partId) .. "' must be a table.")
        else
            if type(part.slot) ~= "string" or part.slot == "" then table.insert(errors, "Part '" .. partId .. "' is missing slot.") end
            if type(part.name) ~= "string" or part.name == "" then table.insert(errors, "Part '" .. partId .. "' is missing name.") end
            if not hasStringArray(part.provides) then
                table.insert(errors, "Part '" .. partId .. "' is missing provides.")
            else
                addSetValues(providedTypes, part.provides)
            end

            for _, field in ipairs(oldPartFields) do
                if part[field] ~= nil then
                    table.insert(errors, "Part '" .. partId .. "' uses removed field '" .. field .. "'.")
                end
            end

            if part.visual ~= nil and not visualComplete(part.visual) then
                table.insert(errors, "Part '" .. partId .. "' has incomplete visual data.")
            end
            if part.visual ~= nil and not validOptionalScale(part.visual.scale) then
                table.insert(errors, "Part '" .. partId .. "' visual.scale must be a positive number.")
            end

            local item = part.item
            if not defaultParts[partId] then
                if type(item) ~= "table" or (type(item.identifier) ~= "string" and item.virtual ~= true) then
                    table.insert(errors, "Non-default part '" .. partId .. "' must declare item.identifier or item.virtual = true.")
                end
            end

            if type(item) == "table" and type(item.identifier) == "string" and not itemPrefabExists(item.identifier) then
                table.insert(warnings, "Part '" .. partId .. "' item prefab not found: " .. item.identifier)
            end

            if part.mounts ~= nil then
                if not isArray(part.mounts) then
                    table.insert(errors, "Part '" .. partId .. "' mounts must be an array.")
                else
                    for index, mount in ipairs(part.mounts) do
                        local label = "Part '" .. partId .. "' mount #" .. tostring(index)
                        if type(mount.slot) ~= "string" or mount.slot == "" then
                            table.insert(errors, label .. " is missing slot.")
                        end
                        if not hasStringArray(mount.accepts) then
                            table.insert(errors, label .. " is missing accepts.")
                        else
                            addSetValues(acceptedTypes, mount.accepts)
                            if not hasAnyProvidedPart(parts, mount.accepts) then
                                table.insert(warnings, label .. " accepts no currently provided part type.")
                            end
                        end
                    end
                end
            end
        end
    end

    for platformId, platform in pairs(platforms) do
        if type(platform) == "table" and type(platform.rootAccepts) == "table" then
            for slot, accepts in pairs(platform.rootAccepts) do
                if hasStringArray(accepts) and not hasAnyProvidedPart(parts, accepts) then
                    table.insert(warnings, "Platform '" .. platformId .. "' rootAccepts for '" .. tostring(slot) .. "' has no matching part.")
                end
            end
        end
    end

    for provided, _ in pairs(providedTypes) do
        if not acceptedTypes[provided] then
            table.insert(warnings, "Provided type '" .. provided .. "' is not accepted by any root slot or mount.")
        end
    end

    printReport(errors, warnings, label)
    return #errors == 0
end

function Validation.RunSelfTest()
    local badConfig = {
        platforms = {
            broken = {
                slots = { "receiver" },
                defaults = {
                    receiver = "missing_default_part"
                },
                canvas = { w = 512, h = 160 },
                visualScale = -1,
                visualOrigin = { x = "bad", y = 80 },
                rootAccepts = {
                    receiver = { "test_receiver" }
                }
            }
        },
        weapons = {
            bad_platform = {
                platform = "missing_platform"
            },
            bad_scale = {
                platform = "broken",
                scale = 0
            }
        },
        parts = {
            old_field_part = {
                slot = "receiver",
                name = "Old Field Part",
                provides = { "test_receiver" },
                texture = "removed_field"
            },
            bad_visual_part = {
                slot = "receiver",
                name = "Bad Visual Part",
                provides = { "test_receiver" },
                item = { virtual = true },
                visual = {
                    texture = "missing_offset",
                    source = { x = 0, y = 0, w = 16, h = 16 }
                }
            },
            no_item_part = {
                slot = "receiver",
                name = "No Item Part",
                provides = { "test_receiver" }
            },
            missing_prefab_part = {
                slot = "receiver",
                name = "Missing Prefab Part",
                provides = { "test_receiver" },
                item = { identifier = "deep_gunsmith_validation_missing_prefab" }
            },
            bad_mount_part = {
                slot = "receiver",
                name = "Bad Mount Part",
                provides = { "unused_test_type" },
                item = { virtual = true },
                mounts = {
                    { slot = "optic_mount" }
                }
            }
        }
    }

    print("[Gunsmith][Validation][SelfTest] Running intentional broken-config validation test.")
    return Validation.Run(badConfig, "SelfTest")
end

function Validation.RegisterCommands()
    if Validation.CommandsRegistered or not Game or not Game.AddCommand then return end
    Validation.CommandsRegistered = true

    Game.AddCommand("DeepGunsmithValidate", "Run GunSmith config validation", function()
        Validation.Run()
    end, nil, false)

    Game.AddCommand("DeepGunsmithValidationSelfTest", "Run intentional GunSmith validation errors without changing real config", function()
        Validation.RunSelfTest()
    end, nil, false)
end
