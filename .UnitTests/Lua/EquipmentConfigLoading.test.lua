Deep_Lua = { Path = "." }
InvSlotType = {
    Head = 1, InnerClothes = 2, OuterClothes = 3, Headset = 4,
    Card = 5, Bag = 6, LeftHand = 7, RightHand = 8,
}
Identifier = function(value) return value end

local loader = "Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config.lua"
local originalDofile = dofile
local config, categories = dofile(loader)
assert(config == AdjustEquipmentConfig)
for category in pairs(categories) do assert(type(config[category]) == "table") end

local extra = { stats = { { statType = "MovementSpeed", value = 0.123 } } }
dofile = function(path)
    if path:match("/AdditionalTest%.lua$") then return { __extra_config = extra } end
    return originalDofile(path)
end
local file = assert(io.open(loader))
local source = file:read("*a")
file:close()
-- Simulate registering a new category file in the loader's single manifest.
local extended, replacements = source:gsub('"NeuralAdjustments.lua"', '"NeuralAdjustments.lua", "AdditionalTest.lua"', 1)
assert(replacements == 1)
local expanded, expandedCategories = assert(load(extended, "@" .. loader))()
assert(expanded.subItems.__extra_config == extra, "new category file was not merged")
local found = false
for _, name in ipairs(expandedCategories.subItems) do
    if name == "AdditionalTest.lua" then found = true end
end
assert(found, "new category file was not exposed to membership tests")

dofile = function(path)
    if path:match("/AdditionalTest%.lua$") then
        return { deep_firendlyfire_avoid_tac = extra }
    end
    return originalDofile(path)
end
local ok, err = pcall(assert(load(extended, "@" .. loader)))
assert(not ok and tostring(err):find("duplicate equipment config: deep_firendlyfire_avoid_tac", 1, true),
    "duplicate category identifiers were accepted")
dofile = originalDofile

print("Equipment config loading check OK")
