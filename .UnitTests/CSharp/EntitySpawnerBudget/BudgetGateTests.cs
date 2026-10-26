using Xunit;

namespace EntitySpawnerBudget.Tests;

public sealed class BudgetGateTests
{
    [Fact]
    public void EmptyQueueStops()
        => Assert.False(BudgetGate.ShouldContinue(0, throttled: true, hasProcessed: false, 0, 2));

    [Fact]
    public void FirstEntryAlwaysRuns()
        => Assert.True(BudgetGate.ShouldContinue(1, throttled: true, hasProcessed: false, 999, 2));

    [Fact]
    public void ProcessedQueueStopsAfterBudget()
        => Assert.False(BudgetGate.ShouldContinue(1, throttled: true, hasProcessed: true, 3, 2));

    [Fact]
    public void UnthrottledQueueAlwaysRuns()
        => Assert.True(BudgetGate.ShouldContinue(1, throttled: false, hasProcessed: true, 999, 2));

    [Fact]
    public void OnlyNetworkedMainTickUpdatesAreThrottled()
    {
        Assert.False(BudgetGate.IsThrottled(createNetworkEvents: true));
        Assert.False(BudgetGate.IsThrottled(createNetworkEvents: false));

        var mainTick = BudgetGate.BeginMainTick();
        try
        {
            Assert.True(BudgetGate.IsThrottled(createNetworkEvents: true));
            Assert.False(BudgetGate.IsThrottled(createNetworkEvents: false));
        }
        finally
        {
            BudgetGate.EndMainTick(mainTick);
        }

        Assert.False(BudgetGate.IsThrottled(createNetworkEvents: true));
    }

    [Theory]
    [InlineData("deep_enemy_reinforce", true)]
    [InlineData("reinforce", false)]
    [InlineData("deep_hunter", false)]
    [InlineData(null, false)]
    public void SpawnPointFilterIsExact(string? tag, bool expected)
        => Assert.Equal(expected, SpawnPointFilter.Matches(tag));
}
