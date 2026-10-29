--[[
    NoProjectileConsume - Prevent projectile consumption when firing RangedWeapons.

    Targets deep mod weapons: they use SRW.SwitchableRangedWeapon
    (Vanilla-Components-Expanded), which fully overrides Use() without calling
    base and hides FindProjectile() with `new`. Patching the vanilla
    RangedWeapon methods would never fire for these weapons, so both capture
    and restore hooks hook the SwitchableRangedWeapon class directly.

    Only protects projectiles stored inside magazines (sub-items of the item
    occupying the weapon's container slot). Direct projectiles (e.g. shotgun
    shells placed directly in the slot) are left untouched.

    Slot filtering (v4.3): only the main ammo slot (PROTECTED_SLOT, slot 0)
    is protected. Other selectable slots (e.g. the underslung grenade
    launcher at slot 1, currentProjectileSelected = 1) launch REAL projectiles
    that must be consumed and fly with live physics - Hook 1 skips tracking
    them, and every downstream hook passes them through its trackedItems
    lookup untouched.

    Package scope (v4.4): only weapons whose prefab comes from the
    Deep-Diving-Armory content package are protected (checked via
    item.Prefab.ContentPackage.Name, cached per prefab). Vanilla and other
    mods are completely unaffected - Hook 1 skips tracking their weapons,
    and even another mod using the SRW component keeps vanilla behavior.

    Whitelist (v4.6.4): deep_meteorite (grenade launcher, switchableSlots=0
    so its MAIN slot is the grenade slot) fires physical rounds. Tracking
    them made Hook 2 block the mid-funnel DoLaunch Drop (Projectile.cs
    L550) - the hard prerequisite for leaving the barrel - so the round
    never left the magazine and every shot was a dry fire. The weapon is
    excluded from the scope entirely (EXCLUDED_IDENTIFIERS): its rounds
    consume normally and fly with live physics, exactly like the v4.3
    underbarrel passthrough but keyed on the weapon prefab.

    Tracer fix (v4.5): hitscan tracers vanished when a shooter INSIDE a hull
    hit a target in open water (or inside another sub), while misses and
    same-sub hits rendered fine. Root cause is a coordinate-space mismatch
    in DoHitscan: it raycasts in BOTH the submarine's local space and world
    space, then SetTransforms the bullet to each hit point with
    forceSubmarine: h.Submarine. World-space hits carry Submarine = null,
    so the body ends up holding WORLD coordinates while Entity.Submarine
    still points at the shooter's sub. The very next statement reads
    item.WorldPosition (= Sub.Position + Position) as the tracer endpoint,
    double-offsetting it far off the map -> tracer invisible. Damage is
    unaffected (HandleProjectileCollision applies it via the limb, not the
    endpoint), which is why hits still registered.

    The submarine-wall branch of HandleProjectileCollision self-corrects
    (item.Move(-sub.Position) + Submarine = sub, Projectile.cs L1088-1094),
    but the Limb branch does not - hence walls are fine, creatures are not.
    Fix (Hooks 11/12, client-only): after a tracked hit, if the bullet body
    no longer sits inside the shooter sub's LOCAL Borders rect, the body
    must be holding world coordinates -> clear item.Submarine so the
    LaunchProjSpecific call reads the correct world endpoint, then restore
    the original Submarine right after the tracer is emitted. The transient
    nil is invisible to Hook 6/8 (they run later and SetTransform with
    forceSubmarine = magazine.Submarine anyway) and to the server (no
    tracers, state self-heals before the next network tick observes it).

    Turret support (v4.6): deep mod turrets (deep_m2_turret) use the engine
    Turret component instead of SRW, and its firing flow differs from
    handheld weapons: TryLaunch() never calls FindProjectile - it fetches
    the bolt from the linked loader's ammo box via the PRIVATE
    GetLoadedProjectiles() (deep_m2_ammobox: capacity 2, boxes hold their
    rounds as condition-fueled SpawnItems - the box CONDITION is the ammo
    meter, not the item count), triggers the box's OnUse (SpawnItem
    replenish + condition drain), then calls the private Launch() which
    runs the SAME funnel as SRW: item.Drop -> SetTransform(barrel) ->
    Projectile.Use (hitscan) -> Item.RemoveContained. Hooks 2-7 already
    cover that funnel generically; Hooks 13/14 add the turret-specific
    capture and restore.

    TryLaunch is reached from THREE paths (Turret.Use via periscope, the
    trigger_in signal handler - deep_m2_turret is characterusable=false so
    the signal path calls TryLaunch directly - and AI auto-operate), so the
    restore hook targets TryLaunch After rather than Use After. Pure
    clients return from TryLaunch before the fetch loop (turret firing is
    server-authoritative, Turret.cs L663), so Hooks 13/14 only do work on
    the server and in single-player - no new client-side tracking. Note
    Hook 6 does not fire for turret bolts at all: Turret.Launch calls the
    (Character, float) Projectile.Use overload (L448), not the
    (float, Character) override Hook 6 patches for handheld weapons.

    Turret dry-fire fix (v4.6.2): v4.6.1 tracked the bolt at Turret.Launch
    entry, so Hook 2 blocked the Launch-internal Drop (Turret.cs L900,
    setTransform: false) that detaches the bolt from the ammo box BEFORE
    Projectile.Use. Handheld weapons never hit this: their Drop calls sit
    mid-funnel (Projectile.cs DoHitscan L593 / DoLaunch L550), after hit
    resolution. For the turret the pre-Use Drop is a hard prerequisite of
    the vanilla launch path - blocking it diverged every downstream step
    and produced dry fire: sounds and muzzle particles (the turret's own
    OnUse effects) played, but no ray, no damage. Fix: the launch path now
    runs byte-identical to vanilla - the L900 Drop passes, the bolt is
    tracked later (Hook 13b at the (Character, float) Projectile.Use
    entry, still before the per-ray loop) and re-contained into the ammo
    box by Hook 14 once TryLaunch completes (Inventory.TryPutItem, 4-arg
    pattern verified in AutoRecycleLoot.lua). DoHitscan leaves IsActive =
    true and vanilla never resets it (vanilla bolts get removed instead),
    so Hook 14 explicitly clears it - the L453 "can't launch if already
    launched" guard would otherwise dry-fire every relaunch of the reused
    bolt. All three deep M2 bolt variants are hitscan="true" in
    turret.xml; non-hitscan projectiles still pass through vanilla
    (Hook 13b checks the Hitscan property) so a future physical variant
    never gets teleported back mid-flight.

    Empty-box passthrough (v4.6.3): with v4.6.2's re-containment a drained
    box kept firing forever. The XML is NOT at fault - vanilla's empty-box
    stop relies on the box going dry: Item.Use (Item.cs L3378) blocks the
    box's OnUse SpawnItem at condition 0 while vanilla bolts despawn on
    hit, so GetLoadedProjectiles eventually finds nothing. But
    CheckProjectileContainer (Turret.cs L1918) only durability-checks the
    DIRECT containers it walks (the turret itself, then each linked
    loader) - the ammo box INSIDE the loader has no such check (L1944's
    condition only bounds the search, it does not gate bolt collection),
    so a re-contained bolt keeps GetLoadedProjectiles fed at box
    condition 0 and defeats the dry state. Fix: Hook 13 checks
    boxItem.Condition <= 0 before the handoff and leaves that bolt fully
    vanilla - no tracking, no re-containment - so it fires and despawns
    (removeonhit / OnNotContained) without being returned; a truly empty
    box now runs dry and gets swapped, and any bolt still inside when the
    box drains is fired off as residual ammo, matching vanilla behavior.

    Scope decision: the ammo box's OnUse economy (per-shot SpawnItem +
    condition drain) is deliberately NOT blocked. The script prevents BOLT
    consumption only; the box still drains and is swapped when empty -
    identical to the vanilla coilgun loader design. Bolts self-remove 1s
    after leaving a container (OnNotContained Remove), so the never-consumed
    bolt cannot be farmed into free items.

    Strategy: intercept item.Drop (detaches from inventory), item.Remove (deletes
    from world), EntitySpawner.AddItemToRemoveQueue (server-side removal queue),
    and Item.RemoveContained (sets Container=null) for tracked projectiles.
    Additionally guard the inventory-move funnel: Inventory.PutItem unconditionally
    executes "item.ParentInventory?.RemoveItem(item)" after its internal Drop call,
    so blocking Drop alone does NOT stop PutItem from pulling the bullet out of
    the magazine (the v4 fix - burst fire with frequent mag handling hit this
    path while bullets were inside their 5s tracking window).

    The SwitchableRangedWeapon.Use firing loop (mirrors vanilla RangedWeapon.Use):
      1. FindProjectile()       -> Path A: direct projectile (skip)
                                -> Path B: magazine sub-item (track)
      2. projectile.Shoot()     -> Launch -> Projectile.Use -> DoHitscan
         -> item.Drop()         (prevented)
         -> HandleProjectileCollision may:
            - set HiddenInGame=true, disable FarseerBody (RemoveOnHit)
            - schedule CoroutineManager.Invoke(AddItemToRemoveQueue, 0.5s)
         -> Entity.Spawner.AddItemToRemoveQueue()  (prevented)
      3. Item.RemoveContained() -> sets Container = null (prevented)

    Server fix (v3): Hook 6 (Projectile.Use After) restores body state and
    position immediately after DoHitscan. However, the caller Launch() then
    calls Item.SetTransform() which OVERRIDES the position to the barrel.
    The bullet ends up at the wrong physical position while still in the
    magazine's inventory. Single-player tolerates this inconsistency, but
    the server's entity system detects and cleans up such invalid states.
    Hook 8 (SwitchableRangedWeapon.Use After) fires AFTER Launch() completes
    and re-restores the position, giving us the final word.

    Hook 7 (Entity.Remove) acts as a final safety net.

    Multiplayer consistency: Item.Remove / Entity.Remove are the surfaces
    where the client materializes server-driven removals
    (EntitySpawner.ClientEventRead calls entity.Remove() directly). Pure
    clients must NEVER block them - the server's 5s tracking window expires
    earlier than the client's (network latency shifts client-side tracking),
    so a legitimately removed bullet can arrive as a removal event while the
    client still tracks it. Blocking it leaves a stale entity; when the
    server reuses the freed ID, the create event throws "ID taken" and the
    client gets kicked. MayBlock() therefore only allows interception on
    authoritative sides (dedicated server / single-player).

    Performance: O(1) per trigger pull. Anti-removal hooks use hash lookups.
    Position restore uses a pendingItem handoff (Hook 1 -> Hook 8) to avoid
    iterating the entire trackedItems table, critical for high-RoF scenarios.
