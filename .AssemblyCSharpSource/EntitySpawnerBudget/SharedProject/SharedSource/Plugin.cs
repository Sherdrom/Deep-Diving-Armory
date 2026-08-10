using System.Diagnostics;
using System.Reflection;
using System.Runtime.ExceptionServices;
using Barotrauma.LuaCs.Events;
using HarmonyLib;

namespace EntitySpawnerBudget;

public sealed class Plugin : IAssemblyPlugin, IEventUpdate
{
    private const string HarmonyId = "deepdivingarmory.entityspawnerbudget";
    private Harmony? harmony;
    public IEventService EventService { get; set; } = null!;

    public void Initialize()
    {
        harmony = new Harmony(HarmonyId);
    }

    public void OnLoadCompleted()
    {
        harmony?.PatchAll(typeof(Plugin).Assembly);
        EventService?.Subscribe<IEventUpdate>(this);
    }

    public void OnUpdate(double fixedDeltaTime)
    {
        DeferredLoadouts.Process(BudgetGate.BudgetMilliseconds);
    }

    public void PreInitPatching() { }

    public void Dispose()
    {
        EventService?.Unsubscribe<IEventUpdate>(this);
        DeferredLoadouts.Clear();
        harmony?.UnpatchSelf();
        harmony = null;
    }

    private sealed class LoadoutContext
    {
        public readonly Character Character;
        public readonly bool LootingIsStealing;

        public LoadoutContext(Character character, bool lootingIsStealing)
        {
            Character = character;
            LootingIsStealing = lootingIsStealing;
        }
    }

    private sealed class LoadoutScope
    {
        public readonly LoadoutContext? Previous;
        public bool Restored;

        public LoadoutScope(LoadoutContext? previous) => Previous = previous;
    }

    private sealed class DeferredItem
    {
        public readonly Character Character;
        public readonly object ItemElement;
        public readonly object HumanPrefab;
        public readonly Submarine? Submarine;
        public readonly WayPoint? SpawnPoint;
        public readonly bool CreateNetworkEvents;
        public readonly bool LootingIsStealing;

        public DeferredItem(Character character, object itemElement, object humanPrefab, Submarine? submarine,
            WayPoint? spawnPoint, bool createNetworkEvents, bool lootingIsStealing)
        {
            Character = character;
            ItemElement = itemElement;
            HumanPrefab = humanPrefab;
            Submarine = submarine;
            SpawnPoint = spawnPoint;
            CreateNetworkEvents = createNetworkEvents;
            LootingIsStealing = lootingIsStealing;
        }
    }

    private static class DeferredLoadouts
    {
        private static readonly Queue<DeferredItem> Pending = new();

        [ThreadStatic]
        private static LoadoutContext? current;

        public static LoadoutScope Push(LoadoutContext? next)
        {
            var scope = new LoadoutScope(current);
            current = next;
            return scope;
        }

        public static void Restore(LoadoutScope? scope)
        {
            if (scope is null || scope.Restored) { return; }
            current = scope.Previous;
            scope.Restored = true;
        }

        public static bool TryEnqueue(Character character, object itemElement, object humanPrefab, Submarine? submarine,
            WayPoint? spawnPoint, Item? parentItem, bool createNetworkEvents)
        {
            var context = current;
            if (context is null || parentItem != null || !ReferenceEquals(character, context.Character)) { return false; }
            Pending.Enqueue(new DeferredItem(character, itemElement, humanPrefab, submarine, spawnPoint,
                createNetworkEvents, context.LootingIsStealing));
            return true;
        }

        public static void Process(double budgetMilliseconds)
        {
            long startedAt = Stopwatch.GetTimestamp();
            bool processed = false;
            while (Pending.Count > 0)
            {
                double elapsedMilliseconds = (Stopwatch.GetTimestamp() - startedAt) * 1000.0 / Stopwatch.Frequency;
                if (!BudgetGate.ShouldContinue(Pending.Count, throttled: true, processed, elapsedMilliseconds, budgetMilliseconds)) { break; }

                var deferred = Pending.Dequeue();
                processed = true;
                if (deferred.Character.Removed || deferred.Character.Inventory == null) { continue; }

                HumanPrefabInitializeItemPatch.InvokeOriginal(deferred);
                if (deferred.LootingIsStealing && !deferred.Character.Removed && deferred.Character.Inventory != null)
                {
                    foreach (var item in deferred.Character.Inventory.FindAllItems(recursive: true))
                    {
                        item.SpawnedInCurrentOutpost = true;
                        item.AllowStealing = false;
                    }
                }
            }
        }

        public static void Clear() => Pending.Clear();
    }

    [HarmonyPatch]
    private static class MapEntityUpdateAllPatch
    {
        private static MethodBase? TargetMethod()
        {
            Type? type = AccessTools.TypeByName("Barotrauma.MapEntity");
            return type is null ? null : AccessTools.Method(type, "UpdateAll", new[] { typeof(float), typeof(Camera) });
        }

        private static void Prefix(out BudgetGate.MainTickScope __state)
            => __state = BudgetGate.BeginMainTick();

        private static void Postfix(BudgetGate.MainTickScope __state)
            => BudgetGate.EndMainTick(__state);

        private static Exception? Finalizer(Exception? __exception, BudgetGate.MainTickScope __state)
        {
            BudgetGate.EndMainTick(__state);
            return __exception;
        }
    }

    [HarmonyPatch]
    private static class EntitySpawnerUpdatePatch
    {
        private static MethodBase? TargetMethod()
        {
            Type? type = AccessTools.TypeByName("Barotrauma.EntitySpawner");
            return type is null ? null : AccessTools.Method(type, "Update", new[] { typeof(bool) });
        }

