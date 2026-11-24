namespace DDA.AmmoLoading;

internal static class DdaSupply
{
    private static readonly Dictionary<string, AmmoSupplyDefinition> definitions = new(StringComparer.OrdinalIgnoreCase);

    static DdaSupply()
    {
        Dictionary<string, double> AddBox(string material)
        {
            string box = "deep_ammobox_" + material;
            var costs = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            definitions.Add(box, new AmmoSupplyDefinition("dda." + box, costs));
            return costs;
        }

        var lead = AddBox("lead");
        var titanium = AddBox("titanium");
        var physicorium = AddBox("physicorium");
        var fulgurium = AddBox("fulgurium_physicorium");
        var tungsten = AddBox("tungsten_physicorium");
        var uranium = AddBox("depleted_uranium");

        void AddRounds(string prefix, int roundsPerBox, string leadSuffix = "_lead", string fuSuffix = "_fu",
            string apSuffix = "_ap", string duSuffix = "_depleted_uranium")
        {
            double cost = 100.0 / roundsPerBox;
            lead.Add(prefix + leadSuffix, cost);
            titanium.Add(prefix + "_tit", cost);
            physicorium.Add(prefix + "_phy", cost);
            fulgurium.Add(prefix + fuSuffix, cost);
            tungsten.Add(prefix + apSuffix, cost);
            uranium.Add(prefix + duSuffix, cost);
        }

        // Each caliber shares one price across magazines. Cost is Condition consumed per projectile,
        // so the number below is the rounds supplied by a full ammo box.
        // value 0.6 => 3200, 1 => 1920, 2 => 960, 3 => 640, 4 => 480, 8 => 240, 10 => 192 rounds per box.
        AddRounds("556x45round", 1920, leadSuffix: "", fuSuffix: "_m995", apSuffix: "_ssa_ap");
        AddRounds("545x39round", 1920, leadSuffix: "", fuSuffix: "_bs", apSuffix: "_7n39");
        AddRounds("58x42round", 1920, duSuffix: "_du");
        AddRounds("762x39round", 1920, fuSuffix: "_bp", apSuffix: "_mai_ap");
        AddRounds("762x51round", 640, fuSuffix: "_m61", apSuffix: "_m993");
        AddRounds("762x54rround", 640, apSuffix: "_7n37");
        AddRounds("762x63round", 640);
        AddRounds("792x33round", 1920, leadSuffix: "");
        AddRounds("792x57round", 640);
        AddRounds("65x50round", 640);
        AddRounds("303round", 640);
        AddRounds("9x39round", 960, duSuffix: "_du");
        AddRounds("127x55round", 480, leadSuffix: "");
        AddRounds("127x99round", 192);
        AddRounds("338lmround", 480);
        AddRounds("338nmround", 480);
        AddRounds("50beowulfround", 640);
        AddRounds("9x18round", 3200);
        AddRounds("9x19round", 3200);
        AddRounds("45acpround", 3200);
        AddRounds("57x28round", 3200);
        AddRounds("46x30round", 3200);
        AddRounds("44mground", 640);
        AddRounds("50aeround", 640);
        AddRounds("50glround", 640);
        AddRounds("50swround", 480);

        AddRounds("deep_12shell", 240, duSuffix: "_du");
        AddRounds("deep_12slug", 240, duSuffix: "_du");
    }

    internal static AmmoSupplyDefinition? Resolve(Item source) =>
        definitions.GetValueOrDefault(source.Prefab.Identifier.Value);
}