--]]

local DEBUG = false

-- The only slot protected by this script: the main ammo slot (slot 0 in
-- switchableSlots). Other selectable slots (e.g. the underslung grenade
-- launcher, currentProjectileSelected = 1) fire REAL projectiles that must
-- be consumed and fly with live physics - they pass through untouched.
local PROTECTED_SLOT = 0

-- SRW.SwitchableRangedWeapon is a mod assembly type, NOT pre-registered with
-- MoonSharp: instance userdata falls back to the registered BASE descriptor
-- (RangedWeapon/ItemComponent), so base members like instance.Item work while
-- members declared on the derived type (CurrentSelected) throw
-- "cannot access field of userdata<^SRW.SwitchableRangedWeapon>".
-- Registering the type + exposing the property fixes Hook 1's slot guard.
-- Pattern copied from verified PeachTechnology scripts (ImmuneToImpact.lua);
-- RegisterType overwrites any stale registration, so both calls are
-- unconditional and reload-safe.
local srwDescriptor = LuaUserData.RegisterType("SRW.SwitchableRangedWeapon")
LuaUserData.MakePropertyAccessible(srwDescriptor, "CurrentSelected")

-- XNA Rectangle is likewise not guaranteed to be pre-registered; the v4.5
-- tracer fix calls sub.Borders.Contains(...) to test whether the bullet body
-- sits in its sub's local coordinate space. Re-registering is force-write
-- and thus reload-safe (same reasoning as above).
local rectDescriptor = LuaUserData.RegisterType("Microsoft.Xna.Framework.Rectangle")

