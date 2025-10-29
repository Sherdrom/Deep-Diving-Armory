using HarmonyLib;
using Barotrauma.Lights;
using Barotrauma;

namespace DeepVisionPatch;

[HarmonyPatch(typeof(LightSource),nameof(LightSource.Update))]
public class DrawNightVision
{
    public static void Postfix(LightSource __instance, float time)
    {
        
    }
}
