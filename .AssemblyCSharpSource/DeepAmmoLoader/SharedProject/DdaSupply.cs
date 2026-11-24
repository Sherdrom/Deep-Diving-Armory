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

        void AddRounds(string prefix, double cost, string leadSuffix = "_lead", string fuSuffix = "_fu",
            string apSuffix = "_ap", string duSuffix = "_depleted_uranium")
        {
            lead.Add(prefix + leadSuffix, cost);
            titanium.Add(prefix + "_tit", cost);
            physicorium.Add(prefix + "_phy", cost);
            fulgurium.Add(prefix + fuSuffix, cost);
            tungsten.Add(prefix + apSuffix, cost);
            uranium.Add(prefix + duSuffix, cost);
        }

        // Each caliber shares one price across magazines: legacy base-magazine Condition / nominal rounds.
        AddRounds("556x45round", 1.5625 / 30, leadSuffix: "", fuSuffix: "_m995", apSuffix: "_ssa_ap");
        AddRounds("545x39round", 1.5625 / 30, leadSuffix: "", fuSuffix: "_bs", apSuffix: "_7n39");
        AddRounds("58x42round", 1.5625 / 30, duSuffix: "_du");
        AddRounds("762x39round", 1.5625 / 30, fuSuffix: "_bp", apSuffix: "_mai_ap");
        AddRounds("762x51round", 1.5625 / 20, fuSuffix: "_m61", apSuffix: "_m993");
        AddRounds("762x54rround", 1.5625 / 5, apSuffix: "_7n37");
        AddRounds("762x63round", 1.5625 / 8);
        AddRounds("792x33round", 1.5625 / 30, leadSuffix: "");
        AddRounds("792x57round", 1.5625 / 10);
        AddRounds("65x50round", 1.5625 / 5);
        AddRounds("303round", 1.5625 / 10);
        AddRounds("9x39round", 1.5625 / 20, duSuffix: "_du");
        AddRounds("127x55round", 1.5625 / 20, leadSuffix: "");
        AddRounds("127x99round", 6.25 / 10);
        AddRounds("338lmround", 3.125 / 5);
        AddRounds("338nmround", 12.5 / 100);
        AddRounds("50beowulfround", 3.125 / 10);
        AddRounds("9x18round", 0.78125 / 8);
        AddRounds("9x19round", 0.78125 / 15);
        AddRounds("45acpround", 0.78125 / 7);
        AddRounds("57x28round", 0.78125 / 20);
        AddRounds("46x30round", 1.0417 / 40);
        AddRounds("44mground", 0.78125 / 6);
        AddRounds("50aeround", 0.78125 / 7);
        AddRounds("50glround", 0.78125 / 7);
        AddRounds("50swround", 0.78125 / 5);

        AddRounds("deep_12shell", 18.75 / 25, duSuffix: "_du");
        AddRounds("deep_12slug", 18.75 / 25, duSuffix: "_du");
    }

    internal static AmmoSupplyDefinition? Resolve(Item source) =>
        definitions.GetValueOrDefault(source.Prefab.Identifier.Value);
}
