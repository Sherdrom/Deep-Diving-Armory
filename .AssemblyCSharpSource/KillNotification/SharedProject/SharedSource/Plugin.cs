using Barotrauma.Sounds;
using HarmonyLib;
using Microsoft.Xna.Framework.Graphics;

namespace KillNotification
{
    public partial class KillNotification : IAssemblyPlugin
    {
        public readonly string Name = "Kill Notification";
        private const float NotificationDuration = 4f;
        private List<KillInfo> killInfos = new List<KillInfo>();
        public Harmony? harmonyInstance;
        public static KillNotification instance;
        public static float FontScale = 1.8f;

        public KillNotification()
        {
            instance = this;
        }

        public void Initialize()
        {
            harmonyInstance = new Harmony("Kill.Notification");
        }

        public void OnLoadCompleted()
        {
            harmonyInstance.PatchAll();

            if (LuaCsSetup.Instance?.Hook is ILuaEventService eventService)
            {
                eventService.Add("think", "KillNotificationThink", Update);
                eventService.Add("attack", "KillNotificationAttack", OnAttack);
                eventService.Add("characterDeath", "KillNotificationCharacterDeath", OnCharacterDeath);
            }

            LuaCsLogger.Log($"Kill Notification loaded!");
        }

        public void Dispose()
        {
            harmonyInstance?.UnpatchSelf();
            try
            {
                if (LuaCsSetup.Instance?.Hook is ILuaEventService eventService)
                {
                    var removeMethod = typeof(ILuaEventService).GetMethod("Remove", new[] { typeof(string), typeof(string) });
                    if (removeMethod != null)
                    {
                        removeMethod.Invoke(eventService, new object[] { "think", "KillNotificationThink" });
                        removeMethod.Invoke(eventService, new object[] { "attack", "KillNotificationAttack" });
                        removeMethod.Invoke(eventService, new object[] { "characterDeath", "KillNotificationCharacterDeath" });
                    }
                }
            }
            catch { }
        }

        public void PreInitPatching() { }

        private object[] Update(object[] args)
        {
            float deltaTime = (float)Timing.Step;
            killInfos.RemoveAll(ki => ki.RemainingTime <= 0);
            foreach (var ki in killInfos)
            {
                ki.RemainingTime -= deltaTime;
            }
            return null;
        }

        public static void DrawKillNotifications(SpriteBatch spriteBatch)
        {
            var inst = KillNotification.instance;
            if (inst == null) return;

            if (inst.killInfos.Count > 0 && GameMain.GameScreen != null)
            {
                float yOffset = 10f;
                float spacing = 30f;

                foreach (var killInfo in inst.killInfos)
                {
                    float alpha = MathHelper.Clamp(killInfo.RemainingTime / NotificationDuration, 0f, 1f);
                    Color color = killInfo.IsVictimTeam1 ? new Color(255, 0, 0, alpha) : new Color(255, 255, 255, alpha);

                    string text;
                    if (killInfo.IsAfflictionDeath)
                    {
                        string affName = killInfo.AfflictionName ?? "Accident";
                        text = $"{killInfo.VictimName} Die From {affName}";
                    }
                    else
                    {
                        text = $"{killInfo.AttackerName} Kill {killInfo.VictimName}";
                    }

                    var font = GUIStyle.Font ?? GUIStyle.SmallFont;
                    if (font == null) continue;

                    Vector2 textSize = font.MeasureString(text) * FontScale;

                    Vector2 position = new Vector2(
                        GameMain.GraphicsWidth - textSize.X - 20f,
                        yOffset
                    );

                    try
                    {
                        spriteBatch.End();
                        spriteBatch.Begin(SpriteSortMode.Deferred, BlendState.NonPremultiplied, SamplerState.LinearClamp, DepthStencilState.None, RasterizerState.CullCounterClockwise, null, Matrix.CreateScale(FontScale));
                        GUI.DrawString(spriteBatch, position / FontScale, text, color, Color.Black * 0.5f, 0, font);
                        spriteBatch.End();
                        spriteBatch.Begin(SpriteSortMode.Deferred, BlendState.NonPremultiplied, SamplerState.LinearClamp, DepthStencilState.None, RasterizerState.CullCounterClockwise);
                    }
                    catch { }

                    yOffset += textSize.Y + spacing;
                }
            }
        }

        [HarmonyPatch(typeof(GUI), nameof(GUI.Draw))]
        static class GUI_Draw_Patch
        {
            static void Postfix(SpriteBatch spriteBatch)
            {
                DrawKillNotifications(spriteBatch);
            }
        }

        private object[] OnAttack(object[] args)
        {
            if (args == null || args.Length < 3) return null;

            Character character = args[0] as Character;
            Character attacker = args[1] as Character;
            AttackResult result = (AttackResult)args[2];

