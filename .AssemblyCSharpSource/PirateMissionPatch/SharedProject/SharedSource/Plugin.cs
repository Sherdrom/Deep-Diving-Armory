using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using System.Text;
using Barotrauma;
using Barotrauma.Extensions;
using Barotrauma.Items.Components;
using FarseerPhysics;
using HarmonyLib;
using Microsoft.Xna.Framework;

[assembly: IgnoresAccessChecksTo("Barotrauma")]
[assembly: IgnoresAccessChecksTo("DedicatedServer")]
[assembly: IgnoresAccessChecksTo("BarotraumaCore")]

namespace PirateMissionPatch
{
    public partial class PirateMissionPatch : IAssemblyPlugin
    {
        public Harmony? harmonyInstance;
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
            harmonyInstance = new Harmony("PirateMissionPatch");
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PirateMissionPatch Initialized!");
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
            harmonyInstance?.PatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PirateMissionPatch Loaded!");
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
            harmonyInstance?.UnpatchAll();
            LuaCsSetup.PrintCsMessage("[Deep Diving Armory] PirateMissionPatch Disposed!");
        }

        [HarmonyPatch(typeof(PirateMission), nameof(PirateMission.StartMissionSpecific))]
        static class PirateMission_StartMissionSpecific_Patch
        {
            private static bool IsDeepDivingMission(PirateMission mission)
            {
                return mission.Prefab.Identifier.ToString().Contains("deep");
            }
            // private static void MyInitPirateShip(PirateMission __instance)
            // {
            //     var enemySub = __instance.enemySub;
            //     enemySub.NeutralizeBallast();
            //     if (enemySub.GetItems(alsoFromConnectedSubs: false).Find(i => i.HasTag(Tags.Reactor) && !i.NonInteractable)?.GetComponent<Reactor>() is Reactor reactor)
            //     {
            //         reactor.PowerUpImmediately();
            //     }
            //     //enemySub.EnableMaintainPosition();
            //     enemySub.TeamID = CharacterTeamType.None;
            //     //防止海盗潜艇被水压摧毁
            //     enemySub.SetCrushDepth(Math.Max(enemySub.RealWorldCrushDepth, Submarine.MainSub.RealWorldCrushDepth));
            //     if (Level.Loaded != null)
            //     {
            //         //...and the depth of the patrol positions + 1000 m
            //         foreach (var patrolPos in __instance.patrolPositions)
            //         {
            //             enemySub.SetCrushDepth(Math.Max(enemySub.RealWorldCrushDepth, Level.Loaded.GetRealWorldDepth(patrolPos.Y) + 1000));
            //         }
            //     }
            //     //免疫丘脑
            //     enemySub.ImmuneToBallastFlora = true;
            //     enemySub.EnableFactionSpecificEntities(__instance.factionIdentifier);
            // }
            private static void MyCreateMissionPositions(out Vector2 preferredSpawnPos, PirateMission __instance)
            {
                var enemySub = __instance.enemySub;
                Vector2 patrolPos = Level.Loaded.EndPosition;
                patrolPos.Y = patrolPos.Y - 300f;
                patrolPos.X = patrolPos.X * 0.5f;;
                Point subSize = enemySub.GetDockedBorders().Size;
                preferredSpawnPos = patrolPos;

                if (Level.Loaded.TryGetInterestingPosition(true, Level.PositionType.MainPath, Level.Loaded.Size.X * 0.2f, out var potentialSpawnPos))
                {
                    preferredSpawnPos = potentialSpawnPos.Position.ToVector2();
                }
                else
                {
                    DebugConsole.ThrowError("Could not spawn pirate submarine in an interesting location! " + __instance,
                        contentPackage: __instance.Prefab.ContentPackage);
                }
                if (Level.Loaded.TryGetInterestingPositionAwayFromPoint(true, Level.PositionType.MainPath, Level.Loaded.Size.X * 0.2f, out var potentialPatrolPos, preferredSpawnPos, minDistFromPoint: 10000f))
                {
                    patrolPos = potentialPatrolPos.Position.ToVector2();
                }
                else
                {
                    DebugConsole.ThrowError("Could not give pirate submarine an interesting location to patrol to! " + __instance,
                        contentPackage: __instance.Prefab.ContentPackage);
                }

                patrolPos = enemySub.FindSpawnPos(patrolPos, subSize);

                __instance.patrolPositions.Add(patrolPos);
                __instance.patrolPositions.Add(preferredSpawnPos);

                // if (!Mission.IsClient)
                // {
                //     PathFinder pathFinder = new PathFinder(WayPoint.WayPointList, false);
                //     var path = pathFinder.FindPath(ConvertUnits.ToSimUnits(patrolPos), ConvertUnits.ToSimUnits(preferredSpawnPos));
                //     if (!path.Unreachable)
                //     {
                //         var validNodes = path.Nodes.FindAll(n => !Level.Loaded.ExtraWalls.Any(w => w.Cells.Any(c => c.IsPointInside(n.WorldPosition))));
                //         if (validNodes.Any())
                //         {
                //             preferredSpawnPos = validNodes.GetRandomUnsynced().WorldPosition; // spawn the sub in a random point in the path if possible
                //         }
                //     }

                //     int graceDistance = 500; // the sub still spawns awkwardly close to walls, so this helps. could also be given as a parameter instead
                //     preferredSpawnPos = enemySub.FindSpawnPos(preferredSpawnPos, new Point(subSize.X + graceDistance, subSize.Y + graceDistance));
                // }
            }
            static bool Prefix(PirateMission __instance, Level level)
            {
            if (IsDeepDivingMission(__instance))
            {
                LuaCsLogger.Log("PirateMission_StartMissionSpecific_Patch Prefix called!");
                // 跳过原方法，执行简化逻辑
                if (__instance.characters.Count > 0) __instance.characters.Clear();
                if (__instance.patrolPositions.Count > 0) __instance.patrolPositions.Clear();

                __instance.enemySub = Submarine.MainSubs[1];
                if (__instance.enemySub == null) return false;

                MyCreateMissionPositions(out Vector2 spawnPos, __instance);
                __instance.enemySub.SetPosition(spawnPos);
                __instance.InitPirateShip();
                __instance.enemySub.ShowSonarMarker = false;
                if (!Mission.IsClient) __instance.InitPirates();

                return false; // 跳过原始方法
            }
            return true; // 继续执行原始方法
            }
        }
    }
}
