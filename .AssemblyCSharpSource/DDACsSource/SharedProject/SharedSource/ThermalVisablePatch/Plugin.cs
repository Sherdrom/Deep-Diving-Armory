namespace ThermalVisablePatch
{
    public partial class ThermalVisablePatch
    {
#if CLIENT
        // 用于暂存未创建角色的同步消息
        private static Dictionary<ushort, bool> pendingHideSync = new Dictionary<ushort, bool>();
#endif
        [NetworkSerialize]
        internal readonly record struct ThermalState(ushort CharacterId, bool Hide) : INetSerializableStruct;

#if CLIENT
        internal static void Register() => DeepDivingArmory.Plugin.Network.RegisterHandler<NetworkHeader, ThermalState>(NetworkHeader.Thermal, state =>
        {
            if (Entity.FindEntityByID(state.CharacterId) is Character character)
                character.Params.HideInThermalGoggles = state.Hide;
            else
                pendingHideSync[state.CharacterId] = state.Hide;
        });

        internal static void ClearRound() => pendingHideSync.Clear();
#endif

        public static void NPCHideInThermalGoggles(Character character)
        {
#if CLIENT
            if (pendingHideSync.Remove(character.ID, out bool hide))
            {
                character.Params.HideInThermalGoggles = hide;
                return;
            }
#endif
            if (character.Params.HideInThermalGoggles ||
                character.HumanPrefab?.Tags.Contains("HideInThermalGoggles") != true) { return; }
#if SERVER
            character.Params.HideInThermalGoggles = true;
            DeepDivingArmory.Plugin.Network.Broadcast(NetworkHeader.Thermal, new ThermalState(character.ID, true));
#else
            if (GameMain.IsSingleplayer) { character.Params.HideInThermalGoggles = true; }
#endif
        }
    }

    [HarmonyPatch]
    public static class Patch
    {
        [HarmonyPatch(typeof(Character), nameof(Character.Create), new Type[] { typeof(CharacterPrefab), typeof(Vector2), typeof(string), typeof(CharacterInfo), typeof(ushort), typeof(bool), typeof(bool), typeof(bool), typeof(RagdollParams), typeof(bool) })]
        static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
        {
            var codes = new List<CodeInstruction>(instructions);
            bool patched = false;

            // We will look for constructor calls for Character or any of its subclasses (like AICharacter).
            // This is much more robust than matching the constructor's string representation.
            var characterConstructorMatcher = new Func<object, bool>(operand =>
                operand is MethodBase method &&
                method.IsConstructor &&
                typeof(Character).IsAssignableFrom(method.DeclaringType)
            );

            // Iterate through the code to find all character creation points.
            // We must adjust the index 'i' after insertion to avoid issues with modifying the collection.
            for (int i = 0; i < codes.Count - 1; i++)
            {
                // Is the current instruction a 'newobj' for a Character or subclass?
                if (codes[i].opcode == OpCodes.Newobj && characterConstructorMatcher(codes[i].operand))
                {
                    // The next instruction should be storing this new character into a local variable (stloc).
                    var stlocInstruction = codes[i + 1];
                    if (stlocInstruction.IsStloc()) // IsStloc is a handy HarmonyLib extension method.
                    {
                        // We found an insertion point.
                        patched = true;

                        // Manually create the corresponding ldloc instruction because ToLdloc()
                        // is not available in this version of HarmonyLib.
                        OpCode? ldlocOpCode = null;
                        if (stlocInstruction.opcode == OpCodes.Stloc_0) { ldlocOpCode = OpCodes.Ldloc_0; }
                        else if (stlocInstruction.opcode == OpCodes.Stloc_1) { ldlocOpCode = OpCodes.Ldloc_1; }
                        else if (stlocInstruction.opcode == OpCodes.Stloc_2) { ldlocOpCode = OpCodes.Ldloc_2; }
                        else if (stlocInstruction.opcode == OpCodes.Stloc_3) { ldlocOpCode = OpCodes.Ldloc_3; }
                        else if (stlocInstruction.opcode == OpCodes.Stloc_S) { ldlocOpCode = OpCodes.Ldloc_S; }
                        else if (stlocInstruction.opcode == OpCodes.Stloc) { ldlocOpCode = OpCodes.Ldloc; }

                        // This check should always pass if IsStloc() was true, but it's good practice.
                        if (ldlocOpCode != null)
                        {
                            // Create the ldloc instruction, making sure to copy the operand
                            // which is important for opcodes like Ldloc_S.
                            var ldlocInstruction = new CodeInstruction(ldlocOpCode.Value, stlocInstruction.operand);

                            var injectCode = new List<CodeInstruction>
                            {
                                ldlocInstruction,
                                new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(ThermalVisablePatch), nameof(ThermalVisablePatch.NPCHideInThermalGoggles)))
                            };

                            // Insert our code *after* the stloc instruction.
                            codes.InsertRange(i + 2, injectCode);

                            // IMPORTANT: Adjust the loop index to skip over the code we just inserted.
                            i += injectCode.Count;
                        }
                    }
                }
            }

            if (!patched)
            {
                // Use a log message instead of throwing an exception for better mod compatibility.
                DebugConsole.NewMessage("[Deep Diving Armory] ThermalVisablePatch: Transpiler failed to find any insertion points in Character.Create.");
            }

            return codes.AsEnumerable();
        }
    }
}