-- v4.4 package scope: content package name whose weapons this script
-- protects, exactly as declared in the mod's filelist.xml
-- (name="Deep-Diving-Armory", workshop id 3159849099).
local MOD_PACKAGE_NAME = "Deep-Diving-Armory"

-- Authority gate, evaluated at callback time (script loads at the main
-- menu where Game.IsMultiplayer is still false, so it must NOT be cached).
-- SERVER is a build-target constant: true on dedicated servers, false on
-- all client builds (including listen-server hosts). A listen-host treated
-- as non-authoritative only degrades gracefully: an uncovered removal of a
-- tracked bullet succeeds and broadcasts, keeping every side consistent.
local function MayBlock()
    return SERVER or not Game.IsMultiplayer
end

local function Log(prefix, ...)
    if DEBUG then
        print("[NPConsume][" .. prefix .. "]", ...)
    end
end

-- Container-death passthrough: a tracked bullet's no-death immunity must NOT
-- outrank its container. Item.Remove never touches OwnInventory contents, so
-- blocking removals for a bullet whose magazine is legitimately dying leaves
-- a server-side orphan dangling on a dead container while clients drop it -
-- server/client entity divergence -> client reports MISSING_ENTITY
-- ("Received msg N, entity X not found"), server logs "Missing item(...)".
-- Container is the owning Item (the magazine); it is null for character
-- inventories, which is the safe default (keep protecting those bullets).
-- IsInRemoveQueue is set BEFORE the recursive AddItemToRemoveQueue pass over
-- ContainedItems, and Removed covers the already-executed case, so every
-- stage of the removal chain sees a true value.
local function ContainerDying(item)
    local container = item.Container
    if container == nil then return false end
    return container.Removed or container.IsInRemoveQueue
end

-- Package scope check: item.Prefab -> base Prefab.ContentPackage (Prefab.cs
-- L37: ContentFile?.ContentPackage) -> ContentPackage.Name. Gate lives ONLY
-- at the Hook 1 tracking entry: untracked items flow through every
-- downstream hook (2-10) via the trackedItems lookup untouched, so vanilla
-- and other mods keep 100% vanilla behavior. Result cached per prefab
-- object - one string compare per weapon prefab per session, O(1) per shot.
--
-- v4.6.4 whitelist: deep-package weapons that must NOT be protected.
-- deep_meteorite fires physical grenades from its MAIN slot; tracking its
-- rounds makes Hook 2 block DoLaunch's Drop (Projectile.cs L550) and the
-- weapon dry-fires. Excluded weapons consume ammo and fly vanilla.
local EXCLUDED_IDENTIFIERS = {
    ["deep_meteorite"] = true,
}

local scopedPrefabs = {}

local function IsScopedWeapon(item)
    local prefab = item ~= nil and item.Prefab or nil
    if prefab == nil then return false end
    local cached = scopedPrefabs[prefab]
    if cached == nil then
        local pkg = prefab.ContentPackage
        cached = pkg ~= nil and pkg.Name == MOD_PACKAGE_NAME
            and not EXCLUDED_IDENTIFIERS[tostring(prefab.Identifier)]
        scopedPrefabs[prefab] = cached
    end
    return cached
end

----------------------------------------------------------------------
-- State
--   trackedItems: table keyed by Item (userdata), value = magazine Item
--     that originally contained the bullet. The key is the bullet Item,
--     used by anti-removal hooks (Drop/Remove/RemoveContained/etc.) for
--     O(1) lookup.
--
--   pendingItem: { item = bulletItem, magazine = magazineItem }
--     The most recently tracked bullet, set by Hook 1 and consumed by
--     Hook 8. Avoids iterating the entire trackedItems table on every
--     weapon use (critical for high-RoF scenarios).
--
--   Items are cleared ~5s after each Use cycle to account for
--   CoroutineManager.Invoke delays (e.g. RemoveOnHit at 0.5s).
----------------------------------------------------------------------
local trackedItems = {}
local pendingItem = nil

-- v4.5 tracer fix handoff: set by Hook 11 when a tracked bullet's body was
-- moved to WORLD coordinates while its stale Entity.Submarine still pointed
-- at the shooter's sub. Consumed by Hook 12 right after the tracer is
-- emitted to restore the original Submarine reference. Single-slot like
-- pendingItem: HandleProjectileCollision -> LaunchProjSpecific run
-- back-to-back inside one DoHitscan call, so no interleaving occurs.
local tracerFix = nil

