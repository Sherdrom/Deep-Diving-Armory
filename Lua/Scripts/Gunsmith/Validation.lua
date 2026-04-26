Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local Gunsmith = Deep_Lua.Gunsmith
local Validation = {}
Gunsmith.Validation = Validation

local oldPartFields = { "texture", "source", "offset", "order", "itemIdentifier", "slot" }
local oldConfigFields = { "defaults", "rootAccepts", "slots", "requiredRootSlots", "hiddenRootSlots", "slotNames" }
local knownStatFields = {
    weight = true,
    ergonomics = true,
    recoilControl = true,
    spreadReduction = true,
    fireRateMultiplier = true,
    damageMultiplier = true
}

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

local function partProvidesAccepted(part, accepts)
    if type(part) ~= "table" or type(part.provides) ~= "table" or type(accepts) ~= "table" then return false end
    for _, provided in ipairs(part.provides) do
        for _, accepted in ipairs(accepts) do
            if provided == accepted then return true end
        end
    end
    return false
end

local function validOptionalPoint(value)
    return value == nil or (type(value) == "table" and type(value.x) == "number" and type(value.y) == "number")
end

local function visualComplete(visual)
    if type(visual) ~= "table" then return false end
    local source = visual.source
    local attachPoint = visual.attachPoint
    local relativeOffset = visual.relativeOffset
    return type(visual.texture) == "string" and visual.texture ~= "" and
        type(source) == "table" and type(source.x) == "number" and type(source.y) == "number" and
        type(source.w) == "number" and type(source.h) == "number" and
        (validOptionalPoint(attachPoint) and validOptionalPoint(relativeOffset)) and
        (attachPoint ~= nil or relativeOffset ~= nil)
end

local function validOptionalScale(value)
    return value == nil or (type(value) == "number" and value > 0)
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

