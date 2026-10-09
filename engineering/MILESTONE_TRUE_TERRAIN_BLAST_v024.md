# Spiral Field v0.2.4 — Ground Truth Demolition Hotfix

**Player report (2026-10-09):** explosive barrels looked like decorative physics cylinders; explosions left generated surroundings unchanged. Screenshots show overlapping red barrels, HUD still reading v0.2.2, and mining/underground visual shortcomings.

## Root-cause receipt
- v0.2.3 `TerrainSlice.blast_placed_blocks` had `if not edits.has(key): continue`. Every originally generated stone/grass voxel was therefore immune. Existing test built its own house and proved only those newly placed voxels could be destroyed: misleading acceptance.
- HUD version label was hardcoded, not driven by the packaged version.
- Duplicate action stacked barrels vertically without an overlap test or quota.

## v0.2.4 repair
- Replace authored-only destruction with `blast_world_blocks`. Its candidate list is sorted by radial distance and limited to 256 edits per detonation. Each loaded non-air voxel (authored or generated) receives distance-attenuated material-resistance damage. The authoritative `VoxelTool.set_voxel(AIR)` and `SlicePersistence.set_voxel_delta(AIR)` persist craters. `MacroTerrain.mark_voxel_edit` masks the overlapping smooth mesh so the destroyed world isn't obscured by cosmetic terrain. No terrain generator or persistence schema change.
- Explosive blast also applies enemy damage, player damage, rigid-prop impulse, bounded chain detonation, flash/SFX and up to 12 ephemeral *RigidBody3D* debris pieces.
- Prevent overlapping duplicates with radial search instead of continuously increasing Y; bound player-created/live explosive barrel spawns (14); barrel visual shrunk to a usable scale and yellow hazard bands; developer spawn entry explicitly names EXPLOSIVE.
- HUD title version derives from `application/config/version`, not a hardcoded string.
- Keep using `user://v023_world_voxels_<seed>.json` as the save namespace: v0.2.4 is a compatible repair of v0.2.3, not a destructive migration. Existing v0.2.3 saved construction remains intact, and v0.2.2 is still copy-only fallback.

## Acceptance (release blocker)
1. Blast a barrel above *pristine* generated terrain with **no existing edit key**.
2. Prove surface voxels removed and that a physics ray reads a *lower collision height* at the crater after collision rebuild.
3. Verify the destroyed terrain saves as AIR and restores as AIR after a real world restart.
4. Re-run the existing house construction/demolition/persistence test.
5. Re-run 46 Python contracts, world generation and player/Spiral/boss/regression gates, Windows packaged runtime probe, Android signing + Voxel Tools libraries.

## Open scope
No structural-support simulation for falling roofs; free rigid debris is bounded short-lived feedback, not voxel chunk fracturing. Barrel props themselves do not persist across saves yet. The user-provided Android screenshots constitute failed v0.2.3 playtest evidence, not proof that v0.2.4 works on a handset. Android touch/screen testing must be repeated before stable promotion.