----------------------------------------------------------------------
-- Hook 1: After FindProjectile - capture the projectile item
--   SwitchableRangedWeapon declares FindProjectile with `new` (method
--   hiding, non-virtual): its Use() loop calls THIS method directly, so
--   patching the vanilla RangedWeapon version would never fire.
--   Only tracks projectiles inside a magazine (sub-items). Direct
--   projectiles occupying the weapon's container slot are skipped.
--
--   Distinction logic:
--     Path A (direct):  projectile.Item.Container == weaponItem -> skip
--     Path B (magazine): projectile.Item.Container is nil or != weaponItem -> track
--
--   Stores the magazine Item as the value, used later for position restoration.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.FindProj",
    "SRW.SwitchableRangedWeapon",
    "FindProjectile",
    { "System.Boolean" },
    function(instance, ptable)
        local projectile = ptable.ReturnValue
        if projectile == nil or projectile.Item == nil then
            Log("FindProjectile", "nil skip")
            return
        end

        local projItem = projectile.Item
        local weaponItem = instance.Item

        -- VCE owns the virtual projectile's lifetime and position.
        if LuaUserData.IsTargetType(projectile, "VCE_VirtualizedMagazine.VirtualizedProjectile") then return end

        -- v4.4 package scope: protect Deep-Diving-Armory weapons ONLY.
        -- Vanilla and other mods' weapons - including any that use the SRW
        -- component - are never tracked, so they keep vanilla consumption
        -- and physics behavior with zero interference.
        if not IsScopedWeapon(weaponItem) then
            Log("FindProjectile", "non-deep weapon, skip")
            return
        end

        -- v4.3 underbarrel passthrough: non-protected slots (underslung
        -- grenade launcher, currentProjectileSelected = 1) fire REAL
        -- projectiles that must be consumed and fly with live physics.
        -- Skipping tracking here lets every downstream hook (2-8) pass the
        -- grenade through its trackedItems lookup untouched - single-point
        -- change, zero risk to the protected main-magazine path.
        if instance.CurrentSelected ~= PROTECTED_SLOT then
            Log("FindProjectile", "non-protected slot " .. tostring(instance.CurrentSelected) .. ", skip")
            return
        end

        -- Item.Container is type Item (the parent item), not ItemContainer.
        -- For a bullet inside a magazine: Container == magazine Item
        -- For a bullet directly in weapon's slot: Container == weapon Item
        local parentItem = projItem.Container

        -- Direct projectile occupying the weapon's container slot -> skip
        if parentItem ~= nil and parentItem == weaponItem then
            Log("FindProjectile", "direct projectile, skip")
            return
        end

        -- Magazine sub-item -> track for anti-removal hooks + set pending for Hook 8
        trackedItems[projItem] = parentItem
        pendingItem = { item = projItem, magazine = parentItem }
        Log("FindProjectile", "tracked " .. tostring(projItem) .. " from magazine " .. tostring(parentItem))
    end,
    Hook.HookMethodType.After
)

----------------------------------------------------------------------
-- Hook 2: Before Item.Drop - keep projectile in magazine inventory
--   Called by: DoHitscan / DoLaunch
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.Drop",
    "Barotrauma.Item",
    "Drop",
    { "Barotrauma.Character", "System.Boolean", "System.Boolean" },
    function(instance, ptable)
        if trackedItems[instance] ~= nil then
            if ContainerDying(instance) then
                Log("Drop", "container dying, dropping " .. tostring(instance))
                return
            end
            Log("Drop", "prevented on " .. tostring(instance))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 3: Before Item.Remove - prevent deletion (single-player path)
--   Called by: DoHitscan when Entity.Spawner == null (Sp)
--   Authority-only: on pure clients this method is how server-driven
--   removals materialize (ClientEventRead -> entity.Remove()), so blocking
--   it there leaves stale entities that break ID reuse. See header.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.Remove",
    "Barotrauma.Item",
    "Remove",
    {},
    function(instance, ptable)
        if not MayBlock() then return end
        if trackedItems[instance] ~= nil then
            if ContainerDying(instance) then
                Log("Remove", "container dying, following " .. tostring(instance))
                return
            end
            Log("Remove", "prevented on " .. tostring(instance))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 4: Before EntitySpawner.AddItemToRemoveQueue - prevent deletion
