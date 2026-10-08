# Voxel world and object presentation development pass

## Exact state and intent

Branch: `feat/voxel-world-presentation`; baseline: `1d564e1c57634f01fc2282e35e351307fbadcf04`.
Godot 4.7.2, Voxel Tools 1.7, pinned in `TOOLCHAIN_LOCK.json`; no engine/plugin migration.
The baseline release files remain untouched. Project mirror `sources/` was not edited.
Desktop Commander device LAPTOP-AETIRLES, ID ae4b6eeb-1f82-492b-8c62-b2d8273a3762,
was used to confirm repository HEAD, create the development branch, acquire materials,
and run the rendered and headless Godot probes.

Player-facing acceptance: editable terrain across the map, unmistakable equipped
tool icon/model, visible NPC/car damage, recognizable cat and continuous Spirals,
object-specific surface materials, preserved driving/crafting/encounter behavior.

## Ownership and compatibility

- `WorldVoxelGenerator` owns immutable generation: cached 12m macro-height grid,
  one-metre voxel cells throughout 960m x 960m, vertical bounds -16..112m.
  Original quarry/cave generation remains authoritative in its authored rectangle.
- `TerrainSlice` retains mutation, streaming, block IDs and inventory interfaces.
  The distant macro mesh is visual-only and discarded within 60m of the camera;
  local voxel view distance remains 76m. The old hidden floor is noncollidable.
- `WorldStreamGuard` gives NPCs, Luca, vehicle and sandbox props 24m collision-only
  bubbles and suspends them while local data/collision is loading.
- `Player` waits for local collision streaming and auto-steps one-metre risers.
- New generation version 2 uses `v020_world_voxels_<seed>.json`. Compatible old
  quarry deltas/inventory are copied once; old save files are not rewritten.
  World saves coalesce writes over 0.5s and flush on normal shutdown. This is not
  crash-proof/atomic persistence; very large edit sets still need profiling.
- `EquippedTool` owns eight visual models, distinct silhouettes/icons and swing
  animation; `HUD` shows the active icon/name. No tool catalog schema was changed.
- `DamageFeedback` owns a timed overlay and at most eight surface marks per actor.
  NPC health/knockback remain NPC-owned. Buggy gains 200 HP, hood deformation,
  contact-impulse damage and an engine-disabled state at zero HP. NPC impact
  routing uses measured pre-impact relative velocity, avoiding post-solver speed loss.
- `EncounterVisuals` owns cat anatomy and indexed continuous spiral/tail meshes;
  contextual verbs, relationship/progression, interaction colliders and save schema
  remain in `SpiralWorldDirector`.
- Six ambientCG PBR materials (18 maps) are imported at 512px with mipmaps and
  VRAM compression. Source files, licenses and archive hashes are in
  `assets/materials/PROVENANCE.md`. Fur and icons are original procedural artwork.

Rollback: baseline branch/artifacts are preserved; `SPIRAL_WORLD_VOXELS=0` selects
the old terrain path for diagnostics. This development branch is not a main/release promotion.

## Falsifiers and verification

Commands use the pinned Godot console executable with `--path` this repository:

- `python -m unittest discover -s tests -p 'test_*.py'`: 46 tests pass.
- `--headless --editor --import --quit`: import/parser gate, including native addon
  and 18 texture maps; `dist/material-mobile-import.log`.
- `--headless --script res://tests/world_voxel_acceptance.gd`: ordinary launch,
  four remote/edge locations, public mining, removed collision, pickup collection,
  craft/place, auto-step, distant actor support, disk delta reload and reconstructed
  world replay of air/brick/inventory/collision.
  `dist/world-voxel-pass.log`; sampled static memory 118,586,750 bytes. This is not
  peak memory or an Android performance measurement.
- `--rendering-method gl_compatibility --script res://tests/presentation_acceptance.gd`:
  all eight distinct icons/models, actual Player USE hammer on NPC and car,
  health/flash/marks, no accidental vehicle entry, engine disable, forced-mobile
  steering path, cat/Spiral captures. `dist/presentation-pass.log`.
