# Spiral Field v0.2 — Player Systems Repair / 2026-10-08

Status: DEVELOPMENT BRANCH. NOT A VERIFIED PHONE RELEASE.

Branch: `repair/spiral-player-systems-20261008`
Starting checkpoint: `8a28f3a` on `feat/voxel-world-presentation`
Local repo: `C:\Users\jmgar\Downloads\SpiralFieldGame`
No release branches, existing APKs, or existing save data deliberately replaced.

## Evidence and user-observed symptoms
User supplied two October 8 Android screen recordings and ten screenshots. Field evidence includes:
- tool mode without a useful inventory/material palette;
- mine/place/craft unclear and opaque resource accounting;
- map transition dialog with three visually similar environments, but no terrain map;
- NPC bodies translating without corresponding articulated gait;
- cat showing dialogue but almost no action, Luca endlessly adjusting/circling;
- visible square terrain cavities and harsh boundary seams during mining;
- no accessible fresh-world control, restart, cleanup, and universal mobile noclip.

Screenshots alone do not establish the exact terrain/collision root cause. That issue remains for physical device reproduction.

## Implemented — playable source changes
- Toggleable INVENTORY menu with item quantities, descriptions, item selection and craft recipes; hotkeys I / B.
- Source-of-truth `SandboxInventory` and `ContentRegistry`, rather than shadow copies of item counts.
- Grass mining yields GRASS BLOCK; authored stone yields STONE; brick yields STONE BRICK. Player picks drops and crafts existing recipes.
- Selected inventory building blocks map to actual voxel types and persistent consumption.
- World topographic survey based on actual macroterrain height samples, player and encounter pins.
- Backup-first NEW WORLD action with double confirmation, independent restart, per-seed save namespaces, clean spawns/ragdolls, mobile NOCLIP, development DAY/NIGHT and Luca STAY/FOLLOW.
- Lightweight motion added for NPC legs/arms/feet and Luca legs/tail; cat head/paws/tail react for 2 seconds to TALK/PET/FEED.
- Separate temporary-save namespaces for tests and reset; original saved world bytes checked unchanged by reset acceptance.

## Verification receipts
- Pinned Godot 4.7.2 importer: exit 0 (latest import after initial fix).
- Python `python -m unittest discover -s tests -p test_*.py`: 46 OK.
- Godot `tests/player_inventory_acceptance.gd`: PASS for inventory and recipe selection; topographic map gate added subsequently.
- Godot `tests/player_world_reset_acceptance.gd`: PASS for backing up before wipe; reinstantiate fresh state; normal world unchanged.
- Godot `tests/v016_systems_acceptance.gd`: ALL PASSED incl. 3 map profiles and independent saves.
- Godot `tests/spiral_field_acceptance.gd`: ALL PASSED incl. world-state reloading.
- Godot `tests/world_voxel_acceptance.gd`: exit 0 after correcting the material-specific mining test for grass/stone; four remote locations, crafting, solid placement, collision, save reload.
- Godot `tests/presentation_acceptance.gd`: exit 0.
- Relevant diagnostic logs: `dist/repair-*.log`.

## Known incomplete requests
- All three maps still share most authored roads, workshop, quarry, and encounter landmarks. New seed, terrain and atmospheric differences are not genuinely independent authored worlds.
- Procedural primitive limb movement is not full rigged gait, task-driven NPC AI, real animal locomotion/utility, or autonomous cat behavior.
- Luca now has STAY/FOLLOW, but movement pathfinding and companion interaction sophistication need mobile acceptance.
- Topographic survey shows terrain height samples and markers; it does not yet show player voxel edits, route navigation, or interactive teleport.
- No typed operator console. Day/night is a simple dev preset, not a persistently simulated clock.
- No persistent block-discovery unlock ledger or broader recipe tree; inventory displays the complete item catalog.
- Clean world resets edits, inventory and story state; preset sandbox props/landmarks are re-created by authored world startup.
- Square mining cavities, terrain seam visual quality, underground lighting/edge geometry and Android physical gameplay remain unverified against video reproduction.
- There is no true ragdoll system to reset, but the cleanup operation supports any entities tagged `ragdoll`.
- No physical phone acceptance or FPS/memory profiling of this branch has been done yet.

## Strict release gate
This branch must not be described as complete. Do not overwrite original v0.2 APK. Export a clearly labeled preview separately, verify Windows binary and Android signature, get user physical-phone retest for controls, terrain, UI size, animal animation. Then tackle remaining systemic issues in controlled passes rather than treating superficial animation as full AI.
