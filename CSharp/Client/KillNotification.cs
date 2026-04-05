using Barotrauma;
using Barotrauma.Sounds;
using HarmonyLib;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;
using System.Reflection.Emit;

namespace KillNotification
{
    public class KillNotification : IAssemblyPlugin
    {
        public readonly string Name = "Kill Notification";
        private const float NotificationDuration = 3f;
        private List<KillInfo> killInfos = new List<KillInfo>();
        public Harmony? harmonyInstance;
        public static KillNotification instance;

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
            GameMain.LuaCs.Hook.Add("think", "KillNotificationThink", Update);
            GameMain.LuaCs.Hook.Add("attack", "KillNotificationAttack", OnAttack);
            GameMain.LuaCs.Hook.Add("characterDeath", "KillNotificationCharacterDeath", OnCharacterDeath);
        }

        public void Dispose()
        {
            harmonyInstance?.UnpatchSelf();
            GameMain.LuaCs.Hook.Remove("think", "KillNotificationThink");
            GameMain.LuaCs.Hook.Remove("attack", "KillNotificationAttack");
            GameMain.LuaCs.Hook.Remove("characterDeath", "KillNotificationCharacterDeath");
        }

        public void PreInitPatching()
        {
        }

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

        // 静态绘制方法，用于 Harmony 补丁调用
        public static void DrawKillNotifications(SpriteBatch spriteBatch)
        {
            // 获取插件实例
            var instance = KillNotification.instance;
            if (instance == null)
            {
                return;
            }
            
            if (instance.killInfos.Count > 0 && GameMain.GameScreen != null)
            {
                float yOffset = 10f;
                float spacing = 30f;

                foreach (var killInfo in instance.killInfos)
                {
                    float alpha = MathHelper.Clamp(killInfo.RemainingTime / NotificationDuration, 0f, 1f);
                    Color color = killInfo.IsVictimTeam1 ? new Color(255, 0, 0, alpha) : new Color(255, 255, 255, alpha);

                    string text;
                    if (killInfo.IsAfflictionDeath)
                    {
                        // 确保 AfflictionName 不为空
                        string affName = killInfo.AfflictionName ?? "Accident";
                        text = $"{killInfo.VictimName} Die From {affName}";
                    }
                    else
                    {
                        text = $"{killInfo.AttackerName} Kill {killInfo.VictimName}";
                    }
                    
                    // 使用较大的字体
                    var font = GUIStyle.LargeFont ?? GUIStyle.Font ?? GUIStyle.SmallFont;
                    if (font == null)
                    {
                        continue;
                    }
                    
                    Vector2 textSize = font.MeasureString(text);
                    
                    Vector2 position = new Vector2(
                        GameMain.GraphicsWidth - textSize.X - 20f,
                        yOffset
                    );
                    
                    // 使用 GUI.DrawString 方法绘制
                    try
                    {
                        GUI.DrawString(spriteBatch, position, text, color, Color.Black * 0.5f, 0, font);
                    } catch {}
                    
                    yOffset += textSize.Y + spacing;
                }
            }
        }

        // Harmony 补丁，用于在游戏绘制流程中调用我们的绘制方法
        [HarmonyPatch(typeof(GUI), nameof(GUI.Draw))]
        static class GUI_Draw_Patch
        {
            static void Postfix(SpriteBatch spriteBatch)
            {
                // 在 GUI.Draw 方法执行完成后调用我们的绘制方法
                DrawKillNotifications(spriteBatch);
            }
        }

        private object[] OnAttack(object[] args)
        {
            if (args == null || args.Length < 3)
            {
                return null;
            }
            
            Character character = args[0] as Character;
            Character attacker = args[1] as Character;
            AttackResult result = (AttackResult)args[2];

            if (attacker != null && character != null && character.IsDead && (attacker.TeamID == CharacterTeamType.Team1 || character.TeamID == CharacterTeamType.Team1))
            {
                string attackerName = GetCharacterName(attacker);
                string victimName = GetCharacterName(character);
                bool isVictimTeam1 = character.TeamID == CharacterTeamType.Team1;
                killInfos.Add(new KillInfo(attackerName, victimName, NotificationDuration, false, null, isVictimTeam1));
                
                // 当 team1 生物死亡时播放音效
                if (isVictimTeam1)
                {
                    try
                    {
                        // 播放音效
                        SoundPlayer.PlaySound("deep_player_death", 0.5f);
                    } catch {}
                }
                // 当不是 team1 的生物死亡时，播放击杀音效
                else
                {
                    try
                    {
                        // 只有攻击者能听到击杀音效
                        if (Character.Controlled == attacker)
                        {
                            // 播放音效
                            SoundPlayer.PlaySound("deep_player_kill", 0.8f);
                        }
                    } catch {}
                }
            }
            return null;
        }

        private object[] OnCharacterDeath(object[] args)
        {
            if (args == null || args.Length < 1)
            {
                return null;
            }
            
            Character character = args[0] as Character;
            
            if (character == null || character.IsDead == false)
            {
                return null;
            }

            // 检查角色的 Affliction，找到导致死亡的 Affliction 的 Source
            Character attacker = FindAttackerFromAfflictions(character);
            
            // 只有当 team1 的生物是攻击者或受害者时，才显示信息
            bool isTeam1Involved = (character.TeamID == CharacterTeamType.Team1) || (attacker != null && attacker.TeamID == CharacterTeamType.Team1);
            if (!isTeam1Involved)
            {
                return null;
            }
            
            bool isVictimTeam1 = character.TeamID == CharacterTeamType.Team1;
            
