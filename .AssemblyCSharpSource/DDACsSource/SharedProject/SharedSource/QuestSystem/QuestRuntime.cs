namespace DeepDivingArmory.Quests;

[NetworkSerialize]
internal readonly record struct QuestRequest(byte Action, string Quest, ushort Speaker, string Round, int Revision, string ObjectiveId) : INetSerializableStruct;
[NetworkSerialize]
internal readonly record struct QuestSnapshot(string Round, int Revision, string State, bool Declined) : INetSerializableStruct;

public static partial class QuestRuntime
{
    internal static QuestRules Rules { get; private set; } = new();
    internal static QuestState State { get; private set; } = new();
    internal static string Round { get; private set; } = "";
    internal static int Revision { get; private set; }
    private static CampaignMode? campaign;
    private static bool readable;
    private static float stockTimer;
    private static readonly Identifier MetadataKey = "dda.quest.state".ToIdentifier();
#if CLIENT
    private static bool Authority => GameMain.IsSingleplayer;
#else
    private const bool Authority = true;
#endif

    internal static void Register(ISimpleHookService hooks)
    {
        try { Rules = QuestRules.Load(Path.Combine(Plugin.Package.Dir, "Config", "Quests")); }
        catch (Exception e) { DebugConsole.ThrowError("[DDA] Quest rules: " + e.Message); }
        hooks.RegisterHook<PluginRoundStartedDelegate>(StartRound);
        hooks.RegisterHook<PluginCampaignOnEnterOutpostDelegate>(EnterOutpost);
        hooks.RegisterHook<PluginOnPostUpdateDelegate>(Update);
        RegisterSide(hooks);
    }

    private static void StartRound(GameSession session)
    {
        if (Authority && session.Campaign is { } mode && EnsureCampaign(mode) &&
            Level.Loaded?.Type == LevelData.LevelType.LocationConnection && State.LastPort >= 0)
        {
            State.LastPort = -1;
            Changed(true);
        }
        StartSide();
    }

    private static bool EnsureCampaign(CampaignMode mode)
    {
        if (ReferenceEquals(campaign, mode)) { return readable; }
        campaign = mode;
        readable = false;
        try { State = QuestState.Read(mode.CampaignMetadata.GetString(MetadataKey)); }
        catch (Exception e) { DebugConsole.ThrowError("[DDA] Cannot read quest state: " + e.Message); return false; }
        Round = Guid.NewGuid().ToString("N");
        Revision = 0;
        readable = true;
        return true;
    }

    private static void EnterOutpost(CampaignMode mode, Location location, Submarine outpost)
    {
        if (!Authority || location == null || !EnsureCampaign(mode)) { return; }
        int port = mode.Map.Locations.IndexOf(location);
        if (port < 0 || port == State.LastPort) { return; }
        State.LastPort = port;
        State.Advance(Rules, ObjectiveType.ReachLocation, id => id == "*" || location.Type.Identifier == id || location.NameIdentifier == id);
        Changed(true);
    }

    private static void Update(float deltaTime)
    {
        UpdateSide();
        if (!Authority || GameMain.GameSession is not { IsRunning: true, Campaign: { } mode } || !EnsureCampaign(mode)) { return; }
        stockTimer -= deltaTime;
        if (stockTimer > 0) { return; }
        stockTimer = 1;
        if (RefreshStock()) { Changed(false); }
    }

    internal static bool InReach(Character? actor, Character npc)
    {
        const float interactionDistance = 200f;
        return actor != null && Vector2.DistanceSquared(actor.WorldPosition, npc.WorldPosition) <=
            interactionDistance * interactionDistance && actor.CanInteractWith(npc, interactionDistance);
    }

    internal static Publisher? Match(Character? npc)
    {
        if (npc?.HumanPrefab is not { } prefab || npc.IsDead || npc.Removed || npc.IsOnPlayerTeam) { return null; }
        return Rules.Npcs.Values.FirstOrDefault(n => prefab.Identifier == n.Identifier || n.Tags.Any(tag => prefab.GetTags().Contains(tag.ToIdentifier())));
    }

    /// <summary>Credits active custom objectives with this target on the authoritative game thread.</summary>
    public static void ReportCustom(string target, int amount = 1) => Advance(ObjectiveType.Custom, id => id == target, amount);

    internal static void Advance(ObjectiveType type, Func<string, bool> matches, int amount = 1)
    {
        if (Authority && GameMain.GameSession?.Campaign is { } mode && EnsureCampaign(mode) &&
            State.Advance(Rules, type, matches, amount)) { Changed(true); }
    }

    private static void Changed(bool persist)
    {
        if (persist) { campaign!.CampaignMetadata.SetValue(MetadataKey, State.Write()); }
        Revision++;
        Publish();
    }

    internal static void ClearRound()
    {
        ClearSide();
        campaign = null;
        readable = false;
        Round = "";
        Revision = 0;
        stockTimer = 0;
        State = new();
    }

    internal static void Dispose()
    {
        DisposeSide();
        Rules = new();
    }

    static partial void RegisterSide(ISimpleHookService hooks);
    static partial void StartSide();
    static partial void UpdateSide();
    static partial void ClearSide();
    static partial void DisposeSide();
    static partial void Publish();
}

[HarmonyPatch(typeof(Character), nameof(Character.RecordKill))]
internal static class QuestKill
{
    private static void Postfix(Character __instance, Character target)
    {
        if (__instance.IsOnPlayerTeam && !target.IsOnPlayerTeam)
        {
            QuestRuntime.Advance(ObjectiveType.KillTag, id => target.MatchesSpeciesNameOrGroup(id.ToIdentifier()) ||
            target.Params.HasTag(id.ToIdentifier()) || target.HumanPrefab?.GetTags().Contains(id.ToIdentifier()) == true);
        }
    }
}