- `--headless --script res://tests/v016_systems_acceptance.gd`: actual driving,
  four-wheel resting contacts, braking, NPC collision damage, companion behavior,
  and map-specific terrain/save paths. `dist/world-v016-regression.log`.
- `--headless --script res://tests/vehicle_damage_acceptance.gd`: a physical wall
  impact reduced car health from 200 to 195.876771262213 and created visible damage
  geometry. `dist/vehicle-damage-pass.log`.
- `--headless --script res://tests/spiral_field_acceptance.gd`: contextual verbs,
  collision stand-off, pressure/environment changes and save/reload.
  `dist/spiral-presentation-final.log`.
- `SPIRAL_WORLD_VOXELS=0` plus `runtime_playability.gd`: legacy fallback gates;
  `dist/legacy-playability-final.log`. Not a claim that the old continuous-mesh
  assertions qualify the new voxel path.

Rendered evidence: `dist/verification/presentation-{cat,spiral,npc-damage,car-damage}.png`.
The independent Demander's first pass rejected hidden car marks, floating cat,
oversized tool, opt-in terrain, unprotected remote actors and weak mutation tests.
These drove repairs and stronger probes; revised evidence must be judged independently.

## Limitations / honest scope

This is full-map voxel TERRAIN, not voxel destruction of every tree, building,
road skin or entity. Visual distant terrain is an LOD mesh. Cat is a stylized
original model, not a photorealistic licensed/scanned animal. NPC/car damage is
visible surface feedback and health, not component destruction or a full injury
simulation; it is not saved across map reloads. Road skins can remain visible
over holes mined beneath them. Large edit-set performance, crash-safe saving,
LOD handoff and fast streaming need additional stress testing.

Android device enumeration sees only `emulator-5554 offline`; no physical-phone
installation, input, frame-rate, thermal or memory acceptance is claimed.
Original recording review remains two-second systematic sampling plus targeted
frames, not literal inspection of every encoded frame; see the prior timecoded
`PLAYTEST_REVIEW_2026-10-08.md`.

One existing Spiral acceptance run initially used its default save location and
left test progression (VELVET BREACH). That test is now routed to a unique save
override, as are the new probes. No silent reset/restoration of the affected
normal save was performed; the prior normal save cannot be recovered from this
run's receipts. This side effect is not represented as preservation success.

## Exported checkpoint receipts

Game source commit: `6846c6017fa4b26c3c5fff19e3284643e885d5bd` on
`feat/voxel-world-presentation`. Both are debug development candidates, not releases.
Output folder: `dist/voxel-candidate-6846c60/`.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| SpiralField-voxel-pass.exe | 107576096 | 9082820f6408d34c3665901680d31a0e95c9f8ab5817f0dbfdf25f903c30a37e |
| SpiralField-voxel-pass.apk | 79636613 | a4119a1a36bffbaeacfa4c86da9562147e06ac210578dac518e08c035b043bfa |

Windows requires the adjacent `libvoxel.windows.editor.x86_64.dll`; retain the
candidate folder together. Export logs: `windows-export.log`, `android-export.log`.
Exported Windows console runtime, through DC, exited 0 in 17.15 seconds with
`[ALL PLAYER TERRAIN TOOL GATES PASSED]`; see `windows-runtime.log`.
APK signature verification passed v2 and v3, one signer. APK manifest reports
`com.onekawaii.spiralfield`, version `0.2.0`; ARM64 and x86_64 Godot and Voxel
native libraries are present. This is packaging evidence, not Android playtesting.
Original v0.2 Windows and Android release hashes were reconfirmed unchanged.

Status: PARTIAL pending final independent judgment and Android device acceptance.
Full object voxelization, realistic animal art, literal frame-by-frame recording
review and streaming/edit stress qualification remain incomplete. No completed-release claim.
