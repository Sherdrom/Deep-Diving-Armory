using System.Runtime.CompilerServices;
using HarmonyLib;
using Barotrauma;
using Barotrauma.Networking;
using Microsoft.Xna.Framework;
using System.Reflection;
using System.Reflection.Emit;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace ThermalVisablePatch
{
    public partial class ThermalVisablePatch : IAssemblyPlugin
    {
#if CLIENT
        // 用于暂存未创建角色的同步消息
        private static Dictionary<ushort, bool> pendingHideSync = new Dictionary<ushort, bool>();
#endif
        public Harmony? harmonyInstance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("ThermalVisablePatch");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] ThermalVisablePatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            harmonyInstance?.PatchAll();
#if CLIENT
            // 注册同步HideInThermalGoggles的网络消息处理
            GameMain.LuaCs.Networking.Receive("SyncHideInThermalGoggles", args =>
            {
                var netMessage = args[0] as IReadMessage;
                if (netMessage == null) return;
                ushort characterId = netMessage.ReadUInt16();
                bool hide = netMessage.ReadBoolean();
                // var character = Character.CharacterList.Find(c => c.ID == characterId);
                Character character = Entity.FindEntityByID(characterId) as Character;
                if (character != null)
                {
                    character.Params.HideInThermalGoggles = hide;
                    LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT: Synced HideInThermalGoggles for '{character.Name}' to {hide}");
                }
                else
                {
                    // 角色未创建，暂存
                    pendingHideSync[characterId] = hide;
                    LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT: Character with ID {characterId} not found, pending HideInThermalGoggles sync.");
                }
            });
#endif
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] ThermalVisablePatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchSelf();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] ThermalVisablePatch Disposed!");
        }

        public static void NPCHideInThermalGoggles(Character character)
        {
            // 增加日志来调试
            if (character == null)
            {
                LuaCsSetup.PrintCsMessage("[Deep Diving Armory] NPCHideInThermalGoggles called with a null character!");
                return;
            }
            // LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] NPCHideInThermalGoggles check for character: '{character.Name}' (IsSingleplayer: {GameMain.IsSingleplayer})");

            if (character.Params.HideInThermalGoggles)
            {
                LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] Character '{character.Name}' is already set to HideInThermalGoggles.");
                return;
            }

            if (character.HumanPrefab != null && character.HumanPrefab.Tags.Contains("HideInThermalGoggles"))
            {
#if SERVER
                LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] SERVER: Hiding '{character.Name}'.");
                character.Params.HideInThermalGoggles = true;
                // 同步到所有客户端
                var message = GameMain.LuaCs.Networking.Start("SyncHideInThermalGoggles");
                message.WriteUInt16(character.ID); // 角色唯一ID
                message.WriteBoolean(true);
                GameMain.LuaCs.Networking.Send(message);
#elif CLIENT
                if (GameMain.IsSingleplayer)
                {
                    LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT (SP): Hiding '{character.Name}'.");
                    character.Params.HideInThermalGoggles = true;
                }
                else
                {
                    clientPendingSync(character);
                    LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT (MP): Try pendHiding '{character.Name} ");
                    if (character.Params.HideInThermalGoggles)
                    {
                        LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT (MP): Character '{character.Name}' is already set to HideInThermalGoggles.");
                        return;
                    }                   
                }
#endif
            }
        }

#if CLIENT
        public static void clientPendingSync(Character character)
        {
            if (character == null) return;
            if (pendingHideSync.TryGetValue(character.ID, out bool hide))
            {
                character.Params.HideInThermalGoggles = hide;
                pendingHideSync.Remove(character.ID);
                LuaCsSetup.PrintCsMessage($"[Deep Diving Armory] CLIENT: Applied pending HideInThermalGoggles for '{character.Name}'");
            }
        }
#endif
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
                LuaCsSetup.PrintCsMessage("[Deep Diving Armory] ThermalVisablePatch: Transpiler failed to find any insertion points in Character.Create.");
            }

            return codes.AsEnumerable();
        }
    }
}