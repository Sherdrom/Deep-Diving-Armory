# Gunsmith V0 Summary

## Overview

`GunsmithPatch` is the first playable prototype of the new Deep-Diving-Armory gunsmith system.

The current V0 goal is:

- prove that a weapon can be described as multiple visual parts
- prove that Lua can drive part selection
- prove that a dedicated C# UI can open and cycle parts
- prove that a composed sprite can replace the original item sprite at runtime

This prototype uses `deep_m4` as the first test weapon platform.

## Current V0 Result

### Working

- Press `G` while holding `deep_m4` opens the Gunsmith UI.
- The UI is built in C# instead of LuaCs GUI bindings.
- Slot buttons work and can cycle configured parts.
- Lua config drives platform slots, defaults, and available parts.
- `InventorySprite` updates correctly after part switching.
- The composed sprite pipeline is working end to end:
  - Lua builds layer spec
  - C# receives the hook
  - textures are composed into one runtime texture
  - a replacement sprite is generated

### Not Yet Working Correctly

- `WorldSprite` does not visibly update as expected.
- `InventorySprite` updates, so the remaining issue is likely in the in-world / held-sprite application path rather than in the texture composition path itself.

## Source Layout

### Lua

- `Lua/Scripts/Gunsmith/Config.lua`
  - platform definition
  - part definition
  - default selections

- `Lua/Scripts/Gunsmith/Main.lua`
  - local selection state
  - `G` key open logic
  - layer spec generation
  - Lua-side part cycling

### C#

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/Plugin.cs`
  - client plugin entry only

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithApi.cs`
  - service-level coordination
  - runtime state ownership
  - disposal

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithHooks.cs`
  - Lua/C# hook bridge

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithGui.cs`
  - dedicated Gunsmith window
  - button creation
  - button click -> Lua callback

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithComposer.cs`
  - layer spec parsing
  - texture composition
  - runtime sprite creation

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithState.cs`
  - internal data containers

- `.AssemblyCSharpSource/GunsmithPatch/ClientProject/ClientSource/GunsmithSpritePatch.cs`
  - Harmony patches
  - sprite persistence hooks
  - GUI refresh hook

## V0 Technical Route

### UI Route

LuaCs cannot directly construct the needed GUI types reliably in this environment, so the gunsmith window is implemented in C#.

Lua is responsible for:

- deciding when to open the UI
- deciding which weapon is active
- deciding current part selection
- sending display data and commands

C# is responsible for:

- rendering the UI
- receiving button clicks
- calling back into Lua for part cycling

### Visual Route

Weapon visuals are built from reusable parts.

Each part describes:

- source texture
- source rect
- offset on the final canvas
- draw order

The final weapon sprite is composed into a runtime `RenderTarget2D`.

This route matches the long-term goal of:

- drawing each part once
- recombining parts in game
- reducing total art workload for future weapons and variants

## Hooks Used In V0

### Lua -> C#

- `DeepGunsmithApply`
- `DeepGunsmithOpen`

### C# -> Lua

- `DeepGunsmithCycle`

## Known Issues

### 1. WorldSprite Not Updating

Symptoms:

- inventory icon changes
- world / held sprite does not yet visibly follow

Likely investigation directions:

- verify which sprite field the weapon actually uses while held
- verify when `SetActiveSprite()` or other item-side refresh logic overwrites the runtime sprite
- inspect whether the held item path uses prefab sprite, active sprite, or another rendering branch
- compare with working sprite replacement logic in `SpritePatch`

### 2. UI Is Functional But Still V0

Current UI is enough for validation, but not yet final-quality gunsmith UX.

Future work:

- better layout
- selected-state visuals
- part preview area
- category grouping
- close / reopen / refresh polish

### 3. Lua/C# Bridge Uses Old Hook API

Current bridge still uses `Compatibility.ILuaCsHook`.

This works for the current prototype, but it produces obsolete warnings during build.

Reason it is kept for V0:

- it matches the working custom hook path for `Hook.Call(...)`
- it is already validated by runtime behavior

## What V0 Has Proven

V0 already proves the core plan is valid:

1. a dedicated gunsmith UI is feasible
2. Lua can remain the configuration side
3. C# can own the heavy UI and runtime sprite work
4. modular gun part composition is feasible in Barotrauma
5. the art pipeline direction is still compatible with "draw parts once, assemble in game"

## Recommended Next Step

The highest-value next task is:

1. solve `WorldSprite` update behavior for held / world rendering

After that:

2. expand from one test weapon to a cleaner AR platform definition
3. improve UI readability and persistence behavior
4. start formalizing part metadata for later stat / attachment interactions

## Branch / Prototype Note

This work is being developed on the `Gunsmith` branch as the prototype line for the new modular weapon customization system.
