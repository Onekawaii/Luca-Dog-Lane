# Spiral Field v0.2.5 — Unified Voxel Terrain and Separated Inventory/Loadout

## Player report and acceptance intent
The v0.2.4 explosion physically removed terrain voxel collision, but flat road meshes and smooth macro scenery still rendered above the hole. In addition, the Field Satchel incorrectly mixed owned stock, every catalog item (including zero quantities), and crafting/selection. The 1–0 hotbar was hardcoded.

**New player-facing contract:** the Satchel reports only items the character actually carries. Example: 20 apples and 10 each of stone, grass, brick, wood and metal: six item types, 70 units. Build/Discovery lists all available block types, recipes, blueprints, and acquired item types. Loadout edits nine independent, assignable hotkeys 1–9 (PC keyboard and touch buttons). Persistent loadout and discovery are world-specific, independent of the unchanged schema-1 voxel-world save.

## Source of truth
- `MacroTerrain.height_at` remains only a deterministic, nonrendered procedural terrain-height provider in voxel mode. **No `TerrainMesh` or `TerrainCollision` node is created** when voxel rendering is enabled. These remain available only when the older nonvoxel compatibility mode is explicitly selected.
- `WorldVoxelGenerator` generates mountains, roads, road lines, plaza, sandbox pad, skate floor and quarry terraces as actual Voxel Tools block data. Road block IDs **8 asphalt, 9 line** appended without renumbering 0–7. World rendering and collision now use the same `VoxelTerrain` + `VoxelMesherBlocky`. Road overlays and pad/floor skins do not exist in voxel mode.
- Explosion `blast_world_blocks` continues to write AIR into VoxelTool + SlicePersistence. No ghost road/smooth macro cover can remain after the edit.
- `SandboxInventory` remains authoritative for real counts; `PlayerInventoryPanel` filters nonzero stock. The new `BuildCatalogPanel` owns all catalog materials/recipes/discovered types. `HotbarLoadoutPanel` owns assignment workflow; `PlayerQuickbar` displays and activates assignments.
- `LoadoutState` persists `{schema_version:1,world_seed,slots[9],discovered[]}` separately in `user://v025_loadout_<seed>.json`. Existing `user://v023_world_voxels_<seed>.json`, original v0.2.2 copies, and Spiral schema-3 story/boss states stay unchanged. World reset backs up loadout and world saves.
- New `apple` catalog entry permits food stock without mixing food into building palette.

## Controls
PC: **I = Satchel**, **B = Build Library/Discovery**, **O = Hotkey Loadout**, **1–9 = assigned item/tool**. Android: distinct **INVENTORY**, **BUILD**, and **1–9 SLOTS** right-side touch menu buttons and nine bottom action buttons.

## Verification evidence
- `tests/voxel_surface_loadout_acceptance.gd`: world boots with no macro mesh or floating road/pad overlays; asphalt and road stripe exist as voxel IDs 8/9. Barrel removes 30 road voxels, collision drops, voxel damage persists across full game reload; 20 apples + 5×10 materials; stock menu exact; all menus independent; discovered types and assignments persist separately.
- `tests/visual_voxel_capture.gd`: runs **real nonheadless OpenGL 3.3** on GTX1650; saves 1280×720 road-before/road-after image pair, projects blast center into camera screen and requires >300 changed pixels in 80×80 blast region (independent of HUD toast). On 2026-10-09 this measured **1,890** substantial changed pixels and the crater was visibly inspected in the captured image.
- `tests/hotbar_lantern_acceptance.gd`, `tests/player_inventory_acceptance.gd`, `tests/pc_playtest_presentation_acceptance.gd`, `tests/runtime_playability.gd`: old flows and all-new ownership passed independently.
- 46 Python contracts passed. Full ten-stage Windows/Android release pipeline required before calling release verified.

## Known limitations
1. Roads and terrains are blocky 1-meter cubes; the old smooth height mesh is intentionally disabled. Smoothing/meshing optimization is subsequent work, not something to fake with a visual overlay.
2. Existing permanent buildings, workshop walls, NPCs, trees and vehicles are separate authored 3D actors, not yet fully voxel-damageable. This change establishes a single authority for **terrain, road, pads, and quarry terraces**.
3. Unbraced roof sections still lack real load-bearing physics; barrel props aren't persistent.
4. Physical Android GPU/touch performance and screenshot-based acceptance are pending even when export-signing tests pass. Keep v0.2.4 rollback release and main unchanged until device playtesting.

## Files
`scripts/Game.gd`, `scripts/HUD.gd`, `scripts/Player.gd`, `scripts/world/{MacroTerrain,TerrainSlice,WorldVoxelGenerator}.gd`, `scripts/systems/{LoadoutState,PlayerInventoryPanel,PlayerQuickbar,BuildCatalogPanel,HotbarLoadoutPanel}.gd`, `data/items_v016.json`, release and tests, no other gameplay architecture rewritten.

No receipt, no banana.
