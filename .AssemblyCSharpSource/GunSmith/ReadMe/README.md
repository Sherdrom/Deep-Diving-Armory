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
- [V0.9 Summary](./V0.9_Gunsmith_Summary.md)
- [V0.9.1 Summary](./V0.9.1_Gunsmith_Summary.md)
- [V0.9.2 Summary](./V0.9.2_Gunsmith_Summary.md)
- [V0.9.3 Summary](./V0.9.3_Gunsmith_Summary.md)
- [V0.9.4 Summary](./V0.9.4_Gunsmith_Summary.md)
- [V1.0 Summary](./V1.0_Gunsmith_Summary.md)
- [V1.0 Content Production Guide](./V1.0_Content_Production_Guide.md)
- [V1.1 Summary](./V1.1_Gunsmith_Summary.md)
- [V1.2 Summary](./V1.2_Gunsmith_Summary.md)
- [V1.2.1 Summary](./V1.2.1_Gunsmith_Summary.md)
- [V1.3 Summary](./V1.3_Gunsmith_Summary.md)
- [V1.3.1 Summary](./V1.3.1_Gunsmith_Summary.md)
- [V1.3.2 Summary](./V1.3.2_Gunsmith_Summary.md)
- [V1.3.3 Summary](./V1.3.3_Gunsmith_Summary.md)
- [V1.4 Summary](./V1.4_Gunsmith_Summary.md)
- [V1.4.1 Summary](./V1.4.1_Gunsmith_Summary.md)
- [V1.4.2 Summary](./V1.4.2_Gunsmith_Summary.md)
- [V1.4.3 Summary](./V1.4.3_Gunsmith_Summary.md)
- [V1.5 Summary](./V1.5_Gunsmith_Summary.md)

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
- HK416 quick-mod ItemContainer bridge for terminal attachment slots

Current nested validation paths include:

- `receiver/barrel`
- `receiver/handguard`
- `receiver/pistol_grip`
- `receiver/stock`
- `receiver/optic_mount`
- `receiver/receiver_top_rail`
- `receiver/receiver_top_rail/rear_optic_mount`
- `receiver/receiver_top_rail/front_optic_mount`
- `receiver/handguard/top_rail`
- `receiver/handguard/bottom_rail`
- `receiver/handguard/left_rail`
- `receiver/handguard/right_rail`
- `receiver/handguard/top_rail/optic_mount`
- `receiver/handguard/Lower_rail_mount`
- `receiver/handguard/Right_rail_mount`
- `receiver/handguard/Left_rail_mount`
- `receiver/barrel/muzzle_mount`

Current quick-mod UI validation paths include:

- HK416 hidden original ItemContainer slots `1-5`
- HK416 quick-mod UI through `Shift+G`
- HK416 `showWhenContained` visible underbarrel slot with managed drag/drop blocking

## Notes

- This is no longer just the original template readme.
- Template setup details should be read from LuaCs / Luatrauma upstream docs if needed.
- Local version notes for this prototype should continue to live in this folder.
