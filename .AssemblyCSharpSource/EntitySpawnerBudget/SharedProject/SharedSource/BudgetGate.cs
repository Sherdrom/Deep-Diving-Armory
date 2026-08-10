using System.Diagnostics;
using System.Globalization;

namespace EntitySpawnerBudget;

public static class BudgetGate
{
    public const string EnvironmentVariable = "DDA_ENTITYSPAWNER_BUDGET_MS";
    public const double DefaultBudgetMilliseconds = 0.25;
    public const double MinimumBudgetMilliseconds = 0.25;
    public const double MaximumBudgetMilliseconds = 10.0;

    public static readonly double BudgetMilliseconds = ReadBudgetMilliseconds();

    [ThreadStatic]
    private static State? current;

    internal sealed class State
    {
        public readonly bool Throttled;
        public readonly long StartedAt;
        public readonly double BudgetMilliseconds;
        public bool GrantedFirst;

        public State(bool throttled)
        {
            Throttled = throttled;
            StartedAt = Stopwatch.GetTimestamp();
            BudgetMilliseconds = BudgetGate.BudgetMilliseconds;
        }
    }

    public sealed class Scope
    {
        internal readonly State? Previous;
        internal readonly State Current;
        internal bool Ended;

        internal Scope(State? previous, State current)
        {
            Previous = previous;
            Current = current;
        }
    }

    public sealed class MainTickScope
    {
        internal bool Ended;
    }

    [ThreadStatic]
    private static int mainTickDepth;

    public static bool MainTickActive => mainTickDepth > 0;

    public static bool IsThrottled(bool createNetworkEvents)
        => createNetworkEvents && MainTickActive;

    public static MainTickScope BeginMainTick()
    {
        mainTickDepth++;
        return new MainTickScope();
    }

    public static void EndMainTick(MainTickScope? scope)
    {
        if (scope is null || scope.Ended) { return; }
        if (mainTickDepth > 0) { mainTickDepth--; }
        scope.Ended = true;
    }

    public static Scope Begin(bool createNetworkEvents)
    {
        var previous = current;
        var next = new State(IsThrottled(createNetworkEvents));
        current = next;
        return new Scope(previous, next);
    }

    public static void End(Scope? scope)
    {
        if (scope is null || scope.Ended) { return; }
        if (ReferenceEquals(current, scope.Current)) { current = scope.Previous; }
        scope.Ended = true;
    }

    public static int FilterQueueCount(int count)
    {
        var state = current;
        if (state is null || !state.Throttled || count <= 0) { return count; }
        if (!state.GrantedFirst)
        {
            state.GrantedFirst = true;
            return count;
        }

        double elapsedMilliseconds = (Stopwatch.GetTimestamp() - state.StartedAt) * 1000.0 / Stopwatch.Frequency;
        return ShouldContinue(count, throttled: true, hasProcessed: true, elapsedMilliseconds, state.BudgetMilliseconds) ? count : 0;
    }

    public static bool ShouldContinue(int queueCount, bool throttled, bool hasProcessed, double elapsedMilliseconds, double budgetMilliseconds)
    {
        if (queueCount <= 0) { return false; }
        if (!throttled || !hasProcessed) { return true; }
        return elapsedMilliseconds < budgetMilliseconds;
    }

    private static double ReadBudgetMilliseconds()
    {
        string? raw = Environment.GetEnvironmentVariable(EnvironmentVariable);
        if (string.IsNullOrEmpty(raw)
            || !double.TryParse(raw, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture, out double parsed)
            || !double.IsFinite(parsed))
        {
            return DefaultBudgetMilliseconds;
        }
        return Math.Clamp(parsed, MinimumBudgetMilliseconds, MaximumBudgetMilliseconds);
    }
}

public static class SpawnPointFilter
{
    public const string RequiredTag = "deep_enemy_reinforce";

    public static bool Matches(string? spawnPointTag)
        => string.Equals(spawnPointTag, RequiredTag, StringComparison.Ordinal);
}