--   Called by: DoHitscan when Entity.Spawner != null (server),
--   AND by CoroutineManager.Invoke after 0.5s delay (RemoveOnHit path).
--   Delayed cleanup (5s after Use) ensures tracking is still active
--   when the delayed coroutine fires.
----------------------------------------------------------------------
--   v4.1 - container-death passthrough: AddItemToRemoveQueue RECURSES into
--   ContainedItems (EntitySpawner.cs: enqueues parent + sets
--   IsInRemoveQueue=true first, THEN recurses). Blocking the recursive call
--   for a tracked bullet while its container (magazine) legitimately dies
--   creates a SERVER-SIDE ORPHAN: Item.Remove never touches OwnInventory
--   contents, so the bullet stays alive dangling on the dead container while
--   clients drop it -> server/client entity divergence -> client reports
--   MISSING_ENTITY ("Received msg N, entity X not found") and the server
--   logs "Missing item(...)". The immunity must NOT outrank its container:
--   when the container is already in the removal queue, let the bullet die
--   with it (identical on both sides).
Hook.Patch(
    "NoProjectileConsume.RemoveQueue",
    "Barotrauma.EntitySpawner",
    "AddItemToRemoveQueue",
    { "Barotrauma.Item" },
    function(instance, ptable)
        local targetItem = ptable["item"]
        if targetItem ~= nil and trackedItems[targetItem] ~= nil then
            if ContainerDying(targetItem) then
                Log("RemoveQueue", "container dying, following " .. tostring(targetItem))
                return
            end
            Log("RemoveQueue", "prevented on " .. tostring(targetItem))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 5: Before Item.RemoveContained - prevent Container = null
--   Called by: RangedWeapon.Use / SwitchableRangedWeapon.Use after
--   projectile.Shoot() (both call Item.RemoveContained at the end of
--   their firing loop).
--   Even though ownInventory.RemoveItem is a no-op (projectile is in
--   magazine, not in weapon), the method always sets contained.Container = null.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.RemoveContained",
    "Barotrauma.Item",
    "RemoveContained",
    { "Barotrauma.Item" },
    function(instance, ptable)
        local contained = ptable["contained"]
        if contained ~= nil and contained.Container ~= nil and instance ~= contained.Container and IsScopedWeapon(instance) then
            local projectile = contained.GetComponentString("Projectile")
            -- SRW clears Container after every shot, even when VCE kept the projectile in its magazine.
            if projectile and LuaUserData.IsTargetType(projectile, "VCE_VirtualizedMagazine.VirtualizedProjectile") then
                ptable.PreventExecution = true
                return
            end
        end
        if contained ~= nil and trackedItems[contained] ~= nil then
            if ContainerDying(contained) then
                Log("RemoveContained", "container dying, following " .. tostring(contained))
                return
            end
            Log("RemoveContained", "prevented on " .. tostring(contained))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 6: After Projectile.Use(Character, float) - restore bullet state
--   Called inside projectile.Shoot() -> Launch() after DoHitscan completes.
--   At this point the bullet is in an inconsistent state:
--     - Still in magazine inventory (Drop prevented by Hook 2)
--     - body.Enabled=true, IsActive=true (set by DoHitscan)
--     - HiddenInGame=true, FarseerBody disabled (if RemoveOnHit)
--     - Position at impact point
--
--   This hook restores proper inventory state to prevent the server
--   entity system from cleaning up the "zombie" item on subsequent ticks.
--   This is the critical fix for server-side operation.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.ProjUsePost",
    "Barotrauma.Items.Components.Projectile",
    "Use",
    { "Barotrauma.Character", "System.Single" },
    function(instance, ptable)
        local item = instance.Item
        if item == nil or trackedItems[item] == nil then
            return
        end

        Log("ProjUse:Post", "restoring state on " .. tostring(item))

        -- Disable physics body (correct state for inventory items)
        if item.body ~= nil then
            item.body.Enabled = false
            Log("ProjUse:Post", "body disabled")
        end

        -- Unhide the item (was set HiddenInGame=true by RemoveOnHit)
        if item.HiddenInGame then
            item.HiddenInGame = false
            Log("ProjUse:Post", "unhidden")
        end

        -- Reset position to the magazine's position
        local magazineItem = trackedItems[item]
        if magazineItem ~= nil and magazineItem.SimPosition ~= nil then
            item.SetTransform(magazineItem.SimPosition, 0.0, true, true, magazineItem.Submarine)
            Log("ProjUse:Post", "position reset to magazine")
        end
    end,
    Hook.HookMethodType.After
)

----------------------------------------------------------------------
-- Hook 7: Before Entity.Remove - final safety net (authority-only)
--   Catches any removal attempt on tracked items that bypassed
--   the more specific hooks above. Acts as a last line of defense.
--   Authority-only, same reason as Hook 3: on pure clients
--   ClientEventRead -> entity.Remove() is the server-driven removal
--   entry point and must pass through. See header.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.EntityRemove",
    "Barotrauma.Entity",
    "Remove",
    {},
    function(instance, ptable)
        if not MayBlock() then return end
        if trackedItems[instance] ~= nil then
            if ContainerDying(instance) then
                Log("EntityRemove", "container dying, following " .. tostring(instance))
                return
            end
            Log("EntityRemove", "prevented on " .. tostring(instance))
            ptable.PreventExecution = true
        end
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Renewing cleanup (v4.2, extracted as shared helper in v4.6):
--   ScheduleRenew(item) re-checks the tracked entry every 5s. RENEWING
--   cleanup instead of fire-and-forget expiry: the old unconditional
--   delete left the bullet UNPROTECTED against any delayed engine cleanup
--   path that fires >5s after the shot (server periodic entity sweeps, AI
--   target cleanup, deconstruct sequences), which manifested as
--   "occasional magazine ammo loss" - burst fire amplified it because more
--   shots per second means more state churn (rope attach, body impulses,
--   position shuffles) racing the expiry. Renew while the bullet still
--   sits in its ORIGINAL magazine; drop the entry the moment it no longer
--   does (magazine removed/removed entry, bullet moved out -
--   container-death passthrough in the removal hooks already guarantees
--   consistency in those cases). Cost: one timer + O(1) checks per tracked
--   bullet per 5s; the tracked set is one bullet per gun. Stacked timers
--   from rapid fire are idempotent: each chain re-validates the entry, and
--   a cleared entry makes remaining chains no-op.
--   Used by Hook 8 (SRW bullets) and Hook 14 (turret bolts).
----------------------------------------------------------------------
local function ScheduleRenew(item)
    if item == nil then return end
    local function RenewTracking()
        local magazine = trackedItems[item]
        if magazine == nil then return end -- entry already cleared elsewhere
        if magazine.Removed or item.Container ~= magazine then
            trackedItems[item] = nil
            Log("Renew", "cleared tracked item " .. tostring(item))
            return
        end
        Log("Renew", "renewed tracking on " .. tostring(item))
        Timer.Wait(RenewTracking, 5000)
    end
    Timer.Wait(RenewTracking, 5000)
end

