# Gunsmith Summary

GunSmith is Deep-Diving-Armory's modular firearm customization system for Barotrauma. The current prototype uses Lua for weapon/platform/part configuration and selection state, while C# owns the runtime UI, composed sprites, item component bridge, and runtime stat application.

## Current State

- Primary validated weapons:
  - `deep_m4`
  - `deep_hk416`
  - AK-platform content is being authored, with `deep_ak74m` config work in progress.
- Current schema model:
  - Weapons bind to a platform.
  - Platforms define root slots, canvas size, path names, required hidden slots, and slot layout semantics.
  - Parts define type, provided compatibility tags, optional item backing, visual source data, stats, and nested mounts.
  - Weapon `roots` provide the default root assembly, root socket alignment, and optional `itemPosOrigin` calibration for quick-slot contained item placement.
- Current interaction model:
  - `G` opens the full GunSmith UI for the selected hand weapon.
  - `Shift+G` opens the QuickMod UI for weapons with quick slots.
  - HK416 QuickMod uses the weapon's real hidden Barotrauma `ItemContainer` slots as authoritative physical storage; dynamic quick-slot containers are injected from Lua quick slot bindings.
- Current persistence/network model:
  - `GunsmithData.SavedState` stores the encoded selection JSON.
  - Single-player reads and writes the component field locally.
  - Multiplayer uses Barotrauma native item component events; clients request/submit state, the server owns accepted state and broadcasts it back.

## Major Milestones

- V0-V0.3 established the basic Lua/C# bridge, M4 prototype, composed sprite application, text-first UI, and local `SavedState` persistence.
- V0.4-V0.6 moved from pure selection state toward item-driven customization, added validation, display stats, and a preview-oriented UI path.
- V0.7-V0.9.4 reworked the schema for multiple weapons on shared platforms, receiver-led nested part trees, mount defaults, root sockets, attach points, and stricter config validation.
- V1.0 added the external anchor/content production workflow and Chinese production guide.
- V1.1-V1.2.1 stabilized world sprite transforms, localization, and the first gameplay-facing stat path through ergonomics.
- V1.3-V1.3.3 integrated HK416 with Barotrauma's original `ItemContainer` workflow, then refined hidden quick slots, conditional slot visibility, and drag/drop protection.
- V1.4-V1.4.3 moved attachment stats into GunSmith part data, polished the full and quick UI, stabilized quick drag/drop behavior, and split the C# GUI into focused partial files.
- V1.5 moved saved selection sync onto native item component networking through `GunsmithData`.
- V1.5.1 fixed client-side apply timing for existing weapons and Lua reloads, added container movement apply hooks, removed `pcall` from GunSmith Lua, and corrected exposed userdata/parameter assumptions.
- V1.5.2 实现了动态maxslots用于quickSlots（快速改装），不需要再手动提前定义SubContainer了。
- V1.5.3 reworked quick-slot layout around `roots`, removed legacy `rootParts`/`rootSockets` compatibility reads, added `itemPosOrigin` based contained item placement, and added console commands for live `itemPosOrigin` tuning.

## Public Interfaces

- Lua hooks kept stable:
  - `DeepGunsmithApply`
  - `DeepGunsmithOpen`
  - `DeepGunsmithOpenQuick`
  - `DeepGunsmithRefreshParts`
  - `DeepGunsmithRefreshQuick`
  - `DeepGunsmithRequestState`
  - `DeepGunsmithSaveState`
  - `DeepGunsmithReceiveState`
  - `DeepGunsmithRegisterHiddenQuickSlots`
  - `DeepGunsmithRegisterQuickSlotVisibility`
  - `DeepGunsmithBeginQuickSlotMutation`
  - `DeepGunsmithEndQuickSlotMutation`
  - `DeepGunsmithIsQuickSlotMutation`
  - `DeepGunsmithRegisterQuickSlotCapacity`
  - `DeepGunsmithClearQuickSlotLayouts`
  - `DeepGunsmithRegisterQuickSlotLayout`
  - `DeepGunsmithApplyQuickSlotLayouts`
- Persisted state remains:
  - `{"v":1,"parts":{...}}`
- Main console commands:
  - `DeepGunsmithValidate`
  - `DeepGunsmithValidationSelfTest`
  - `DeepGunsmithPrintItemPosOrigin`
  - `DeepGunsmithSetItemPosOrigin`
  - `DeepGunsmithNudgeItemPosOrigin`

## Current Validation Notes

- M4/HK416 full UI and QuickMod flows have been locally validated through repeated in-game passes.
- Existing weapons in cabinets, player inventories, and hands are now reapplied after map load and `cl_reloadlua`.
- GunSmith Lua scripts intentionally avoid `pcall` so invalid hook parameters and userdata assumptions surface immediately during testing.
- GunSmith solution build is expected to pass with:
  - `dotnet build .AssemblyCSharpSource/GunSmith/GunSmith.sln -m:1 /p:UseSharedCompilation=false /p:DebugType=None /p:DebugSymbols=false /p:ModDeployDir=.buildcheck\`

## Deferred Work

- Quick attachment transform architecture is planned in [QuickAttachmentTransformPlan.md](QuickAttachmentTransformPlan.md), covering the staged move from physical contained item placement to shared display/effect transforms.
- Multiplayer validation still needs real multi-client testing.
- Server-side anti-cheat validation is intentionally minimal; full Lua compatibility rule reconstruction on the server is deferred.
- Server-authoritative runtime stat application beyond saved selection sync is deferred.
- Workbench/access gating, wider weapon content, and final art polish remain outside the current sync/apply stabilization pass.
