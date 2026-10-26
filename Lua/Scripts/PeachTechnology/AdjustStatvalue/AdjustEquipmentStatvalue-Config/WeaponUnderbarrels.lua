local debuff = {
    blockedByEnemyResistance = true,
    statsKey = "deep_sub_hanging_debuff",
    stats = {
        { statType = "MovementSpeed", value = -0.2 },
        { statType = "WeaponsSkillBonus", value = -20 },
    },
}

local SHOTGUN_AMMO_TAG = Identifier("deep_round_shotgun_attenuation")
local function hasShotgunAmmo(_, _, accessory)
    local inventory = accessory and accessory.OwnInventory
    return inventory and inventory:FindItemByTag(SHOTGUN_AMMO_TAG, false) ~= nil
end

local shotgunMarker = {
    when = hasShotgunAmmo,
    talentMarkers = { "deep_shotgun_damgage_balance_12shell" },
}

return {
    ["deep_sub_hanging_master_key"] = { pollInterval = 0.9, effects = { debuff, shotgunMarker } },
    ["deep_sub_hanging_m203"] = debuff,
    ["deep_sub_hanging_gp25"] = debuff,
    ["deep_sub_hanging_qlg10a"] = debuff,
}