            if (attacker != null && attacker != character)
            {
                string attackerName = GetCharacterName(attacker);
                string victimName = GetCharacterName(character);
                killInfos.Add(new KillInfo(attackerName, victimName, NotificationDuration, false, null, isVictimTeam1));
                
                // 当 team1 生物死亡时播放音效
                if (isVictimTeam1)
                {
                    try
                    {
                        // 播放指定路径的音效
                        try
                        {
                            // 播放音效
                            SoundPlayer.PlaySound("deep_player_death", 0.5f);
                        } catch {}
                    } catch {}
                }
                // 当不是 team1 的生物死亡时，也播放音效
                else
                {
                    try
                    {
                        // 只有攻击者能听到击杀音效
                        if (Character.Controlled == attacker)
                        {
                            // 播放音效
                            SoundPlayer.PlaySound("deep_player_kill", 0.8f);
                        }
                    } catch {}
                }
            }
            else
            {
                // 找不到攻击者，显示死于 Affliction 的信息
                string victimName = GetCharacterName(character);
                string afflictionName = "Accident";
                
                // 尝试获取 Affliction 信息
                try
                {
                    if (character.CharacterHealth != null)
                    {
                        var afflictions = character.CharacterHealth.GetAllAfflictions();
                        if (afflictions != null)
                        {
                            // 尝试获取第一个有效的 Affliction 名称
                            foreach (var affliction in afflictions)
                            {
                                if (affliction != null)
                                {
                                    // 尝试多种方式获取 Affliction 名称
                                    // 1. 尝试使用类型名称
                                    string typeName = affliction.GetType().Name;
                                    if (!string.IsNullOrEmpty(typeName))
                                    {
                                        // 移除 "Affliction" 后缀
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
                } catch {}
                
                // 确保 afflictionName 不为空
                if (string.IsNullOrEmpty(afflictionName))
                {
                    afflictionName = "Accident";
                }
                
                killInfos.Add(new KillInfo(victimName, afflictionName, NotificationDuration, true, afflictionName, isVictimTeam1));
                
                // 当 team1 生物死亡时播放音效
                if (isVictimTeam1)
                {
                    try
                    {
                        // 播放指定路径的音效
                        try
                        {
                            // 播放音效
                            SoundPlayer.PlaySound("deep_player_death", 0.5f);
                        } catch {}
                    } catch {}
                }
                // 当不是 team1 的生物死亡时，也播放音效
                else
                {
                    // 找不到攻击者，不播放击杀音效
                }
            }
            return null;
        }

        private Character FindAttackerFromAfflictions(Character character)
        {
            if (character == null)
            {
                return null;
            }
            
            if (character.CharacterHealth == null)
            {
                return null;
            }

            // 检查角色整体的 Affliction
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

        private string FindMainAffliction(Character character)
        {
            if (character == null || character.CharacterHealth == null)
            {
                return null;
            }

            // 检查角色整体的 Affliction，找到主要的 Affliction
            var afflictions = character.CharacterHealth.GetAllAfflictions();
            foreach (var affliction in afflictions)
            {
                // 尝试不同的方式获取 Affliction 名称
                if (affliction.Prefab != null)
                {
                    if (affliction.Prefab.Name != null && !string.IsNullOrEmpty(affliction.Prefab.Name.Value))
                    {
                        return affliction.Prefab.Name.Value;
                    }
                    // 尝试使用 Affliction 的其他属性作为名称
                    if (affliction.Prefab.Identifier != null)
                    {
                        return affliction.Prefab.Identifier.ToString();
                    }
                }
                // 尝试直接使用 Affliction 的字符串表示
                string afflictionStr = affliction.ToString();
                if (!string.IsNullOrEmpty(afflictionStr))
                {
                    return afflictionStr;
                }
            }

            return null;
        }

        private string GetCharacterName(Character character)
        {
            if (character == null)
            {
                return "未知";
            }

            // 首先尝试获取角色的显示名称（无论是哪个团队）
            if (!string.IsNullOrEmpty(character.Name))
            {
                return character.Name;
            }

            // 对于 team1 的生物（玩家），如果没有显示名称，使用其他方式获取
            if (character.TeamID == CharacterTeamType.Team1)
            {
                // 尝试获取角色的 Prefab 名称
                if (character.Prefab != null && character.Prefab.Name != null)
                {
                    string prefabName = character.Prefab.Name.ToString();
                    if (!string.IsNullOrEmpty(prefabName))
                    {
                        return prefabName;
                    }
                }
            }

            // 对于其他生物，尝试获取本地化名称
            if (character.Prefab != null && !string.IsNullOrEmpty(character.Prefab.Identifier.ToString()))
            {
                string key = "character." + character.Prefab.Identifier.ToString();
                var localizedString = TextManager.Get(key);
                string localizedName = localizedString?.Value ?? "";
                if (!string.IsNullOrEmpty(localizedName) && localizedName != key)
                {
                    return localizedName;
                }
            }

            // 尝试获取角色的 Prefab 名称
            if (character.Prefab != null && character.Prefab.Name != null)
            {
                string prefabName = character.Prefab.Name.ToString();
                if (!string.IsNullOrEmpty(prefabName))
                {
                    return prefabName;
                }
            }

            // 尝试获取角色的 SpeciesName
            if (character.SpeciesName != null)
            {
                string speciesName = character.SpeciesName.ToString();
                if (!string.IsNullOrEmpty(speciesName))
                {
                    return speciesName;
                }
            }

            // 尝试获取角色的类型名称
            string typeName = character.GetType().Name;
            if (!string.IsNullOrEmpty(typeName))
            {
                return typeName;
            }

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
