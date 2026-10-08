# M-PC-04: Spiral threats, compact HUD, bounded terraforming

## Outcome

Spiral Field v0.2.2 turns the Spiral pressure states into gameplay: two sentinel families appear as the field wakes, the Coil Maw appears at the Velvet Breach, both sides can deal damage, and boss defeat survives save/reload. The gameplay HUD, hotbar, inventory, map and pause menu use less screen area. Terrain tools now support bounded spherical brushes with hold-to-edit cadence, while the macro terrain uses denser sampling and shared smooth normals.

## Architecture

```text
SpiralWorldDirector (authoritative pressure + schema 3)
  -> exact bounded threat budget
  -> SpiralEnemy instances (minor/boss)
  -> HUD threat snapshot

Player health/tool input
  -> hammer damage against threats
  -> mine/place spherical brush
  -> TerrainSlice deltas + conserved pickups

MacroTerrain
  -> 8 m sampled shared vertices
  -> indexed normal generation
```

`SpiralWorldDirector` owns progression and persistence; enemies do not write story state. `TerrainSlice` remains the sole terrain edit/inventory persistence owner. HUD and menus only present or route authoritative state.

## Evidence and repairs

- Recordings: `20261008-2044-53.0135814.mp4` (179.13 s) and `20261008-2059-10.2805998.mp4` (166.27 s), both 1920x1032 at 30 FPS.
- Observed: Spiral state changed atmosphere/dialogue but produced no enemy or boss; HUD/menu coverage obscured play; edits exposed blocky shafts and mountain triangles read as faceted.
- Research source: contextual HUD, focused menus, hybrid editable voxel terrain, bounded editing resources, and progression that changes hazards/enemies/resources.
- Repair: bounded sentinels/boss, player health loop, compact surfaces, spherical multi-voxel edit modes, indexed smooth macro normals, and 8 m terrain sampling.

## Acceptance receipts

- Python contracts: 46/46 PASS.
- Dedicated `spiral_threat_terraform_hud_acceptance.gd`: exact 0/2/4/6+boss budgets, damage/death, boss persistence, brush sizes 1/7/27, UI bounds and schema 3 reload PASS.
- Regression: runtime playability, v0.16 systems, Spiral verbs/persistence, lantern/hotbar, inventory, terrain slice, terrain climb, Quarry, presentation, reset and full-world voxel suites PASS.
- Windowed input: LMB damage, keyboard-echo rejection, pointer recapture, modal input ownership and vehicle view controls PASS.
- Rendered captures: `dist/v022-captures/` contains boss HUD, inventory, map and pause evidence.
- Final Windows/APK paths, byte sizes, signatures and SHA-256 values are written by the clean build to `dist/RELEASE_RECEIPT_Spiral-Field-v0.2.2.json`.

## Known limits / next engineering moves

1. The spherical brush still edits discrete block voxels. A true continuous-density/SDF plus Transvoxel migration should be isolated behind a versioned save converter and performance budget.
2. Threat pursuit is deterministic and bounded but does not yet use navigation, authored attacks, loot, spawn telegraphs or audio cues.
3. Validate Android touch layout, remesh latency and memory on physical hardware; the connected emulator is offline.
4. Add terrain undo/redo or preview volume before increasing brush size beyond 1.75 m.
