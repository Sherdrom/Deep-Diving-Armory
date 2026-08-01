local mufflerMarker = {
    blockedByEnemyResistance = true,
    talentMarkers = { "deep_muffler" },
}

return {
    ["deep_asvalmod4"] = mufflerMarker,
    ["deep_mp5sd"] = mufflerMarker,
    ["deep_LYXN"] = mufflerMarker,
    ["deep_asval"] = mufflerMarker,
    ["deep_g36c_roger"] = {
        effects = {
            mufflerMarker,
            { talentMarkers = { "chip_headshot_detect" } },
        },
    },
}