----------------------------------------------------------------------
-- Hook 8: After SwitchableRangedWeapon.Use - restore position and schedule cleanup
--   SwitchableRangedWeapon overrides Use() completely (no base.Use call),
--   so the vanilla RangedWeapon.Use patch never fires for deep mod
--   weapons; this After hook on the override is the correct final point.
--   This is the critical server-side fix. Hook 6 (Projectile.Use After)
--   restores the bullet's state, but then Launch() calls Item.SetTransform()
--   which moves the bullet to the barrel/shoulder position, overriding
--   Hook 6's position restoration.
--
--   Uses a pendingItem handoff from Hook 1 to avoid iterating the entire
--   trackedItems table. Phase 1 restores only the bullet from THIS weapon
--   use. Phase 2 schedules a 5s delayed cleanup for that single item.
--
--   At 667 shots/sec (50 guns @ 800 RPM), this avoids ~2.2M table iterations
--   per second that a full-table-scan approach would cause.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.UsePost",
    "SRW.SwitchableRangedWeapon",
    "Use",
    { "System.Single", "Barotrauma.Character" },
    function(instance, ptable)
        local pi = pendingItem
        pendingItem = nil

        -- Phase 1: Restore the bullet that was just tracked by Hook 1.
        -- Launch() moved it to the barrel position after Hook 6 restored it.
        -- This is the critical server-side fix.
        -- Using pendingItem avoids iterating the entire trackedItems table.
        if pi ~= nil then
            local item = pi.item
            local magazineItem = pi.magazine

            if item.body ~= nil then
                item.body.Enabled = false
            end
            if item.HiddenInGame then
                item.HiddenInGame = false
            end
            if magazineItem ~= nil and magazineItem.SimPosition ~= nil then
                item.SetTransform(magazineItem.SimPosition, 0.0, true, true, magazineItem.Submarine)
            end

            Log("Use:Post", "restored position for " .. tostring(item))
        end

        -- Phase 2: Schedule cleanup of just this bullet after 5s.
        -- v4.6: the RENEWING cycle (v4.2) lives in the shared ScheduleRenew
        -- helper above, now also used by Hook 14 for turret bolts.
        ScheduleRenew(pi ~= nil and pi.item or nil)
    end,
    Hook.HookMethodType.After
)

----------------------------------------------------------------------
-- Hook 9/10: Before Inventory.PutItem / CharacterInventory.PutItem
--   The inventory-move funnel. PutItem (protected, virtual) unconditionally
--   executes after its Drop call:
--       item.Drop(user, ...)                      <- Hook 2 blocks this
--       item.ParentInventory?.RemoveItem(item)    <- NOT covered by any hook
--       slots[i].Add(item); item.ParentInventory = this
--   Blocking the internal Drop does NOT abort PutItem, so a tracked bullet
--   was silently moved out of its magazine by ANY inventory transfer
--   (reload top-ups, slot reshuffles, drag operations, bot logistics)
--   landing inside its 5s tracking window - burst fire with frequent mag
--   handling made this highly probable (the v4 root cause).
--
--   Blocking PutItem Before aborts the ENTIRE move before ANY mutation
--   (no duplication risk, unlike blocking RemoveItem after the fact).
--   Runs on ALL sides: no entity ID risk (pure inventory op), and server +
--   client must block identically to avoid divergence. UX cost mirrors the
--   Drop/RemoveContained guards: the just-fired round cannot be yanked out
--   of its magazine for 5s.
--
--   Two patch points required: ItemInventory (magazines) dispatches to the
--   base Barotrauma.Inventory.PutItem, while character inventories dispatch
--   to the CharacterInventory override - Harmony patches the declared
--   method only, so both must be covered. Signature (6 params):
--   PutItem(Item, int, Character, bool, bool, bool)
----------------------------------------------------------------------
local function GuardPutItem(instance, ptable)
    -- ParameterTable exposes parameters only through its string indexer
    -- (ptable["item"]); dot access (ptable.item) throws "cannot access field".
    local movedItem = ptable["item"]
    if movedItem ~= nil and trackedItems[movedItem] ~= nil then
        Log("PutItem", "prevented on " .. tostring(movedItem))
        ptable.PreventExecution = true
    end
end