        private static void Prefix(bool createNetworkEvents, out BudgetGate.Scope __state)
            => __state = BudgetGate.Begin(createNetworkEvents);

        private static void Postfix(BudgetGate.Scope __state)
            => BudgetGate.End(__state);

        private static Exception? Finalizer(Exception? __exception, BudgetGate.Scope __state)
        {
            BudgetGate.End(__state);
            return __exception;
        }

        private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
        {
            var codes = instructions.ToList();
            Type? type = AccessTools.TypeByName("Barotrauma.EntitySpawner");
            FieldInfo? queueField = type is null ? null : AccessTools.Field(type, "spawnOrRemoveQueue");
            int matches = 0;
            int insertionIndex = -1;

            if (queueField != null)
            {
                for (int i = 0; i + 1 < codes.Count; i++)
                {
                    bool sameQueue = codes[i].opcode == OpCodes.Ldfld && codes[i].operand is FieldInfo field && field == queueField;
                    bool countGetter = codes[i + 1].operand is MethodInfo method
                        && (codes[i + 1].opcode == OpCodes.Call || codes[i + 1].opcode == OpCodes.Callvirt)
                        && method.Name == "get_Count"
                        && method.ReturnType == typeof(int)
                        && method.DeclaringType == queueField.FieldType;
                    if (sameQueue && countGetter)
                    {
                        matches++;
                        insertionIndex = i + 2;
                    }
                }
            }

            if (matches != 1 || insertionIndex < 0)
            {
                Console.Error.WriteLine($"[EntitySpawnerBudget] Update transpiler fail-closed: queue Count matches={matches}");
                return codes;
            }

            codes.Insert(insertionIndex, new CodeInstruction(OpCodes.Call,
                AccessTools.Method(typeof(BudgetGate), nameof(BudgetGate.FilterQueueCount), new[] { typeof(int) })));
            return codes;
        }
    }

    [HarmonyPatch]
    private static class CharacterSpawnInfoOnSpawnedPatch
    {
        private static MethodBase? TargetMethod()
        {
            Type? type = AccessTools.TypeByName("Barotrauma.EntitySpawner+CharacterSpawnInfo");
            return type is null ? null : AccessTools.Method(type, "OnSpawned");
        }

        private static void Prefix(object __instance, Entity spawnedCharacter, out LoadoutScope __state)
        {
            var next = TryGetContext(__instance, spawnedCharacter);
            __state = DeferredLoadouts.Push(next);
        }

        private static void Postfix(LoadoutScope __state)
            => DeferredLoadouts.Restore(__state);

        private static Exception? Finalizer(Exception? __exception, LoadoutScope __state)
        {
            DeferredLoadouts.Restore(__state);
            return __exception;
        }

        private static LoadoutContext? TryGetContext(object instance, Entity spawnedCharacter)
        {
            if (spawnedCharacter is not Character character) { return null; }
            FieldInfo? callbackField = instance.GetType().GetField("onSpawned", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (callbackField?.GetValue(instance) is not Delegate callback || callback.Target is null) { return null; }

            object? spawnAction = null;
            foreach (var field in callback.Target.GetType().GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                if (field.FieldType.FullName == "Barotrauma.SpawnAction")
                {
                    spawnAction = field.GetValue(callback.Target);
                    break;
                }
            }
            if (spawnAction is null) { return null; }

            var spawnPointTag = spawnAction.GetType().GetProperty("SpawnPointTag", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)?.GetValue(spawnAction)?.ToString();
            if (!SpawnPointFilter.Matches(spawnPointTag)) { return null; }
            bool lootingIsStealing = spawnAction.GetType().GetProperty("LootingIsStealing", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)?.GetValue(spawnAction) is true;
            return new LoadoutContext(character, lootingIsStealing);
        }
    }

    [HarmonyPatch]
    private static class HumanPrefabInitializeItemPatch
    {
        internal static MethodInfo? OriginalMethod { get; private set; }

        private static MethodBase? TargetMethod()
        {
            Type? type = AccessTools.TypeByName("Barotrauma.HumanPrefab");
            if (type is null) { return null; }
            OriginalMethod = AccessTools.Method(type, "InitializeItem", new[]
            {
                typeof(Character), typeof(ContentXElement), typeof(Submarine), type,
                typeof(WayPoint), typeof(Item), typeof(bool)
            });
            return OriginalMethod;
        }

        private static bool Prefix(Character character, ContentXElement itemElement, Submarine submarine, object humanPrefab,
            WayPoint spawnPoint, Item parentItem, bool createNetworkEvents)
        {
            return !DeferredLoadouts.TryEnqueue(character, itemElement, humanPrefab, submarine, spawnPoint, parentItem, createNetworkEvents);
        }

        internal static void InvokeOriginal(DeferredItem deferred)
        {
            MethodInfo? method = OriginalMethod ?? TargetMethod() as MethodInfo;
            if (method is null)
            {
                Console.Error.WriteLine("[EntitySpawnerBudget] HumanPrefab.InitializeItem was not found; deferred item dropped");
                return;
            }

            try
            {
                method.Invoke(null, new object?[]
                {
                    deferred.Character, deferred.ItemElement, deferred.Submarine, deferred.HumanPrefab,
                    deferred.SpawnPoint, null, deferred.CreateNetworkEvents
                });
            }
            catch (TargetInvocationException ex) when (ex.InnerException is not null)
            {
                ExceptionDispatchInfo.Capture(ex.InnerException).Throw();
            }
        }
    }
}