            if (attacker != null && character != null && character.IsDead && (attacker.TeamID == CharacterTeamType.Team1 || character.TeamID == CharacterTeamType.Team1))
            {
                string attackerName = GetCharacterName(attacker);
                string victimName = GetCharacterName(character);
                bool isVictimTeam1 = character.TeamID == CharacterTeamType.Team1;
                killInfos.Add(new KillInfo(attackerName, victimName, NotificationDuration, false, null, isVictimTeam1));

                if (isVictimTeam1)
                {
                    try { SoundPlayer.PlaySound("deep_player_death", 0.5f); } catch { }
                }
                else
                {
                    try { if (Character.Controlled == attacker && character.IsHuman) SoundPlayer.PlaySound("deep_player_kill", 0.8f); } catch { }
                }
            }
            return null;
        }

        private object[] OnCharacterDeath(object[] args)
        {
            if (args == null || args.Length < 1) return null;

            Character character = args[0] as Character;

            if (character == null || character.IsDead == false) return null;

            Character attacker = FindAttackerFromAfflictions(character);

            bool isTeam1Involved = (character.TeamID == CharacterTeamType.Team1) || (attacker != null && attacker.TeamID == CharacterTeamType.Team1);
            if (!isTeam1Involved) return null;

            bool isVictimTeam1 = character.TeamID == CharacterTeamType.Team1;

            if (attacker != null && attacker != character)
            {
                string attackerName = GetCharacterName(attacker);
                string victimName = GetCharacterName(character);
                killInfos.Add(new KillInfo(attackerName, victimName, NotificationDuration, false, null, isVictimTeam1));

                if (isVictimTeam1)
                {
                    try { SoundPlayer.PlaySound("deep_player_death", 0.5f); } catch { }
                }
                else
                {
                    try { if (Character.Controlled == attacker && character.IsHuman) SoundPlayer.PlaySound("deep_player_kill", 0.8f); } catch { }
                }
            }
            else
            {
                string victimName = GetCharacterName(character);
                string afflictionName = "Accident";

                try
                {
                    if (character.CharacterHealth != null)
                    {
                        var afflictions = character.CharacterHealth.GetAllAfflictions();
                        if (afflictions != null)
                        {
                            foreach (var affliction in afflictions)
                            {
                                if (affliction != null)
                                {
                                    string typeName = affliction.GetType().Name;
                                    if (!string.IsNullOrEmpty(typeName))
                                    {
                                        if (typeName.EndsWith("Affliction") && typeName.Length >= 11)
                                        {
                                            typeName = typeName.Substring(0, typeName.Length - 11);
                                        }
                                        afflictionName = typeName;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                catch { }

                if (string.IsNullOrEmpty(afflictionName)) afflictionName = "Accident";

                killInfos.Add(new KillInfo(victimName, afflictionName, NotificationDuration, true, afflictionName, isVictimTeam1));

                if (isVictimTeam1)
                {
                    try { SoundPlayer.PlaySound("deep_player_death", 0.5f); } catch { }
                }
            }
            return null;
        }

        private Character FindAttackerFromAfflictions(Character character)
        {
            if (character == null) return null;
            if (character.CharacterHealth == null) return null;

            var afflictions = character.CharacterHealth.GetAllAfflictions();

            foreach (var affliction in afflictions)
            {
                if (affliction.Source != null && affliction.Source != character)
                {
                    return affliction.Source;
                }
            }

            return null;
        }

        private string GetCharacterName(Character character)
        {
            if (character == null) return "未知";

            if (!string.IsNullOrEmpty(character.Name)) return character.Name;

            if (character.TeamID == CharacterTeamType.Team1)
            {
                if (character.Prefab != null && character.Prefab.Name != null)
                {
                    string prefabName = character.Prefab.Name.ToString();
                    if (!string.IsNullOrEmpty(prefabName)) return prefabName;
                }
            }

            if (character.Prefab != null && !string.IsNullOrEmpty(character.Prefab.Identifier.ToString()))
            {
                string key = "character." + character.Prefab.Identifier.ToString();
                var localizedString = TextManager.Get(key);
                string localizedName = localizedString?.Value ?? "";
                if (!string.IsNullOrEmpty(localizedName) && localizedName != key) return localizedName;
            }

            if (character.Prefab != null && character.Prefab.Name != null)
            {
                string prefabName = character.Prefab.Name.ToString();
                if (!string.IsNullOrEmpty(prefabName)) return prefabName;
            }

            if (character.SpeciesName != null)
            {
                string speciesName = character.SpeciesName.ToString();
                if (!string.IsNullOrEmpty(speciesName)) return speciesName;
            }

            string typeName = character.GetType().Name;
            if (!string.IsNullOrEmpty(typeName)) return typeName;

            return "未知";
        }

        private class KillInfo
        {
            public string AttackerName { get; set; }
            public string VictimName { get; set; }
            public string AfflictionName { get; set; }
            public bool IsAfflictionDeath { get; set; }
            public float RemainingTime { get; set; }
            public bool IsVictimTeam1 { get; set; }

            public KillInfo(string attackerName, string victimName, float duration, bool isAfflictionDeath = false, string afflictionName = null, bool isVictimTeam1 = false)
            {
                AttackerName = attackerName;
                VictimName = victimName;
                AfflictionName = afflictionName;
                IsAfflictionDeath = isAfflictionDeath;
                RemainingTime = duration;
                IsVictimTeam1 = isVictimTeam1;
            }
        }
    }
}
