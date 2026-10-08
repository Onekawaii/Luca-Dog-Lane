Original prompt: PC playthrough of Spiral Field v0.2.1. Identify and repair the next bugs using the supplied recordings, project sources, DC/Demander practices and plugins; add spiral enemies and a boss, shrink menus/HUD, and move terrain editing toward a No Man's Sky-style smooth workflow. Provide receipts and suggestions.

## Active milestone

M-PC-04 / v0.2.2 candidate on `feat/spiral-threats-terraform-hud-v022`.
Rollback: clean `feat/pc-controls-menu-milestone` at `ee19ebdfe6286feb90fe6cc4622d5636873c159e`.

## Evidence / design constraints

- Supplied recordings: `20261008-2044-53.0135814.mp4` (179.13 s) and `20261008-2059-10.2805998.mp4` (166.27 s), 1920x1032/30 fps.
- Observed: atmosphere and dialogue advance without hostile gameplay; top-left header, duplicate stock text, large menu buttons and tall hotbar consume view; terrain edits expose hard cuboid/stepped boundaries and the mountain surface reads faceted.
- Project research recommends minimal contextual HUD, separate focused menus, hybrid smooth terrain plus detailed entities, bounded smooth terraforming, deterministic world-change deltas, and progression that changes hazards/enemies/resources.
- Preserve current block save-delta schema unless a deliberate versioned migration is required. No external dependency or engine/plugin upgrade.

## Planned invariants / falsifiers

1. Spiral pressure owns a bounded encounter budget: DORMANT=0, AWAKE=2, INFECTED=4, VELVET BREACH=6 plus one boss; boss defeat persists and prevents respawn.
2. Enemies visibly pursue/attack, hammer damage reduces health, death removes them, and player damage/respawn is observable through HUD/runtime state.
3. Terrain tools use a bounded spherical brush and controlled hold cadence; every changed voxel persists and mining conserves resource counts. The macro surface uses shared smooth normals and finer sampling.
4. Desktop gameplay retains crosshair/hotbar/health/threat essentials while header, quickbar, encounter, inventory, map and pause surfaces are materially smaller.
5. Existing PC controls/menu, voxel, vehicle, inventory, lantern, persistence and Spiral tests remain green.

## TODO

- [x] Implement Spiral enemy/boss subsystem and health loop.
- [x] Implement compact HUD/menu layouts.
- [x] Implement bounded terraform brush and smooth macro-mountain repair.
- [x] Add behavioral acceptance/demolition tests.
- [x] Run static, unit, headless and rendered source checks.
- [ ] Export Windows/Android, execute the Windows artifact, and package final hashes.
- [x] Append the M-PC-04 engineering record; exact export hashes live in the generated release receipt.