local function mountForPath(part, path)
    if type(part) ~= "table" or type(part.mounts) ~= "table" then return nil end
    for _, mount in ipairs(part.mounts) do
        if mount.path == path then return mount end
    end
    return nil
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

    local defaultPartIds = {}
    local acceptedTypes = {}
    local providedTypes = {}
    local platformRootSlots = {}
    local validatedDefaultParents = {}

    local function validateDefaultChildren(parentPartId, parentPart, path, stack, depth)
        if type(parentPart.mounts) ~= "table" then return end
        if depth > 32 then
            table.insert(errors, "Default part tree under '" .. tostring(path) .. "' is deeper than 32 levels.")
            return
        end
        if validatedDefaultParents[parentPartId] then return end
        validatedDefaultParents[parentPartId] = true

        for _, mount in ipairs(parentPart.mounts) do
            local childPartId = mount.defaultPart
            if childPartId ~= nil then
                if type(childPartId) ~= "string" or childPartId == "" then
                    table.insert(errors, "Part '" .. tostring(parentPartId) .. "' mount '" .. tostring(mount.path) .. "' defaultPart must be a part id string.")
                else
                    local childPathSegment = mount.path
                    local childPath = path .. "/" .. tostring(childPathSegment)
                    local childPart = parts[childPartId]
                    defaultPartIds[childPartId] = true

                    if stack[childPartId] then
                        table.insert(errors, "Mount defaultPart contains a cycle at '" .. tostring(childPartId) .. "'.")
                    elseif not childPart then
                        table.insert(errors, "Part '" .. tostring(parentPartId) .. "' mount '" .. tostring(childPathSegment) .. "' default part '" .. tostring(childPartId) .. "' does not exist.")
                    else
                        local expectedType = mount.partType or childPathSegment
                        if childPart.type ~= expectedType then
                            table.insert(errors, "Part '" .. tostring(parentPartId) .. "' mount '" .. tostring(childPathSegment) .. "' default part '" .. tostring(childPartId) .. "' type does not match '" .. tostring(expectedType) .. "'.")
                        elseif not partProvidesAccepted(childPart, mount.accepts) then
                            table.insert(errors, "Part '" .. tostring(parentPartId) .. "' mount '" .. tostring(childPathSegment) .. "' default part '" .. tostring(childPartId) .. "' is not accepted by '" .. tostring(childPath) .. "'.")
                        end

                        stack[childPartId] = true
                        validateDefaultChildren(childPartId, childPart, childPath, stack, depth + 1)
                        stack[childPartId] = nil
                    end
                end
            end
        end
    end

    for platformId, platform in pairs(platforms) do
        if type(platform) ~= "table" then
            table.insert(errors, "Platform '" .. tostring(platformId) .. "' must be a table.")
        else
            for _, field in ipairs(oldConfigFields) do
                if platform[field] ~= nil then
                    table.insert(errors, "Platform '" .. tostring(platformId) .. "' uses removed field '" .. field .. "'.")
                end
            end
            if type(platform.rootSlots) ~= "table" then table.insert(errors, "Platform '" .. platformId .. "' is missing rootSlots.") end
            if type(platform.canvas) ~= "table" or type(platform.canvas.w) ~= "number" or type(platform.canvas.h) ~= "number" then
                table.insert(errors, "Platform '" .. platformId .. "' is missing canvas.w/h.")
            end
            if not validOptionalScale(platform.visualScale) then
                table.insert(errors, "Platform '" .. platformId .. "' visualScale must be a positive number.")
            end
            if not validOptionalPoint(platform.visualOrigin) then
                table.insert(errors, "Platform '" .. platformId .. "' visualOrigin must contain numeric x/y.")
            end

            local rootSlots = {}
            if type(platform.rootSlots) == "table" then
                if not isArray(platform.rootSlots) then
                    table.insert(errors, "Platform '" .. platformId .. "' rootSlots must be an array.")
                else
                    for index, root in ipairs(platform.rootSlots) do
                        local rootLabel = "Platform '" .. platformId .. "' rootSlots #" .. tostring(index)
                        if type(root) ~= "table" or type(root.path) ~= "string" or root.path == "" then
                            table.insert(errors, rootLabel .. " is missing path.")
                        elseif root.slot ~= nil then
                            table.insert(errors, rootLabel .. " uses removed field 'slot'; use 'path'.")
                        elseif rootSlots[root.path] then
                            table.insert(errors, rootLabel .. " duplicates root path '" .. root.path .. "'.")
                        else
                            rootSlots[root.path] = root
                        end
                        if type(root) == "table" then
                            if root.required ~= nil and type(root.required) ~= "boolean" then
                                table.insert(errors, rootLabel .. " required must be boolean when declared.")
                            end
                            if root.hidden ~= nil and type(root.hidden) ~= "boolean" then
                                table.insert(errors, rootLabel .. " hidden must be boolean when declared.")
                            end
                        end
                    end
                end
            end
            platformRootSlots[platformId] = rootSlots
        end
    end

    for weaponId, weapon in pairs(weapons) do
        local platformId = type(weapon) == "table" and weapon.platform or nil
        local platform = type(platformId) == "string" and platforms[platformId] or nil
        if type(weapon) ~= "table" or type(platformId) ~= "string" or not platform then
            table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' references missing platform '" .. tostring(platformId) .. "'.")
        else
            if weapon.defaults ~= nil then table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' uses removed field 'defaults'.") end
            if weapon.rootAccepts ~= nil then table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' uses removed field 'rootAccepts'.") end
            if not validOptionalScale(weapon.scale) then
                table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' scale must be a positive number.")
            end

            local rootSlots = platformRootSlots[platformId] or {}
            if type(weapon.rootParts) ~= "table" then
                table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' is missing rootParts.")
            else
                for path, root in pairs(rootSlots) do
                    if root.required == true and weapon.rootParts[path] == nil then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' rootParts missing required root path '" .. tostring(path) .. "'.")
                    end
                end
                for path, partId in pairs(weapon.rootParts) do
                    local part = parts[partId]
                    if not rootSlots[path] then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' rootParts contains unknown root path '" .. tostring(path) .. "'.")
                    elseif not part then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' root part '" .. tostring(partId) .. "' does not exist.")
                    elseif part.type ~= path then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' root part '" .. tostring(partId) .. "' type does not match '" .. tostring(path) .. "'.")
                    else
                        defaultPartIds[partId] = true
                        validateDefaultChildren(partId, part, path, { [partId] = true }, 0)
                    end
                end
            end

            if type(weapon.rootSockets) ~= "table" then
                table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' is missing rootSockets.")
            else
                for path, root in pairs(rootSlots) do
                    if root.required == true and (not validOptionalPoint(weapon.rootSockets[path]) or weapon.rootSockets[path] == nil) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' rootSockets missing numeric x/y for root path '" .. tostring(path) .. "'.")
                    end
                end
                for path, _ in pairs(weapon.rootSockets) do
                    if not rootSlots[path] then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' rootSockets contains unknown root path '" .. tostring(path) .. "'.")
                    end
                end
            end

            if weapon.preview ~= nil then
                if type(weapon.preview) ~= "table" then
                    table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' preview must be a table.")
                else
                    if weapon.preview.padding ~= nil and (type(weapon.preview.padding) ~= "number" or weapon.preview.padding < 0) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' preview.padding must be a non-negative number.")
                    end
                    if not validOptionalScale(weapon.preview.zoom) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' preview.zoom must be a positive number.")
                    end
                    if not validOptionalPoint(weapon.preview.offset) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' preview.offset must contain numeric x/y.")
                    end
                end
            end

            if weapon.inventory ~= nil then
                if type(weapon.inventory) ~= "table" then
                    table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' inventory must be a table.")
                else
                    if not validOptionalScale(weapon.inventory.scale) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' inventory.scale must be a positive number.")
                    end
                    if weapon.inventory.rotation ~= nil and type(weapon.inventory.rotation) ~= "number" then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' inventory.rotation must be a number.")
                    end
                    if weapon.inventory.padding ~= nil and (type(weapon.inventory.padding) ~= "number" or weapon.inventory.padding < 0) then
                        table.insert(errors, "Weapon '" .. tostring(weaponId) .. "' inventory.padding must be a non-negative number.")
                    end
                end
            end
        end
    end

    for partId, part in pairs(parts) do
        if type(part) ~= "table" then
            table.insert(errors, "Part '" .. tostring(partId) .. "' must be a table.")
        else
            if type(part.type) ~= "string" or part.type == "" then table.insert(errors, "Part '" .. partId .. "' is missing type.") end
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
            if part.visual ~= nil and part.visual.offset ~= nil then
                table.insert(errors, "Part '" .. partId .. "' visual.offset is removed; use visual.attachPoint.")
            end
            if part.visual ~= nil and not validOptionalScale(part.visual.scale) then
                table.insert(errors, "Part '" .. partId .. "' visual.scale must be a positive number.")
            end
            if part.stats ~= nil then
                if type(part.stats) ~= "table" then
                    table.insert(errors, "Part '" .. partId .. "' stats must be a table.")
                else
                    for statName, statValue in pairs(part.stats) do
                        if not knownStatFields[statName] then
                            table.insert(warnings, "Part '" .. partId .. "' uses unknown stat '" .. tostring(statName) .. "'.")
                        elseif type(statValue) ~= "number" then
                            table.insert(errors, "Part '" .. partId .. "' stat '" .. statName .. "' must be a number.")
                        end
                    end
                end
            end

            local item = part.item
            if not defaultPartIds[partId] then
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
                        local mountLabel = "Part '" .. partId .. "' mount #" .. tostring(index)
                        if mount.slot ~= nil then
                            table.insert(errors, mountLabel .. " uses removed field 'slot'; use 'path'.")
                        end
                        if type(mount.path) ~= "string" or mount.path == "" then
                            table.insert(errors, mountLabel .. " is missing path.")
                        end
                        if mount.partSlot ~= nil then
                            table.insert(errors, mountLabel .. " uses removed field 'partSlot'; use 'partType'.")
                        end
                        if mount.partType ~= nil and (type(mount.partType) ~= "string" or mount.partType == "") then
                            table.insert(errors, mountLabel .. " partType must be a non-empty string when declared.")
                        end
                        if mount.defaultPart ~= nil and (type(mount.defaultPart) ~= "string" or mount.defaultPart == "") then
                            table.insert(errors, mountLabel .. " defaultPart must be a non-empty string when declared.")
                        end
                        if not hasStringArray(mount.accepts) then
                            table.insert(errors, mountLabel .. " is missing accepts.")
                        else
                            addSetValues(acceptedTypes, mount.accepts)
                            if not hasAnyProvidedPart(parts, mount.accepts) then
                                table.insert(warnings, mountLabel .. " accepts no currently provided part type.")
                            end
                        end
                        if not validOptionalPoint(mount.anchor) then
                            table.insert(errors, mountLabel .. " anchor must contain numeric x/y.")
                        end
                    end
                end
            end
            if part.defaultParts ~= nil then
                table.insert(errors, "Part '" .. partId .. "' uses removed field 'defaultParts'; use mounts[].defaultPart.")
            end
        end
    end

    for partId, part in pairs(parts) do
        if type(part) == "table" and type(part.mounts) == "table" then
            validateDefaultChildren(partId, part, part.type or partId, { [partId] = true }, 0)
        end
    end

    for provided, _ in pairs(providedTypes) do
        if not acceptedTypes[provided] then
            local acceptedByRoot = false
            for _, weapon in pairs(weapons) do
                if type(weapon) == "table" and type(weapon.rootParts) == "table" then
                    for _, rootPartId in pairs(weapon.rootParts) do
                        local rootPart = parts[rootPartId]
                        if rootPart and partProvidesAccepted(rootPart, { provided }) then
                            acceptedByRoot = true
                            break
                        end
                    end
                end
                if acceptedByRoot then break end
            end
            if not acceptedByRoot then
                table.insert(warnings, "Provided type '" .. provided .. "' is not accepted by any mount.")
            end
        end
    end

    printReport(errors, warnings, label)
    return #errors == 0
