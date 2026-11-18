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

        void AddCaliber(string caliber, double cost, string leadSuffix = "_lead", string fuSuffix = "_fu",
            string apSuffix = "_ap", string duSuffix = "_depleted_uranium")
        {
            string round = caliber + "round";
            lead.Add(round + leadSuffix, cost);
            titanium.Add(round + "_tit", cost);
            physicorium.Add(round + "_phy", cost);
            fulgurium.Add(round + fuSuffix, cost);
            tungsten.Add(round + apSuffix, cost);
            uranium.Add(round + duSuffix, cost);
        }

        // Each caliber shares one price across magazines: legacy base-magazine Condition / nominal rounds.
        AddCaliber("556x45", 1.5625 / 30, leadSuffix: "", fuSuffix: "_m995", apSuffix: "_ssa_ap");
        AddCaliber("545x39", 1.5625 / 30, leadSuffix: "", fuSuffix: "_bs", apSuffix: "_7n39");
        AddCaliber("58x42", 1.5625 / 30, duSuffix: "_du");
        AddCaliber("762x39", 1.5625 / 30, fuSuffix: "_bp", apSuffix: "_mai_ap");
        AddCaliber("762x51", 1.5625 / 20, fuSuffix: "_m61", apSuffix: "_m993");
        AddCaliber("762x54r", 1.5625 / 5, apSuffix: "_7n37");
        AddCaliber("762x63", 1.5625 / 8);
        AddCaliber("792x33", 1.5625 / 30, leadSuffix: "");
        AddCaliber("792x57", 1.5625 / 10);
        AddCaliber("65x50", 1.5625 / 5);
        AddCaliber("303", 1.5625 / 10);
        AddCaliber("9x39", 1.5625 / 20, duSuffix: "_du");
        AddCaliber("127x55", 1.5625 / 20, leadSuffix: "");
        AddCaliber("127x99", 6.25 / 10);
        AddCaliber("338lm", 3.125 / 5);
        AddCaliber("338nm", 12.5 / 100);
        AddCaliber("50beowulf", 3.125 / 10);
        AddCaliber("9x18", 0.78125 / 8);
        AddCaliber("9x19", 0.78125 / 15);
        AddCaliber("45acp", 0.78125 / 7);
        AddCaliber("57x28", 0.78125 / 20);
        AddCaliber("46x30", 1.0417 / 40);
        AddCaliber("44mg", 0.78125 / 6);
        AddCaliber("50ae", 0.78125 / 7);
        AddCaliber("50gl", 0.78125 / 7);
        AddCaliber("50sw", 0.78125 / 5);

        titanium.Add("deep_12shell_aa12", 18.75 / 25);
        physicorium.Add("deep_slug_aa12", 18.75 / 25);
    }

    internal static AmmoSupplyDefinition? Resolve(Item source) =>
        definitions.GetValueOrDefault(source.Prefab.Identifier.Value);
}
