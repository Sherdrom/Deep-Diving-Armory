namespace GunSmith
{
    public partial class GunSmith : IAssemblyPlugin
    {
        partial void InitializePlatform()
        {
        }

        partial void OnLoadCompletedPlatform()
        {
            GunsmithApi.Initialize(GameMain.GraphicsDeviceManager.GraphicsDevice);
            if (LuaCsSetup.Instance?.Hook is Barotrauma.LuaCs.Compatibility.ILuaCsHook hook)
            {
                GunsmithApi.RegisterLuaHooks(hook);
            }
            else
            {
                LuaCsSetup.PrintCsMessage("[Gunsmith] Compatibility hook is unavailable; Lua bridge not registered.");
            }
        }

        partial void DisposePlatform()
        {
            GunsmithApi.Dispose();
        }
    }
}
