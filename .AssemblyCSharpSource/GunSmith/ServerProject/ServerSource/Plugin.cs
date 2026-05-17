namespace GunSmith
{
    public partial class GunSmith : IAssemblyPlugin
    {
        partial void InitializePlatform()
        {
        }

        partial void OnLoadCompletedPlatform()
        {
            if (LuaCsSetup.Instance?.Hook is Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
            {
                GunsmithServerHooks.RegisterLuaHooks(hook);
            }
            else
            {
                LuaCsSetup.PrintCsMessage("[Gunsmith] Compatibility hook is unavailable; server Lua bridge not registered.");
            }
        }

        partial void DisposePlatform()
        {
        }
    }
}
