using System.Reflection.Emit;
using Barotrauma;
using HarmonyLib;

namespace ThermalVisablePatch
{
    public partial class ThermalVisablePatch : IAssemblyPlugin
    {
        // Client-specific code
        [HarmonyPatch(typeof(Barotrauma.Items.Components.StatusHUD), nameof(Barotrauma.Items.Components.StatusHUD.DrawThermalOverlay))]
        static class RangedWeapon_DrawHUD_Patch
        {
            static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
            {
                var codes = new List<CodeInstruction>(instructions);
                bool foundInsertionPoint = false;
                for (int i = 0; i < codes.Count; i++)
                {
                    if (codes[i].opcode == OpCodes.Call &&
                        codes[i].operand.ToString().Contains("get_Current") &&
                        i + 1 < codes.Count && codes[i + 1].opcode == OpCodes.Stloc_S &&
                        i + 2 < codes.Count && codes[i + 2].opcode == OpCodes.Ldloc_S &&
                        i + 3 < codes.Count && codes[i + 3].opcode == OpCodes.Ldarg_2)
                    {
                        foundInsertionPoint = true;
                        var injectCode = new List<CodeInstruction>
                        {
                            new CodeInstruction(OpCodes.Dup),      // 局部 (character)
                            new CodeInstruction(OpCodes.Call, typeof(ThermalVisablePatch).GetMethod("NPCHideInThermalGoggles"))
                        };
                        codes.InsertRange(i + 3, injectCode);
                        break;
                    }
                }
                if (!foundInsertionPoint)
                    throw new Exception("Failed to find insertion point in IL code! This may beacuse of other mod(s).");
                return codes;
            }
        }

        public static void NPCHideInThermalGoggles(Character character)
        {
            if (!character.Params.HideInThermalGoggles)
            {
                // ADD NULL CHECK HERE: Check if HumanPrefab is not null before accessing its properties.
                if (character.HumanPrefab != null && character.HumanPrefab.Tags.Contains("HideInThermalGoggles"))
                {
                    character.Params.HideInThermalGoggles = true;
                }
            }
        }


    }
}
