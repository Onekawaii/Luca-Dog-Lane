# World support and generation candidate — 2026-10-10

Status: PARTIAL, source-only draft; no release or physical-device qualification.

## Exact source

Onekawaii/Luca-Dog-Lane `feat/spiral-voxel-world-loadout-v025`, baseline `d136df1c7aca72c71010524d8e00c1f535b53859`. Local branch `fix/world-support-and-variation`, text-only snapshot HEAD `acf83d453baa07c0e72e0555192affadab4b959c`. The supplied screenshot says v0.2.7; that exact source was not found among published branches. Port/retest this candidate against the actual screenshot build before claiming its repair. TOOLCHAIN_LOCK.json remains unchanged (Godot 4.7.2 / Voxel Tools 1.7).

## Invariant, falsifier and ownership

A visible/generated surface is insufficient: streamed voxel data through the support column and a matching native collision floor must both exist before gravity resumes. Null voxel rays never mean ready. Far actors relinquish their collision viewer and park; nearby actors own collision-only viewers. Holding updates the desired freeze state through the guard. Companion catchup runs outside suspended motion and respects STAY.

The voxel layer at y=−16 is protected bedrock (new ID 10; old IDs unchanged). Mining, placement, blasting and saved-edit replay all reject that layer. A permanent world-owned floor at top y=−15 remains collidable through stream unload, and outer walls reach it. Recovery runs before the player streaming early-return to escape already stranded positions.

Continue reloads a persisted seed/generator identity per map. New Generated World flushes current terrain/story saves, chooses a new seed and retains old files. Version 2 varies macro terrain regions; old-world identities retain version 1. Supported v1/v2 story, terrain and loadout saves select the legacy identity on first migration. New terrain uses v026 per-seed paths/persistence generator 3; legacy terrain paths/generator 2 remain unchanged. Story progress for new worlds uses map+seed paths. Generator settings remain reproducible with explicit seed/version overrides.

## Mobile cost and rollback

Remote guards sleep beyond 80m, wake within 64m. Nearby viewers usually need 32m; depth requests expand only to the support floor/bedrock, bounded at 144m. Terrain max viewer distance is 144m for the full-world adapter. This bounds distance, not measured mobile memory or frame time; dense actors and high cliff/deep-hole cases need telemetry. Rollback is the baseline branch plus old per-seed files; main and published artifacts remain unchanged. Archived worlds remain on disk; an archive-browser UI is not supplied. Entity transforms/injuries are not newly persisted.

## Receipts

- Available engine: `/usr/local/bin/godot`, 4.6.3.stable.official.7d41c59c4, without Voxel Tools. Locked-engine and actual voxel generation/remeshing acceptance are blocked.
- `XDG_DATA_HOME=/tmp/hive-godot-data XDG_CONFIG_HOME=/tmp/hive-godot-config XDG_CACHE_HOME=/tmp/hive-godot-cache godot --headless --path /workspace/Spiral-Field --script res://tests/world_support_generation_acceptance.gd`: exit 0, zero failures; 27 of 30 sampled heights vary by >1m across seeds, same-seed samples match exactly.
- Native collision/gravity fixture falsifies absent floor, null voxel result, distant unload, early approach, held release/resume, distant companion/STAY, below-bottom recovery, deep gap and cached bedrock beneath missing intermediate data. It substitutes voxel data and does not exercise Voxel Tools.
- Disk identity reload and actual SlicePersistence edit reload/new-world isolation pass; actual Voxel Tools remesh/replay remains unexecuted. Bedrock protection predicate passes; actual generator/mining/blast tests remain locked-engine gates.
- `python -m unittest discover -s tests -q`: 46 checks, exit 0. Editor import exit 0 with sandbox socket errors. No SCRIPT ERROR in focused run. Exact source/log hashes: WORLD_SUPPORT_RECEIPT_2026-10-10.json.
- Independent Demander reviewed source and independently reran focused tests; source-only PARTIAL. No exported Windows runtime, APK/signature or physical Android qualification.

## Exact next action

Executor with full upstream checkout, staged locked Godot/Voxel Tools and physical Android: fetch draft branch, preserve the last release, then use the pinned console executable from TOOLCHAIN_LOCK.json:

```powershell
& $pinnedGodot --headless --editor --path . --quit
& $pinnedGodot --headless --path . --script res://tests/world_support_generation_acceptance.gd
& $pinnedGodot --headless --path . --script res://tests/world_voxel_acceptance.gd
& $pinnedGodot --headless --path . --script res://tests/spiral_build_blast_acceptance.gd
& $pinnedGodot --headless --path . --script res://tests/player_world_reset_acceptance.gd
```

Use isolated SPIRAL_WORLD_INDEX_PATH, SPIRAL_STATE_SAVE_PATH, SPIRAL_LOADOUT_SAVE_PATH and LUCA_V013_SLICE_SAVE_PATH with `{seed}` for those acceptance probes. Run real mine/blast/place/reload at y=−16, absent/remeshing floor, parked car at increasing distances, deep excavations/cliff jumps, New/Continue across maps, and forced-mobile/menu acceptance. Measure active viewers, memory and frame times. Only after exact-commit acceptance export with BUILD_SPIRAL_FIELD.ps1 and verify the physical target; append artifact hashes and device evidence to the ledger.

## Editions and crossover

Hive and Spiral remain separate editions. Seed/version identities provide reproducible worlds within each edition; the algorithms are different. A future crossover needs explicit portal entry, edition-qualified identity and a reviewed character/inventory transfer policy. That crossover is not implemented or released here.