Hook.Patch(
    "NoProjectileConsume.PutItem",
    "Barotrauma.Inventory",
    "PutItem",
    { "Barotrauma.Item", "System.Int32", "Barotrauma.Character", "System.Boolean", "System.Boolean", "System.Boolean" },
    GuardPutItem,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "NoProjectileConsume.CharacterPutItem",
    "Barotrauma.CharacterInventory",
    "PutItem",
    { "Barotrauma.Item", "System.Int32", "Barotrauma.Character", "System.Boolean", "System.Boolean", "System.Boolean" },
    GuardPutItem,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 11: After Projectile.HandleProjectileCollision - fix stale
--   coordinate space before the tracer endpoint is read (client-only)
--   Both hooks live behind `if not SERVER`: LaunchProjSpecific is a
--   partial void with no dedicated-server implementation, so patching it
--   there would fail to resolve the method - and servers have no tracers.
--
--   DoHitscan raycasts in the sub's local space AND world space, then
--   SetTransforms the bullet to each hit point with forceSubmarine:
--   h.Submarine. World-space hits (creatures in open water, targets inside
--   OTHER subs - RayCastInOtherSubs converts their points back to world
--   coordinates with sub: null) leave the body holding world coordinates
--   while Entity.Submarine still points at the shooter's sub. The caller
--   then reads item.WorldPosition (= Sub.Position + Position) as the
--   tracer endpoint -> double-offset -> tracer drawn far off the map.
--   The Limb branch of HandleProjectileCollision performs no correction
--   (the Submarine-wall branch does: item.Move(-sub.Position)), so only
--   creature/item hits leak the stale state into the renderer.
--
--   Detection: a legit LOCAL-space hit point always lies inside the sub's
--   local Borders rect (both are sub-local coordinates, borders superset
--   all hull geometry). A stale WORLD hit point has the magnitude of the
--   sub's world position - tens of thousands of units away from the local
--   rect, which sits around the origin. Borders.Contains(item.Position)
--   therefore separates the two spaces with no false positives.
--
--   Guards: tracked items only (v4.4 scope + v4.3 slots apply upstream),
--   ReturnValue == true only (false = wall/hitbox passthrough, whose
--   submarine branch self-corrects), Submarine ~= nil only.
----------------------------------------------------------------------
if not SERVER then
    Hook.Patch(
        "NoProjectileConsume.TracerSpaceFix",
        "Barotrauma.Items.Components.Projectile",
        "HandleProjectileCollision",
        { "FarseerPhysics.Dynamics.Fixture", "Microsoft.Xna.Framework.Vector2", "Microsoft.Xna.Framework.Vector2" },
        function(instance, ptable)
            local item = instance.Item
            if item == nil or trackedItems[item] == nil then return end
            if ptable.ReturnValue ~= true then return end

            local sub = item.Submarine
            if sub == nil then return end

            local borders = sub.Borders
            if borders.Contains(item.Position) then return end

            -- Body holds world coordinates while Submarine is stale: clear
            -- it so the caller's item.WorldPosition read (tracer endpoint)
            -- yields the raw world point.
            tracerFix = { item = item, sub = sub }
            item.Submarine = nil
            Log("TracerFix", "cleared stale Submarine on " .. tostring(item))
        end,
        Hook.HookMethodType.After
    )

    ----------------------------------------------------------------------
    -- Hook 12: After Projectile.LaunchProjSpecific - restore the stale
    --   Submarine reference after the tracer was emitted (client-only)
    --   Runs on EVERY client-side tracer emission, tracked or not, and is
    --   O(1). Restores only if the Submarine reference was not legitimately
    --   reassigned in between (e.g. SetTransform's forceSubmarine on a
    --   follow-up hit inside another sub within the same DoHitscan).
    ----------------------------------------------------------------------
    Hook.Patch(
        "NoProjectileConsume.TracerSpaceRestore",
        "Barotrauma.Items.Components.Projectile",
        "LaunchProjSpecific",
        { "Microsoft.Xna.Framework.Vector2", "Microsoft.Xna.Framework.Vector2" },
        function(instance, ptable)
            if tracerFix == nil then return end
            if tracerFix.item == instance.Item and tracerFix.item.Submarine == nil then
                tracerFix.item.Submarine = tracerFix.sub
                Log("TracerFix", "restored Submarine on " .. tostring(tracerFix.item))
            end
            tracerFix = nil
        end,
        Hook.HookMethodType.After
    )
end

----------------------------------------------------------------------
-- Hook 13: Before Turret.Launch - pending handoff (v4.6.2)
--   Engine Turret.TryLaunch never calls FindProjectile: it fetches the
--   bolt from the linked loader's ammo box (private GetLoadedProjectiles,
--   only callers TryLaunch L699/L733), triggers the box's OnUse replenish,
--   then calls the private Launch() which runs the standard funnel:
--   item.Drop -> SetTransform(barrel) -> Projectile.Use (hitscan) ->
--   Item.RemoveContained.
--
--   v4.6.2: this hook NO LONGER tracks the bolt. Turret.Launch's own Drop
--   (Turret.cs L900) detaches the bolt from the box BEFORE the hitscan
--   and is a hard prerequisite of the vanilla launch path - blocking it
--   (v4.6.1 tracked here, so Hook 2 blocked the Drop) caused dry fire.
--   Instead this hook only clears stale tracking (a re-fired bolt still
--   carries its previous shot's entry, which would block the L900 Drop
--   again) and hands the bolt to Hook 13b via pendingItem, which does the
--   actual tracking AFTER the Drop, right before the per-ray loop.
--
--   Package scope follows the TURRET prefab (IsScopedWeapon): vanilla
--   coilguns/railguns and other mods' turrets are never touched. Pure
--   clients never reach Launch (TryLaunch returns before the fetch loop -
--   turret firing is server-authoritative), so this hook only does work
--   on the server and in single-player.
--
--   parameterTypes = nil: Turret declares exactly one Launch (the private
--   funnel entry); name-only lookup resolves it via the NonPublic flag.
--   ProjectileCount > 1 overwrites of a DIFFERENT pending item are handled
--   by scheduling that item's renew immediately.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.TurretCapture",
    "Barotrauma.Items.Components.Turret",
    "Launch",
    nil,
    function(instance, ptable)
        local projItem = ptable["projectile"]
        if projItem == nil then return end

        local turretItem = instance.Item
        if not IsScopedWeapon(turretItem) then
            Log("TurretCapture", "non-deep turret, skip")
            return
        end

        -- a re-fired bolt still carries its previous shot's tracking;
        -- clear it so the L900 Drop below passes unblocked
        trackedItems[projItem] = nil

        local boxItem = projItem.Container
        if boxItem == nil then
            Log("TurretCapture", "uncontained bolt, skip")
            pendingItem = nil
            return
        end

        -- Empty-box passthrough (v4.6.3): the box's condition IS the ammo
        -- meter. Vanilla's dry state relies on Item.Use (Item.cs L3378)
        -- blocking the OnUse SpawnItem at condition 0 while bolts despawn
        -- on hit, but CheckProjectileContainer (Turret.cs L1918) never
        -- durability-checks the box inside the loader - re-containing a
        -- bolt (Hook 14) would keep GetLoadedProjectiles fed forever and
        -- defeat the empty box. Leave this bolt completely vanilla: no
        -- tracking, no re-containment, it fires and despawns on its own.
        if boxItem.Condition <= 0.0 then
            pendingItem = nil
            Log("TurretCapture", "ammo box empty, vanilla passthrough")
            return
        end

        -- ProjectileCount > 1 safety: overwriting a DIFFERENT pending item
        -- would orphan its renew cycle - schedule it immediately.
        if pendingItem ~= nil and pendingItem.item ~= projItem then
            ScheduleRenew(pendingItem.item)
        end

        pendingItem = { item = projItem, magazine = boxItem }
        Log("TurretCapture", "pending " .. tostring(projItem) .. " from box "
            .. tostring(boxItem) .. " on " .. tostring(turretItem))
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 13b: Before Projectile.Use(Character, float) - funnel entry capture
--   (v4.6.2) Turret.Launch L937 calls the (Character, float) overload
--   (Projectile.cs L448) with a null character - a DIFFERENT method from
--   the (float, Character) override Hook 6 patches for handheld weapons.
--   This hook fires after the L900 Drop (bolt already detached from the
--   box) and before the per-ray loop (DoHitscan at L491), so tracking
--   here still covers the whole funnel: Hook 2 blocks the in-funnel Drop
--   (a no-op for the already-detached bolt, same as handheld weapons),
--   Hook 4 blocks the delayed removal-queue add, and the v4.5 tracer fix
--   (Hooks 11/12) applies to the turret's rays.
--
--   Non-hitscan bolts are left completely vanilla: tracking one would
--   make Hook 14 teleport a live flying shell back into the box. All
--   current deep M2 bolt variants are hitscan="true" (turret.xml); the
--   check just guards future physical variants.
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.TurretFunnelCapture",
    "Barotrauma.Items.Components.Projectile",
    "Use",
    {"Barotrauma.Character", "System.Single"},
    function(instance, ptable)
        local pi = pendingItem
        if pi == nil then return end

        local bolt = pi.item
        if bolt ~= instance.Item then return end

        if not instance.Hitscan then
            pendingItem = nil
            Log("TurretCapture", "non-hitscan bolt, vanilla passthrough")
            return
        end

        if trackedItems[bolt] == nil then
            trackedItems[bolt] = pi.magazine
        end
        pi.component = instance
        Log("TurretCapture", "tracked " .. tostring(bolt) .. " at funnel entry")
    end,
    Hook.HookMethodType.Before
)

