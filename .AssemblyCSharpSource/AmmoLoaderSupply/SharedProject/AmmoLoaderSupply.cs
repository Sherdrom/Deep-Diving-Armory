using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using Barotrauma;
using Barotrauma.Items.Components;
using Barotrauma.LuaCs;
using HarmonyLib;

namespace DdaAmmoSupply
{
    public sealed class Plugin : IAssemblyPlugin
    {
        internal const string HarmonyId = "deepdivingarmory.ammoloadersupply";
        // Existing virtual 30-round magazine: a full refill costs 1.5625 box Condition.
        private const double CostPer556Round = 1.5625 / 30;
        internal static readonly Dictionary<string, Dictionary<string, double>> SupplyCosts =
            new Dictionary<string, Dictionary<string, double>>(StringComparer.OrdinalIgnoreCase)
            {
                ["ammobox1"] = new Dictionary<string, double> { ["5.56x45round"] = CostPer556Round },
                ["ammobox_7.62"] = new Dictionary<string, double> { ["5.56x45round_tit"] = CostPer556Round },
                ["ammobox_12.7"] = new Dictionary<string, double> { ["5.56x45round_phy"] = CostPer556Round },
                ["ammobox_phy_ful"] = new Dictionary<string, double> { ["556x45round_m995"] = CostPer556Round },
                ["ammobox_tun_ful"] = new Dictionary<string, double> { ["556x45round_ssa_ap"] = CostPer556Round },
                ["ammobox_du"] = new Dictionary<string, double> { ["556x45round_depleted_uranium"] = CostPer556Round },
                // Leave unfinished virtual calibers unmapped; add their projectile costs when implemented.
                ["ammobox_rip"] = new Dictionary<string, double>()
            };

        private static readonly Dictionary<string, object> definitions = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        private static PropertyInfo supplyProperty;
        private static Delegate resolver;
        private Harmony harmony;

        public void Initialize() { }
        public void PreInitPatching() { }

        public void OnLoadCompleted()
        {
            // Resolve optional VCE types after all mod assemblies load, so legacy DDA still loads without VCE.
            var loaderType = AccessTools.TypeByName("VCE.AmmoLoading.AmmoLoader");
            var definitionType = AccessTools.TypeByName("VCE.AmmoLoading.AmmoSupplyDefinition");
            supplyProperty = loaderType?.GetProperty("SupplyResolver");
            if (supplyProperty == null || definitionType == null)
            {
                LuaCsLogger.Log("[DDA AmmoLoader] Custom supplies require the VCE SupplyResolver API.");
                return;
            }
            definitions.Clear();
            foreach (var entry in SupplyCosts.Where(p => p.Value.Count > 0))
            {
                definitions.Add(entry.Key, Activator.CreateInstance(definitionType,
                    new object[] { "dda." + entry.Key, entry.Value }));
            }
            var source = Expression.Parameter(typeof(Item), "source");
            resolver = Expression.Lambda(supplyProperty.PropertyType,
                Expression.Convert(Expression.Call(AccessTools.Method(typeof(Plugin), nameof(Resolve)), source), definitionType), source).Compile();
            harmony = new Harmony(HarmonyId);
            harmony.Patch(AccessTools.Method(loaderType, "OnItemLoaded"), postfix: new HarmonyMethod(typeof(Plugin), nameof(Attach)));
            foreach (var loader in ExistingLoaders()) { Attach(loader); }
        }

        private static object Resolve(Item source) => definitions.TryGetValue(source.Prefab.Identifier.Value, out var value) ? value : null;

        internal static void Attach(ItemComponent __instance)
        {
            if (GameMain.NetworkMember?.IsClient == true ||
                __instance.Item.Prefab.Identifier != new Identifier("deep_new_ammoloader")) { return; }
            if (supplyProperty.GetValue(__instance) == null) { supplyProperty.SetValue(__instance, resolver); }
        }

        private static IEnumerable<ItemComponent> ExistingLoaders() => Item.ItemList
            .Where(item => !item.Removed).SelectMany(item => item.GetComponents<ItemComponent>())
            .Where(component => supplyProperty.DeclaringType.IsInstanceOfType(component));

        public void Dispose()
        {
            harmony?.UnpatchSelf();
            if (supplyProperty != null && resolver != null)
            {
                foreach (var loader in ExistingLoaders())
                {
                    if (Equals(supplyProperty.GetValue(loader), resolver)) { supplyProperty.SetValue(loader, null); }
                }
            }
            definitions.Clear();
            resolver = null;
            supplyProperty = null;
        }
    }
}
