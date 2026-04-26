# GunSmith ReadMe

This folder stores development notes for the `GunSmith` prototype under Deep-Diving-Armory.

## Version Notes

- [V0 Summary](./V0_Gunsmith_Summary.md)
- [V0.1 Summary](./V0.1_Gunsmith_Summary.md)
- [V0.2 Summary](./V0.2_Gunsmith_Summary.md)
- [V0.3 Summary](./V0.3_Gunsmith_Summary.md)
- [V0.4 Summary](./V0.4_Gunsmith_Summary.md)
- [V0.5 Summary](./V0.5_Gunsmith_Summary.md)
- [V0.6 Summary](./V0.6_Gunsmith_Summary.md)
- [V0.7 Summary](./V0.7_Gunsmith_Summary.md)
- [V0.8 Summary](./V0.8_Gunsmith_Summary.md)

## Current Direction

The project is currently validating a modular firearm customization workflow for Barotrauma:

- Lua owns configuration and part selection data
- C# owns runtime UI and sprite composition
- weapon visuals are assembled from reusable part layers

## Current Test Scope

The active validation weapons are:

- `deep_m4`
- `deep_hk416`

Current new-system tag:

- `deep_gunsmith`

Current validated slots:

- `receiver`
- `barrel`
- `handguard`
- `pistol_grip`
- `stock`

Current nested validation paths include:

- `handguard/top_rail`
- `handguard/bottom_rail`
- `handguard/left_rail`
- `handguard/right_rail`
- `handguard/top_rail/optic_mount`

## Notes

- This is no longer just the original template readme.
- Template setup details should be read from LuaCs / Luatrauma upstream docs if needed.
- Local version notes for this prototype should continue to live in this folder.