----------------------------------------------------------------------
-- Hook 14: After Turret.TryLaunch - re-containment + renew (v4.6.2)
--   TryLaunch is reached from THREE paths: Turret.Use (periscope/character),
--   the trigger_in signal handler (deep_m2_turret is characterusable=false,
--   so the signal path calls TryLaunch directly, Turret.cs L2025), and AI
--   auto-operate (L1201). A Use After hook would miss the latter two, so
--   TryLaunch After is the single point following every launch loop.
--
--   v4.6.2: the launch path ran vanilla (the L900 Drop passed), so the
--   bolt is now OUT of the box, at the hit position with the removeonhit
--   state (body disabled, HiddenInGame). Re-contain it into the ammo box:
--   untrack first so our own PutItem guards (Hooks 9/10) don't block the
--   insertion, TryPutItem (4-arg pattern verified in AutoRecycleLoot.lua),
--   retrack, renew. If the box is gone the fallback parks the bolt at the
--   box's last position in the world, where the 1s OnNotContained
--   self-remove cleans it up and the box's per-shot SpawnItem replenish
--   keeps the ammo flow alive.
--
--   IsActive is explicitly cleared: DoHitscan sets it (Projectile.cs
--   L600) and vanilla never resets it (vanilla bolts are removed instead)
--   - the L453 "can't launch if already launched" guard would dry-fire
--   every relaunch of the reused bolt.
--
--   parameterTypes = nil: TryLaunch has no overloads, name-only lookup
--   (ResolveMethod's NonPublic flag covers the private declaration).
----------------------------------------------------------------------
Hook.Patch(
    "NoProjectileConsume.TurretTryLaunchPost",
    "Barotrauma.Items.Components.Turret",
    "TryLaunch",
    nil,
    function(instance, ptable)
        local pi = pendingItem
        pendingItem = nil

        if pi == nil then return end

        local item = pi.item
        local boxItem = pi.magazine
        local pc = pi.component

        -- physical bolts: Hook 13b cleared the handoff, vanilla passthrough
        if trackedItems[item] == nil then
            Log("TurretLaunch", "untracked bolt, no re-containment")
            return
        end

        if pc ~= nil then
            pc.IsActive = false
        end
        if item.HiddenInGame then
            item.HiddenInGame = false
        end

        -- untrack so Hooks 9/10 let our own re-containment through
        trackedItems[item] = nil
        local boxInv = boxItem ~= nil and boxItem.OwnInventory or nil
        if boxInv ~= nil and boxInv:TryPutItem(item, nil, nil, true) then
            Log("TurretLaunch", "re-contained " .. tostring(item) .. " into " .. tostring(boxItem))
        else
            if item.body ~= nil then
                item.body.Enabled = false
            end
            if boxItem ~= nil and boxItem.SimPosition ~= nil then
                item.SetTransform(boxItem.SimPosition, 0.0, true, true, boxItem.Submarine)
            end
            Log("TurretLaunch", "re-contain failed, parked at box position")
        end
        trackedItems[item] = boxItem
        ScheduleRenew(item)
    end,
    Hook.HookMethodType.After
)

print("[NoProjectileConsume] Initialized. DEBUG=" .. tostring(DEBUG))
