namespace DDA.AmmoLoading;

internal static class DdaSupply
{
    // ContainerConditionTransfer.lua: cost per round = fullCondition * drainPerSecond / gainPerSecond / rounds.
    // Shared projectile IDs use the base magazine's nominal capacity, even when extended magazines differ.
    internal static readonly Dictionary<string, Dictionary<string, double>> SupplyCosts =
        new Dictionary<string, Dictionary<string, double>>(StringComparer.OrdinalIgnoreCase)
        {
            ["deep_ammobox_lead"] = new Dictionary<string, double>
            {
                // Pistols
                ["9mmround"] = 0.78125 / 8,
                ["9mmround_2"] = 0.78125 / 15,
                [".45acp"] = 0.78125 / 7,

                // Rifles
                ["5.56x45round"] = 1.5625 / 30,
                ["5.45x39round"] = 1.5625 / 30,
                ["762x39round_lead"] = 1.5625 / 30,
                ["762x51round_lead"] = 1.5625 / 20,
                ["58x42round_lead"] = 1.5625 / 30,
                ["792x33round"] = 1.5625 / 30,
                ["9x39round_lead"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round"] = 1.0417 / 30,
                ["smg_1143_round"] = 1.5625 / 50,
                ["smg_mac_round"] = 1.0417 / 30,
                ["smg_ump45_round"] = 1.0417 / 25,

                // Machine guns
                ["762x54round_dp"] = 6.25 / 60,
                ["762x39round_rpk_lead"] = 3.125 / 75,

                // Sniper rifles
                ["762x63round"] = 1.5625 / 8,
                ["762x39round_sks"] = 1.5625 / 10,
                ["762x51round_m14"] = 1.5625 / 20,
                ["792x57round_fn49"] = 1.5625 / 10,
                ["792x57round_gew43"] = 1.5625 / 10,
                ["762x54rround"] = 1.5625 / 5,
                ["762x63round_m1903"] = 1.5625 / 5,
                ["77round_lee"] = 1.5625 / 10,
                ["65round_38"] = 1.5625 / 5,
                ["792round_98k"] = 1.5625 / 5,
            },
            ["deep_ammobox_titanium"] = new Dictionary<string, double>
            {
                // Pistols
                ["5.7round"] = 0.78125 / 20,
                ["p_45acp_tit"] = 0.78125 / 7,
                ["44_magnum"] = 0.78125 / 6,
                ["9mmround_3"] = 0.78125 / 15, // CZ75 standard 15-round magazine.

                // Rifles
                ["5.56x45round_tit"] = 1.5625 / 30,
                ["5.45x39round_tit"] = 1.5625 / 30,
                ["7.62x39round"] = 1.5625 / 30,
                ["7.62x51round"] = 1.5625 / 20,
                ["58x42round_tit"] = 1.5625 / 30,
                ["792x33round_tit"] = 1.5625 / 30,
                ["9x39round_tit"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round_tit"] = 1.0417 / 30,
                ["smg_ump45_round_tit"] = 1.0417 / 25,
                ["smg_vector_round_tit"] = 1.0417 / 30,
                ["smg_57mm_round_tit"] = 1.0417 / 50,

                // Machine guns
                ["762x54round_dp_tit"] = 6.25 / 60,
                ["762x39round_rpk"] = 3.125 / 75,
                ["545x39round_tit_rpk16"] = 3.125 / 95,
                ["762x51round_m60"] = 12.5 / 100,

                // Sniper rifles
                ["762x63round_tit"] = 1.5625 / 8,
                ["762x39round_sks_tit"] = 1.5625 / 10,
                ["762x51round_m14_tit"] = 1.5625 / 20,
                ["792x57round_fn49_tit"] = 1.5625 / 10,
                ["792x57round_gew43_tit"] = 1.5625 / 10,
                ["762x54rround_tit"] = 1.5625 / 5,
                ["762x63round_m1903_tit"] = 1.5625 / 5,
                ["77round_lee_tit"] = 1.5625 / 10,
                ["65round_38_tit"] = 1.5625 / 5,
                ["792round_98k_tit"] = 1.5625 / 5,
                ["awm_338_round_tit"] = 3.125 / 5,
                ["sv98_762_54_round_tit"] = 3.125 / 10,
                ["m700_762_51_round_tit"] = 3.125 / 5,
                ["r93_762_51_round_tit"] = 3.125 / 10,
                ["sr25_762x51round"] = 3.125 / 20,

                // Shotguns
                ["deep_12shell_aa12"] = 18.75 / 25,
            },
            ["deep_ammobox_physicorium"] = new Dictionary<string, double>
            {
                // Pistols
                ["57round_phy"] = 0.78125 / 20,
                ["p_45acp_phy"] = 0.78125 / 7,
                [".50ae"] = 0.78125 / 7,
                [".50gl"] = 0.78125 / 7,
                [".50sw"] = 0.78125 / 5,
                ["9mmround_phy"] = 0.78125 / 17, // Glock standard 17-round magazine.

                // Rifles
                ["5.56x45round_phy"] = 1.5625 / 30,
                ["5.45x39round_phy"] = 1.5625 / 30,
                ["7.62x39round_phy"] = 1.5625 / 30,
                ["7.62x51round_phy"] = 1.5625 / 20,
                ["12.7x55round"] = 1.5625 / 20,
                ["58x42round_phy"] = 1.5625 / 30,
                ["792x33round_phy"] = 1.5625 / 30,
                ["9x39round_phy"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round_phy"] = 1.0417 / 30, // Standard 30-round SMG magazine, before the PP-19.
                ["smg_ump45_round_phy"] = 1.0417 / 25,
                ["smg_57mm_round_phy"] = 1.0417 / 50,
                ["smg_46mm_round_phy"] = 1.0417 / 40,

                // Machine guns
                ["545x39round_phy_rpk16"] = 3.125 / 95,
                ["762x51round_m60_phy"] = 12.5 / 100,
                ["762x54round_pkp"] = 12.5 / 100,
                ["792x57round_phy"] = 12.5 / 100,
                ["556x45round_phy_m249"] = 6.25 / 100,
                ["762x39round_rpd_sun"] = 6.25 / 100,

                // Sniper rifles
                ["762x63round_phy"] = 1.5625 / 8,
                ["762x39round_sks_phy"] = 1.5625 / 10,
                ["762x51round_m14_phy"] = 1.5625 / 20, // M14 standard 20-round magazine, before the M14EBR drum.
                ["792x57round_fn49_phy"] = 1.5625 / 10,
                ["792x57round_gew43_phy"] = 1.5625 / 10,
                ["762x54rround_phy"] = 1.5625 / 5,
                ["762x63round_m1903_phy"] = 1.5625 / 5,
                ["77round_lee_phy"] = 1.5625 / 10,
                ["65round_38_phy"] = 1.5625 / 5,
                ["792round_98k_phy"] = 1.5625 / 5,
                ["awm_338_round_phy"] = 3.125 / 5,
                ["sv98_762_54_round_phy"] = 3.125 / 10,
                ["m700_762_51_round_phy"] = 3.125 / 5,
                ["r93_762_51_round_phy"] = 3.125 / 10,
                ["sr25_762x51round_phy"] = 3.125 / 20,
                ["127x99round"] = 6.25 / 10,
                ["deep_ar15_50_round_phy"] = 3.125 / 10,

                // Shotguns
                ["deep_slug_aa12"] = 18.75 / 25,
            },
            ["deep_ammobox_fulgurium_physicorium"] = new Dictionary<string, double>
            {
                // Rifles
                ["556x45round_m995"] = 1.5625 / 30,
                ["545x39round_bs"] = 1.5625 / 30,
                ["762x39round_bp"] = 1.5625 / 30,
                ["762x51round_m61"] = 1.5625 / 20,
                ["127x55round_ps12b"] = 1.5625 / 20,
                ["58x42round_fu"] = 1.5625 / 30,
                ["9x39round_fu"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round_fu"] = 1.0417 / 30, // Standard 30-round SMG magazine, before the PP-19.
                ["smg_57mm_round_fu"] = 1.0417 / 50,
                ["smg_46mm_round_fu"] = 1.0417 / 40,

                // Machine guns
                ["556x45round_m995_m249"] = 6.25 / 100,
                ["86x70_rm338_round_fu"] = 12.5 / 100,

                // Sniper rifles
                ["sr25_762x51round_m61"] = 3.125 / 20,
                ["deep_ar15_50_round_fu"] = 3.125 / 10,
                ["762x51round_m14_m80a1"] = 6.25 / 50,
                ["izanagi_paidaxing_round_fu"] = 6.25 / 4,
                ["mk22_round_fu"] = 6.25 / 10,
            },
            ["deep_ammobox_tungsten_physicorium"] = new Dictionary<string, double>
            {
                // Rifles
                ["556x45round_ssa_ap"] = 1.5625 / 30,
                ["5.45x39round_7n39"] = 1.5625 / 30,
                ["762x39round_mai_ap"] = 1.5625 / 30,
                ["762x51round_m993"] = 1.5625 / 20,
                ["58x42round_ap"] = 1.5625 / 30,
                ["9x39round_ap"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round_ap"] = 1.0417 / 30, // Standard 30-round SMG magazine, before the PP-19.
                ["smg_57mm_round_ap"] = 1.0417 / 50,
                ["smg_46mm_round_ap"] = 1.0417 / 40,

                // Machine guns
                ["792x57round"] = 37.5 / 300, // MG42 nominal capacity is 300; its 0.33 Condition drain is rounded.
                ["556x45round_ssa_ap_m249"] = 6.25 / 100,
                ["762x54round_pkp_7n37"] = 12.5 / 100,
                ["86x70_rm338_round_ap"] = 12.5 / 100,

                // Sniper rifles
                ["awm_338_round_ap"] = 3.125 / 5,
                ["sv98_762_54_round_7n37"] = 3.125 / 10,
                ["m700_762_51_round_m993"] = 3.125 / 5,
                ["r93_762_51_round_m993"] = 3.125 / 10,
                ["sr25_762x51round_m993"] = 3.125 / 20,
                ["deep_ar15_50_round_ap"] = 3.125 / 10,
                ["762x51round_m14_m993"] = 6.25 / 50,
                ["izanagi_paidaxing_round_ap"] = 6.25 / 4,
                ["mk22_round_ap"] = 6.25 / 10,
            },
            ["deep_ammobox_depleted_uranium"] = new Dictionary<string, double>
            {
                // Rifles
                ["556x45round_depleted_uranium"] = 1.5625 / 30,
                ["545x39round_depleted_uranium"] = 1.5625 / 30,
                ["762x39round_depleted_uranium"] = 1.5625 / 30,
                ["762x51round_depleted_uranium"] = 1.5625 / 20,
                ["127x55round_depleted_uranium"] = 1.5625 / 20,
                ["58x42round_du"] = 1.5625 / 30,
                ["9x39round_du"] = 1.5625 / 20, // 9A-91 standard 20-round magazine.

                // SMGs
                ["smg_9mm_round_du"] = 1.0417 / 30, // Standard 30-round SMG magazine, before the PP-19.
                ["smg_vector_round_du"] = 1.0417 / 30,
                ["smg_57mm_round_du"] = 1.0417 / 50,
                ["smg_46mm_round_du"] = 1.0417 / 40,

                // Machine guns
                ["762x54round_dp_du"] = 6.25 / 60,
                ["762x39round_rpk_du"] = 3.125 / 75,
                ["545x39round_du_rpk16"] = 3.125 / 95,
                ["762x51round_m60_du"] = 12.5 / 100,
                ["556x45round_du_m249"] = 6.25 / 100,

                // Sniper rifles
                ["762x63round_du"] = 1.5625 / 8,
                ["762x39round_sks_du"] = 1.5625 / 10,
                ["762x51round_m14_du"] = 1.5625 / 20, // M14 standard 20-round magazine, before the M14EBR drum.
                ["792x57round_fn49_du"] = 1.5625 / 10,
                ["792x57round_gew43_du"] = 1.5625 / 10,
                ["762x54rround_du"] = 1.5625 / 5,
                ["762x63round_m1903_du"] = 1.5625 / 5,
                ["77round_lee_du"] = 1.5625 / 10,
                ["65round_38_du"] = 1.5625 / 5,
                ["792round_98k_du"] = 1.5625 / 5,
                ["awm_338_round_du"] = 3.125 / 5,
                ["sv98_762_54_round_du"] = 3.125 / 10,
                ["m700_762_51_round_du"] = 3.125 / 5,
                ["r93_762_51_round_du"] = 3.125 / 10,
                ["sr25_762x51round_du"] = 3.125 / 20,
                ["deep_ar15_50_round_du"] = 3.125 / 10,
            },
            ["deep_ammobox_copper"] = new Dictionary<string, double>
            {
                // SMGs
                ["smg_vector_round_rip"] = 1.0417 / 30,
            },
        };

    private static readonly Dictionary<string, AmmoSupplyDefinition> definitions = SupplyCosts
        .Where(p => p.Value.Count > 0).ToDictionary(p => p.Key,
            p => new AmmoSupplyDefinition("dda." + p.Key, p.Value), StringComparer.OrdinalIgnoreCase);

    internal static AmmoSupplyDefinition? Resolve(Item source) =>
        definitions.TryGetValue(source.Prefab.Identifier.Value, out var value) ? value : null;
}