end

function Validation.RunSelfTest()
    local badConfig = {
        platforms = {
            broken = {
                rootSlots = {
                    { path = "receiver", required = true, hidden = true },
                    { path = "receiver", required = "bad" }
                },
                defaults = {
                    receiver = "old_default"
                },
                canvas = { w = 512, h = 160 },
                visualScale = -1,
                visualOrigin = { x = "bad", y = 80 }
            },
            nested_broken = {
                rootSlots = {
                    { path = "receiver", required = true, hidden = true }
                },
                canvas = { w = 512, h = 160 }
            }
        },
        weapons = {
            bad_platform = {
                platform = "missing_platform"
            },
            bad_scale = {
                platform = "broken",
                scale = 0,
                rootParts = {
                    receiver = "missing_root_part"
                },
                rootSockets = {
                    receiver = { x = 0, y = 0 }
                }
            },
            missing_root_part = {
                platform = "nested_broken",
                rootParts = {},
                rootSockets = {
                    receiver = { x = 0, y = 0 }
                }
            },
            bad_root_socket = {
                platform = "nested_broken",
                rootParts = {
                    receiver = "test_receiver_part",
                    magazine = "test_receiver_part"
                },
                rootSockets = {
                    receiver = { x = "bad", y = 0 },
                    magazine = { x = 0, y = 0 }
                },
                defaults = {
                    receiver = "old_weapon_default"
                },
                rootAccepts = {
                    receiver = { "old_accepts" }
                }
            }
        },
        parts = {
            test_receiver_part = {
                type = "receiver",
                name = "Test Receiver Part",
                provides = { "test_receiver" },
                item = { virtual = true },
                visual = {
                    texture = "test_receiver",
                    source = { x = 0, y = 0, w = 16, h = 16 },
                    attachPoint = { x = 0, y = 0 }
                },
                mounts = {
                    { path = "barrel", accepts = { "test_barrel" }, defaultPart = "bad_type_part", anchor = { x = 0, y = 0 } },
                    { path = "stock", accepts = { "test_stock" }, defaultPart = "cycle_part", anchor = { x = 0, y = 0 } },
                    { path = "bad_default", accepts = { "test_stock" }, defaultPart = 42, anchor = { x = 0, y = 0 } }
                }
            },
            bad_type_part = {
                type = "stock",
                name = "Bad Type Part",
                provides = { "test_barrel" },
                item = { virtual = true },
                visual = {
                    texture = "bad_type",
                    source = { x = 0, y = 0, w = 16, h = 16 },
                    attachPoint = { x = 0, y = 0 }
                }
            },
            test_stock_part = {
                type = "stock",
                name = "Test Stock Part",
                provides = { "test_stock" },
                item = { virtual = true },
                visual = {
                    texture = "test_stock",
                    source = { x = 0, y = 0, w = 16, h = 16 },
                    attachPoint = { x = 0, y = 0 }
                }
            },
            cycle_part = {
                type = "stock",
                name = "Cycle Part",
                provides = { "test_stock" },
                item = { virtual = true },
                mounts = {
                    { path = "stock", accepts = { "test_stock" }, defaultPart = "cycle_part", anchor = { x = 0, y = 0 } }
                }
            },
            old_field_part = {
                type = "receiver",
                name = "Old Field Part",
                provides = { "test_receiver" },
                texture = "removed_field"
            },
            bad_visual_part = {
                type = "receiver",
                name = "Bad Visual Part",
                provides = { "test_receiver" },
                item = { virtual = true },
                stats = {
                    weight = "heavy",
                    mysteryStat = 1
                },
                visual = {
                    texture = "missing_offset",
                    source = { x = 0, y = 0, w = 16, h = 16 }
                }
            },
            bad_mount_part = {
                type = "receiver",
                name = "Bad Mount Part",
                provides = { "unused_test_type" },
                item = { virtual = true },
                mounts = {
                    { slot = "old_path_field", path = "optic_mount", partSlot = "", partType = "", anchor = { x = "bad", y = 0 } }
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
