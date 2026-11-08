namespace DDA.AmmoLoading;

internal static class DdaSupply
{
    // Existing virtual 30-round magazine: a full refill costs 1.5625 box Condition.
    private const double CostPer556Round = 1.5625 / 30;
    internal static readonly Dictionary<string, Dictionary<string, double>> SupplyCosts =
        new Dictionary<string, Dictionary<string, double>>(StringComparer.OrdinalIgnoreCase)
        {
            ["deep_ammobox_lead"] = new Dictionary<string, double> { ["5.56x45round"] = CostPer556Round },
            ["deep_ammobox_titanium"] = new Dictionary<string, double> { ["5.56x45round_tit"] = CostPer556Round },
            ["deep_ammobox_physicorium"] = new Dictionary<string, double> { ["5.56x45round_phy"] = CostPer556Round },
            ["deep_ammobox_fulgurium_physicorium"] = new Dictionary<string, double> { ["556x45round_m995"] = CostPer556Round },
            ["deep_ammobox_tungsten_physicorium"] = new Dictionary<string, double> { ["556x45round_ssa_ap"] = CostPer556Round },
            ["deep_ammobox_depleted_uranium"] = new Dictionary<string, double> { ["556x45round_depleted_uranium"] = CostPer556Round },
            // Leave unfinished virtual calibers unmapped; add their projectile costs when implemented.
            ["deep_ammobox_copper"] = new Dictionary<string, double>()
        };

    private static readonly Dictionary<string, AmmoSupplyDefinition> definitions = SupplyCosts
        .Where(p => p.Value.Count > 0).ToDictionary(p => p.Key,
            p => new AmmoSupplyDefinition("dda." + p.Key, p.Value), StringComparer.OrdinalIgnoreCase);

    internal static AmmoSupplyDefinition? Resolve(Item source) =>
        definitions.TryGetValue(source.Prefab.Identifier.Value, out var value) ? value : null;
}
