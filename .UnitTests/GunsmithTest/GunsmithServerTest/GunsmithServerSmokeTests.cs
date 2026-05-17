using GunSmith;
using Xunit;

namespace GunsmithServerTest;

public sealed class GunsmithServerSmokeTests
{
    [Fact]
    public void ServerAssemblyReference_ExposesPluginType()
    {
        Assert.Equal("GunSmith", typeof(GunSmith.GunSmith).Namespace);
    }
}
