# Luca Dog World — Build Ledger

Append-only engineering evidence. New entries go at the bottom. Do not rewrite failed history.

## Ledger schema

Every entry must contain:

- **ID**
- **Date**
- **Branch / HEAD**
- **Goal**
- **Observed evidence**
- **Invariant**
- **Hypothesis**
- **Falsifier**
- **Design decision**
- **Files changed**
- **Commands executed**
- **Results**
- **Demolition**
- **Performance**
- **Artifacts**
- **Known limitations**
- **Status**: PLANNED / IN_PROGRESS / PASS / PARTIAL / BLOCKED / REVERTED

---

## ENG-000 — Establish hardened engineering discipline

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation` from `76f9659321824ea61460256a0bdbc8619b34035a`
- **Goal:** Make engineering procedure enforceable before v0.13 architectural work begins.
- **Observed evidence:** v0.12.x improved rapidly, but repeated physical Android playtests exposed failures that static/source-presence tests did not catch.
- **Invariant:** No substantial architectural claim may be promoted without behavioral evidence from the exact candidate state.
- **Hypothesis:** A repository-local protocol + append-only ledger + executable contract checker will reduce untracked assumptions and accidental "green by construction" tests.
- **Falsifier:** Delete or corrupt the protocol/ledger/toolchain lock and confirm the checker fails.
- **Design decision:** Add `AGENTS.md`, this ledger, `TOOLCHAIN_LOCK.json`, and `tools/check_engineering_contract.py`.
- **Files changed:** `AGENTS.md`, `engineering/BUILD_LEDGER.md`, `engineering/TOOLCHAIN_LOCK.json`, `tools/check_engineering_contract.py`.
- **Commands executed:** see exact terminal receipts for this session; checker command is `python tools/check_engineering_contract.py`.
- **Results:** IN_PROGRESS.
- **Demolition:** pending contract corruption test.
- **Performance:** N/A.
- **Artifacts:** none.
- **Known limitations:** A process document cannot guarantee discipline; enforcement must increasingly move into executable gates.
- **Status:** IN_PROGRESS

---

## ENG-001 — v0.13 substrate migration proof

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation`
- **Goal:** Prove Luca Dog World can move from unsupported Godot 4.3 to pinned Godot 4.7.2 without destroying the v0.12.2 rollback point, then stage an editable voxel substrate.
- **Observed evidence:** local toolchain currently contains only Godot 4.3. Official release data identifies Godot 4.7.2 as stable. Voxel Tools 1.7 provides a GDExtension package for Godot 4.5+.
- **Invariant:** v0.12.2 must remain reproducible while migration work occurs on this branch.
- **Hypothesis:** Godot 4.7.2 + Voxel Tools 1.7 GDExtension can support Windows + Android while keeping the project on official Godot binaries.
- **Falsifier:** Any of: project fails to parse/run on 4.7.2; v0.12.2 acceptance regresses before voxel integration; voxel extension cannot load; Android extension binaries are absent/incompatible; export cannot package/sign.
- **Design decision:** Install 4.7.2 side-by-side. Pin Voxel Tools v1.7x by SHA-256. Do not modify terrain architecture until the engine migration baseline is green.
- **Files changed:** pending.
- **Commands executed:** pending.
- **Results:** PLANNED.
- **Demolition:** pending.
- **Performance:** establish baseline before voxel terrain.
- **Artifacts:** pending.
- **Known limitations:** Voxel Tools documents the GDExtension edition as newer and less tested than module builds; treat this as an explicit dependency risk.
- **Status:** IN_PROGRESS

---

## ENG-002 — Qualification receipt for engineering protocol + voxel substrate

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation` at pre-commit state based on `76f9659321824ea61460256a0bdbc8619b34035a`.
- **Goal:** Qualify the repository engineering protocol and the smallest editable-voxel substrate slice.
- **Observed evidence:** Existing v0.12.2 behavior passes unchanged under Godot 4.7.2. Pinned Voxel Tools 1.7 GDExtension loads and exposes required classes. A streamed voxel region accepts a block write, authoritative readback, block removal, and state restoration.
- **Invariant:** No v0.13 terrain architecture work proceeds unless the old product behavior survives the engine migration and the new voxel primitive is directly editable.
- **Hypothesis:** Godot 4.7.2 + Voxel Tools 1.7 GDExtension is a viable development substrate for Luca Dog World.
- **Falsifier:** Corrupt dependency pin; break engine migration; fail extension class load; fail streamed area editability; fail voxel write/read/remove.
- **Design decision:** Keep 4.7.2 and Voxel Tools side-by-side in `%USERPROFILE%\.luca_toolchain`; materialize `addons/zylann.voxel` from the pinned cache and keep generated third-party binaries out of Git.
- **Files changed:** `AGENTS.md`, `.gitignore`, `engineering/BUILD_LEDGER.md`, `engineering/TOOLCHAIN_LOCK.json`, `tools/check_engineering_contract.py`, `tools/bootstrap_v013_toolchain.ps1`, `tools/stage_v013_voxel.ps1`, `tools/verify_v013_migration_baseline.py`, `tools/verify_v013_substrate.py`, `tests/voxel_extension_smoke.gd`, `tests/voxel_edit_smoke.gd`.
- **Commands executed:** `python tools/check_engineering_contract.py`; deliberate corrupted-lock falsifier; `powershell -File tools/bootstrap_v013_toolchain.ps1`; `python tools/verify_v013_migration_baseline.py`; `powershell -File tools/stage_v013_voxel.ps1`; Godot 4.7.2 extension smoke; Godot 4.7.2 voxel edit smoke; `python tools/verify_v013_substrate.py`.
- **Results:** Contract normal gate PASS. Deliberate corrupt-lock gate failed with RC=1 as required; restored gate RC=0. Toolchain archives match SHA-256. Migration baseline PASS. Extension smoke PASS. Voxel edit smoke PASS. Aggregate substrate gate PASS in 17.48 seconds.
- **Demolition:** Initial relative-path falsifier procedure failed before mutation because .NET resolved the relative path against the host process directory; rerun with absolute path correctly failed the corrupted lock. First bootstrap attempt left a stale download process and zero/partial archive; hardened downloader now uses atomic `.part` files, curl failure checks, exact size, and SHA-256. First voxel smoke test used reserved GDScript keyword `class_name`; parser rejected it; corrected test passed. These failures were not hidden or converted to success.
- **Performance:** Only gate runtime measured so far: aggregate substrate qualification 17.48 s on development laptop. No Android frame/memory/voxel remesh telemetry yet.
- **Artifacts:** `%USERPROFILE%\.luca_toolchain\BOOTSTRAP_RECEIPT_v013.json`; generated ignored addon `addons/zylann.voxel`.
- **Known limitations:** No 4.7.2 Windows/Android export qualification yet. No persistence stream, terrain save delta, mountain generator, block inventory, or navigation invalidation yet. GDExtension edition remains an upstream-documented higher-risk path than the module build.
- **Status:** PASS

---

## ENG-003 — Godot 4.7.2 shipping substrate + v0.13 terrain vertical slice

- **Date:** 2026-10-04 (resumed from 2026-10-03)
- **Branch / HEAD:** `feat/v0.13-voxel-terrain-slice`, candidate based on exact qualified export commit `46fc1621ce7c793526d6026896e4bf3ea4cce071`.
- **Goal:** First preserve the proven Godot 4.7.2 + Voxel Tools native export substrate, then prove one bounded streamed voxel terrain slice end-to-end before scaling world generation.
- **Observed evidence:** The parent commit has an exact native qualification receipt: Windows runtime loads Voxel Tools; Android APK is v2/v3 signed and contains arm64 + x86_64 voxel libraries. The resumed slice now streams a deterministic mountain with a through-cave/overhang, supports authoritative mine/place edits, collision remeshing, physical stone pickup, a data-driven 3-stone -> 1-stone-brick recipe, final-state edit persistence, inventory persistence, and real Player/HUD routing. A real no-noclip physics ascent moved the player from approximately `(310,2.81,329)` to `(310,19.40,299.96)`.
- **Invariant:** Existing v0.12.2 playability remains green. Generated terrain is reconstructible; only edit deltas and inventory are saved. Mining/placement never rebuild the whole terrain node. Mobile uses the same TOOL/USE path as desktop. No frozen Hive-Lattice campaign schema is mutated.
- **Hypothesis:** A small Voxel Tools blocky terrain region can provide caves, traversal, mutable collision, gathering, crafting, and restart-safe edits on the qualified shipping substrate without regressing the existing sandbox.
- **Falsifier:** Any of: no solid overhead above cave air; real player cannot climb the slope with noclip off; mine/place does not alter authoritative voxel data; collision does not remesh; mining rebuilds the terrain node; resource never enters inventory; recipe is hardcoded outside data; placement succeeds without material or inside the player; saved edit/inventory disappears after terrain reconstruction; legacy migration/playability or extension smoke regresses.
- **Design decision:** Use a bounded southeast slice `AABB((256,-2,228),(112,54,108))` with deterministic authored generator grammar; keep generator, live terrain controller, persistence, inventory, pickup, and player-facing routing separate; store final-state voxel deltas keyed by coordinate; defer visual material polish and full-world generation until mechanics are qualified.
- **Files changed:** `scripts/world/TerrainSliceGenerator.gd`, `scripts/world/TerrainSlice.gd`, `scripts/systems/SlicePersistence.gd`, `scripts/systems/SandboxInventory.gd`, `scripts/systems/ResourcePickup.gd`, `data/recipes_v013.json`, `scripts/Game.gd`, `scripts/Player.gd`, `scripts/HUD.gd`, `tests/terrain_slice_acceptance.gd`, `tests/terrain_player_flow.gd`, `tests/terrain_climb_acceptance.gd`, `tests/test_clean_room.py`, `tools/verify_v013_terrain_slice.py`, `tools/build_v013_qualification.ps1`, plus generated project-owned GDScript UID sidecars.
- **Commands executed:** locked Godot 4.7.2 parser/import; integrated headless runtime; terrain/collision/persistence acceptance; real Player -> Game -> Terrain flow; real movement/jump mountain ascent; 18-test Python contract suite; engineering contract checker; migration baseline verifier; Voxel Tools extension smoke; streamed voxel edit smoke; non-headless visual capture on GTX 1650; PowerShell qualification-script parse.
- **Results:** Current candidate mechanics PASS. 18/18 Python tests PASS. Engineering contract PASS. Migration baseline PASS. Extension smoke PASS. Voxel edit smoke PASS. Terrain acceptance PASS with zero Godot error markers. Real player flow PASS. Real climb PASS with noclip=false. Visual inspection confirms a mountain silhouette plus a true cave mouth/overhang.
- **Demolition:** Rejected and repaired wrong generator-side `VoxelBuffer.set_voxel` signature; rejected a false cave-roof sample that landed inside the carved chamber; rejected a nominal green run containing a lifecycle error from setting pickup global transform before tree entry; killed a stale scratch Godot process that locked the staged voxel DLL; proved no-material placement is rejected; proved player-overlap placement is rejected without consuming the brick; preserved the real 8 m tool reach after a test incorrectly aimed from 12 m; fixed the player-flow test to move the real VoxelViewer into the slice before waiting for streamed chunks.
- **Performance:** Slice viewer distance 76, terrain max view 96; one bounded `112 x 54 x 108` region only. Non-headless visual verification rendered on NVIDIA GTX 1650. Dedicated Android frame/memory/remesh budget remains unmeasured pending physical-device acceptance.
- **Artifacts:** Parent exact native receipt at `dist/v013-qualification/QUALIFICATION_RECEIPT_v013.json`; temporary visual evidence `eng003_visual_overview.png` and `eng003_visual_cave.png` inspected locally then removed before checkpoint; updated native qualification pipeline now runs the terrain verifier before Windows/APK export.
- **Known limitations:** Visual block materials are intentionally raw/near-white; this is one controlled terrain slice, not the full deterministic world architecture. Physical Android launch, terrain interaction, remesh performance, and persistence remain PENDING and cannot be claimed from package inspection alone.
- **Status:** IN_PROGRESS

---

## ENG-004 — Godot 4.7 UID migration metadata

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation`
- **Goal:** Preserve stable script resource identities created by Godot 4.7.
- **Observed evidence:** Opening the 4.3 project in Godot 4.7 generated `.gd.uid` sidecars for project GDScript files.
- **Invariant:** Script UID sidecars generated by the migration must be committed and must never be globally ignored.
- **Hypothesis:** Tracking the sidecars prevents UID references from degrading to path fallback on another clone/device.
- **Falsifier:** Add `*.uid` to `.gitignore` or delete a GDScript sidecar and confirm `tools/check_engineering_contract.py` fails.
- **Design decision:** Track project-owned `.gd.uid` files. Continue ignoring generated third-party addon binaries under `addons/zylann.voxel/`.
- **Files changed:** project GDScript `.uid` sidecars; `tools/check_engineering_contract.py`; this ledger entry.
- **Commands executed:** inspected generated sidecars; consulted Godot UID migration guidance; strengthened executable contract checker.
- **Results:** Checker now enforces sidecar presence and rejects UID ignore rules.
- **Demolition:** pending final precommit contract run.
- **Performance:** N/A.
- **Artifacts:** project-owned `.gd.uid` files.
- **Known limitations:** Scene/resource UID upgrade and re-save policy will be addressed separately if 4.7 writes scene-level migration diffs.
- **Status:** PASS

---

## ENG-005 — UID policy demolition receipt

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation`, pre-checkpoint state.
- **Goal:** Independently prove the Godot 4.7 UID version-control policy is enforced rather than documented only.
- **Observed evidence:** Godot 4.7 generated project-owned `.gd.uid` files during migration.
- **Invariant:** Project GDScript UID sidecars remain versionable and present.
- **Hypothesis:** The engineering contract rejects any attempt to globally ignore UID sidecars.
- **Falsifier:** Temporarily append `*.uid` to `.gitignore` and run the contract checker.
- **Design decision:** Contract checker inspects both ignore policy and sidecar existence.
- **Files changed:** no persistent test mutation; temporary `.gitignore` mutation was restored.
- **Commands executed:** temporary `*.uid` ignore injection; `python tools/check_engineering_contract.py`; restore; rerun checker.
- **Results:** corrupted policy returned RC=1 with `[FAIL] Godot UID sidecars must not be ignored`; restored state returned RC=0 with all engineering contract gates passed.
- **Demolition:** PASS.
- **Performance:** N/A.
- **Artifacts:** terminal receipt only; temporary logs deleted.
- **Known limitations:** This gate protects script sidecars under `scripts/` and `tests/`; additional source roots must be added if introduced later.
- **Status:** PASS

---

## ENG-006 — ENG-003 precommit native export qualification

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation`, base HEAD `c163f9bd978a3ab026225cf05d18fd40ce6ca55f`, dirty candidate state.
- **Goal:** Prove the pinned Godot 4.7.2 + Voxel Tools 1.7 substrate can produce native Windows and Android artifacts before any terrain migration.
- **Observed evidence:** Matching 4.7.2 export templates were absent initially. Windows export later produced the executable plus native voxel DLL. Android export initially failed because Godot 4.7 requires `export/android/java_sdk_path` in Editor Settings. After toolchain configuration, Android export signed successfully and carried voxel native libraries for both requested ABIs.
- **Invariant:** A local editor/runtime PASS cannot qualify v0.13 delivery. Native exported artifacts must carry, load, and verify the extension independently.
- **Hypothesis:** Pinned Godot 4.7.2 export templates and Voxel Tools 1.7 GDExtension can produce working Windows x86_64 and Android arm64/x86_64 packages while preserving v0.12.2 gameplay.
- **Falsifier:** Any of: wrong/missing export templates; exported Windows DLL absent; exported runtime cannot instantiate `VoxelTerrain`; Android export failure; APK signature failure; missing arm64/x86_64 voxel libraries; repo/test/editor files leak into artifacts.
- **Design decision:** Pin export templates in `TOOLCHAIN_LOCK.json`; install them reproducibly; configure 4.7 Android JDK/SDK/keystore reproducibly; keep native addon binaries generated/ignored; use an environment-gated runtime probe in the real game bootstrap; independently inspect exported artifacts.
- **Files changed:** `engineering/TOOLCHAIN_LOCK.json`, `export_presets.cfg`, `scripts/Game.gd`, `tests/test_clean_room.py`, `tools/check_engineering_contract.py`, `tools/bootstrap_v013_export_templates.ps1`, `tools/configure_v013_android_toolchain.ps1`, `tools/build_v013_qualification.ps1`, `tools/verify_v013_exports.py`, this ledger.
- **Commands executed:** unit suite; engineering contract; diff check; export-template bootstrap; Android toolchain configurator; substrate verifier; Godot 4.7.2 Windows debug export; exported Windows runtime probe; exported normal-runtime smoke; Godot 4.7.2 Android debug export; `apksigner verify`; `aapt dump badging`; APK ZIP payload inspection; aggregate `build_v013_qualification.ps1 -AllowDirty`.
- **Results:** Precommit aggregate gate PASS. Windows exported runtime printed `[ALL EXPORTED VOXEL RUNTIME GATES PASSED]` and normal boot printed `LUCA_SANDBOX_READY`. APK package `com.onekawaii.lucadogworld`, versionCode 14, versionName 0.12.2, v2/v3 signatures PASS, voxel arm64 and x86_64 libraries present, no repo/test/editor leakage.
- **Demolition:** First Android export failed because 4.7 Editor Settings had an empty Java SDK path; fixed via reproducible configurator. First configurator failed because Windows PowerShell treats `java -version` stderr as a terminating native-command error under `ErrorActionPreference=Stop`; replaced with deterministic JDK `release` metadata parsing. First exported-runtime probe attempted `--script`; exported Godot ignored it and booted the configured main scene, so that test was rejected and replaced with an environment-gated real-bootstrap probe. Export logs exposed engineering/editor resource leakage; export filters were tightened and requalified.
- **Performance:** Precommit Windows EXE 103,242,280 bytes; voxel Windows DLL 11,337,216 bytes. Android APK 75,278,311 bytes; voxel arm64 library 9,031,288 bytes; voxel x86_64 library 9,177,136 bytes.
- **Artifacts:** `dist/v013-qualification/QUALIFICATION_RECEIPT_v013.json` marked `PRECOMMIT_ONLY`; local export-template and Android-toolchain receipts under `%USERPROFILE%\.luca_toolchain`.
- **Known limitations:** Physical Android launch/voxel runtime is still PENDING. Precommit artifact hashes are not final because the candidate state is not yet committed.
- **Status:** PASS

---

## ENG-007 — Quarry Ridge player-facing expedition

- **Date:** 2026-10-04
- **Branch / HEAD:** `feat/v0.14-quarry-expedition`, candidate based on protected checkpoint `5768956aa51ab57937247f99c74e0197012b2cb4`.
- **Goal:** Turn the proven v0.13 voxel mountain into an optional, discoverable normal-play destination with a complete enter -> mine/collect/craft/place -> leave loop, without introducing a mandatory quest framework.
- **Observed evidence:** At `5768956` the voxel terrain mechanics were qualified, but the slice was still primarily an engineering target. The new route adds in-world quarry signs/posts and a physical discovery volume while retaining the existing terrain, inventory, crafting, persistence, player movement, and HUD systems.
- **Invariant:** `5768956` remains an untouched rollback point; no save/schema change; no alternate movement or teleport requirement; noclip remains unnecessary; voxel terrain remains authoritative; old v0.13 terrain acceptance must stay green.
- **Hypothesis:** A separate lightweight QuarryExpedition presentation/controller node can make the voxel site legible and purposeful in normal play without coupling site discovery to terrain generation or game-state persistence.
- **Falsifier:** The acceptance test was written first and initially failed because the real game had no Quarry Expedition controller. The repaired candidate must let the real player enter and leave the site using normal collision movement with noclip false, show the site cue, and preserve every existing v0.13 terrain gate.
- **Design decision:** Keep quarry route/discovery presentation in `scripts/world/QuarryExpedition.gd`; use two route signs, an entry sign, six lightweight trail posts, and one Area3D monitoring player layer 4. Game.gd owns/spawns the controller; HUD only receives transient discovery/exit toasts.
- **Files changed:** `scripts/Game.gd`; `scripts/world/QuarryExpedition.gd` + UID; `tests/quarry_expedition_acceptance.gd` + UID; `tools/verify_v014_quarry_expedition.py`; `README.md`; this ledger.
- **Commands executed:** first-fail Quarry acceptance; repaired Quarry acceptance; Godot 4.7.2 UID import; `python tools/check_engineering_contract.py`; 18-test Python suite; v0.13 terrain generation/edit/collision/persistence acceptance; real Player->Game->Terrain flow; real no-noclip climb; non-headless visual viewport capture on GTX 1650; aggregate `python tools/verify_v014_quarry_expedition.py`; clean Windows debug export; exported Voxel Tools runtime probe; exported normal-runtime smoke.
- **Results:** Initial falsifier failed as expected. Repaired Quarry acceptance passes all 13 player-facing gates. Python regression remains 18/18. Existing terrain, player-flow, and climb gates pass, including climb end approximately `(310,19.396,299.963)` with `NOCLIP=false`. Aggregate verifier prints `[ALL V0.14 QUARRY EXPEDITION GATES PASSED]`. Clean Windows export loads Voxel Tools and prints `[ALL EXPORTED VOXEL RUNTIME GATES PASSED]`; normal exported boot prints both `V013_TERRAIN_SLICE_READY` and `LUCA_SANDBOX_READY` and exits 0.
- **Demolition:** The first Windows export was explicitly rejected because the temporary visual PNG at repository root was imported into the package. Temporary probe/image/import/log files were removed, the export directory was rebuilt from scratch, and the package was rerun. Entry/exit testing also proves the site does not rely on noclip or teleportation.
- **Performance:** New site presentation cost is bounded to three Label3D signs, six simple post/cap marker pairs, and one Area3D. Visual evidence rendered on NVIDIA GTX 1650. Android frame/remesh performance was not remeasured in this milestone.
- **Artifacts:** Candidate Windows executable `dist/v014-quarry-candidate/Luca-Dog-World-v014-quarry.exe`, 103,266,280 bytes, SHA-256 `03ef50582e95255dcc611ec6596d649418794248c4ab08628406de1bdfe1431d`; adjacent Voxel Tools Windows DLL present. Temporary visual evidence was inspected and removed before the accepted export.
- **Known limitations:** No physical Android v0.14 playtest is claimed. Quarry visuals remain intentionally lightweight; this is one optional expedition site, not yet the full deterministic seeded world/site generator.
- **Status:** PASS


---

## ENG-008 — Visible Kimi terrain + vehicle camera + Easter egg pass

- **Date:** 2026-10-05
- **Branch / HEAD:** `feat/v0.15.1-mountains-cameras-eggs`, candidate based on Kimi checkpoint `a756a7abc5c4bd42a962c8d5be25f05c382c155f`.
- **Goal:** Make the Kimi world-core visible in normal play by adding real topographic relief, materially different vehicle views, and discoverable Easter eggs without regressing ENG-003 voxel terrain or ENG-007 Quarry Ridge.
- **Observed evidence:** Three deterministic collidable macro-terrain regions now materialize from the Kimi world plan: North Mountain Pass, West Ridge, and South Valley. Wilderness props sample macro terrain height. Buggy camera cycle is DRIVER -> CHASE -> HOOD -> OVERHEAD with distinct transforms and speed-responsive FOV. Twelve fried-egg collectibles spawn as real Area3D pickups and increment a runtime found count.
- **Invariant:** Central sandbox remains playable; primary roads remain low corridors through terrain; ENG-003 voxel terrain remains active; Quarry Ridge remains separate; Kimi seed 6060 remains authoritative; Android/Windows share the same project state.
- **Hypothesis:** Kimi world-space noise plus authored macro shaping can produce immediately visible mountains/valleys at mobile-safe mesh density while preserving deterministic generation and core sandbox controls.
- **Falsifier:** Any of: mountain peak/pass relief below 20 m; valley wall/floor relief below 16 m; missing terrain collision; fewer than 12 eggs; egg collection fails to remove pickup/update count; vehicle cycle fails to reach any of four named views; old playability gates regress.
- **Design decision:** Add three tapered static ArrayMesh terrain patches with trimesh collision instead of replacing ENG-003. Keep central roads flattened as passes/valley floors. Reuse Kimi terrain height/fBm for deterministic macro variation. Keep egg hunt session-scoped for this pass; persistence is deferred.
- **Files changed:** `scripts/world/MacroTerrain.gd`, `scripts/world/EggHunt.gd`, `scripts/Game.gd`, `scripts/Buggy.gd`, `scripts/HUD.gd`, version/export/build metadata, and runtime/static acceptance tests.
- **Commands executed:** Python unit discovery; Godot 4.7.2 import; updated live `runtime_playability.gd`; non-headless GTX 1650 visual probe; diff check.
- **Results:** 26/26 Python tests PASS. Live runtime PASS proves collidable macro terrain, north mountain relief, south valley relief, 12 eggs + collection, four active vehicle cameras, and all prior playability gates. Non-headless OpenGL capture on GTX 1650 visibly shows the road cutting through a steep mountain pass and a distinct chase view behind the buggy.
- **Demolition:** The old two-camera contract was replaced rather than layered. Temporary visual-probe script was removed after captures. Generated icon import noise was restored before checkpoint.
- **Performance:** Three low-density terrain patches at ~14 m cell spacing; static concave collision only. No full-world voxel replacement. Dedicated physical Android FPS/memory telemetry remains pending.
- **Artifacts:** `%USERPROFILE%\Downloads\Luca-Dog-World-v0.15.1-KIMI-MOUNTAINS\v0151_mountain_pass.png`; `v0151_chase_camera.png`.
- **Known limitations:** Easter-egg discovery is session-scoped in this milestone. Physical Android terrain driving/collection performance is not yet claimed. Macro terrain supplements ENG-003 rather than replacing the bounded editable voxel slice.
- **Status:** PASS


---

## ENG-009 — Continuous terrain replacement + camera collision + egg expansion

- **Date:** 2026-10-05
- **Branch / base:** `feat/v0.15.2-continuous-terrain`, based on verified v0.15.1 checkpoint `5372a29d3bfb5a121b944be54db623e7028c8577`.
- **Player-facing problem:** Physical Android screenshots showed the v0.15.1 mountains as separate smooth wedges layered over the legacy flat world; hard seams/cliffs, an under-world/cyan camera state, and chase-camera terrain intersection remained visible.
- **Goal:** Replace the visible flat slab + terrain-patch stack with one deterministic world surface while preserving ENG-003, ENG-007, roads, sandbox landmarks, Kimi seed authority, and dual-platform export.
- **Implementation:** `MacroTerrain.gd` now builds one 80x80-cell continuous ArrayMesh/trimesh world surface from Kimi deterministic fBm plus regional NorthMountainPass, WestRidge, and SouthValley shaping. Main roads, diagonal roads, sandbox, skate area, plaza, world boundary, and the ENG-003 voxel slice receive broad smooth clearances. Legacy `WorldGround` is collision-only and lowered as a fail-safe instead of rendering a second flat world.
- **Vehicle camera:** CHASE now lives on `ChaseSpringArm` with collision mask/margin and right-side/mobile orbit input. DRIVER, CHASE, HOOD, OVERHEAD remain distinct.
- **Recovery:** Player under-world threshold tightened to -1.25 m; buggy recovery to -2 m. Runtime acceptance explicitly forces the player below terrain and requires immediate recovery.
- **Eggs:** Egg hunt expanded from 12 to 24 physical fried-egg pickups; pickup scale/collision reduced so discoveries are less visually oversized.
- **Visual tuning:** Reduced ambient/sun/fog washout so terrain surface color and relief remain readable on GL Compatibility/mobile-style rendering.
- **Acceptance:** 28/28 Python tests PASS. Live Godot runtime PASS proves: one continuous visible/collidable terrain owner; legacy flat ground collision-only; north-pass relief; south-valley relief; no cliff-step road shoulder; 24 eggs + collection; four camera modes; spring-arm chase + orbit; under-world recovery; prior sandbox/companion/vehicle gates.
- **Visual evidence:** Non-headless GTX 1650 captures `v0152_north_pass.png`, `v0152_west_ridge.png`, `v0152_south_valley.png`, `v0152_chase_springarm.png` show continuous blended landforms with no v0.15.1 vertical patch walls or giant rendered flat slab.
- **Preserved systems:** ENG-003 Voxel Tools editable mountain/cave slice remains active and is explicitly flattened out of macro terrain overlap. ENG-007 Quarry Ridge remains intact.
- **Known limit:** Physical Android v0.15.2 FPS and touch/terrain playtest remains pending until the exported APK is installed on-device.
- **Status:** PASS — release candidate pending exact-commit exports.


---

## ENG-010 — v0.16 world systems: physical buggy, stable companion, damageable NPCs, content/maps

- **Date:** 2026-10-05
- **Branch / base:** `feat/v0.16-world-systems`, based on verified v0.15.2 checkpoint `c07e92f32840872ca2293316d84658888642cc02`.
- **Physical-playtest input:** Android screenshots showed the buggy still gliding/floating, Luca orbiting arbitrarily, capsule/pill NPC bodies, no NPC damage, and no scalable authoring surface for items/tools/maps.
- **Vehicle repair:** `Buggy.gd` is now `VehicleBody3D` with four `VehicleWheel3D` contacts, front steering, four-wheel traction, suspension travel/stiffness/damping, tire friction, rigid-body pitch/roll, SpringArm chase camera, and NPC impact damage. Measured acceptance: 4/4 wheel contacts; idle speed ~0.00005 m/s; visual-forward displacement +11.49 m over the drive probe; post-throttle coast speed ~0.037 m/s after 1.5 s.
- **Companion repair:** Luca's formation anchor is derived from player translation rather than camera/player yaw. Camera-only rotation leaves the anchor fixed; translation updates it. Arrival braking and obstacle sidestep are active. Runtime gate also requires Luca to settle with <0.65 m cumulative travel over the final stationary sample.
- **NPCs:** NPCs now have 100 HP, shared `take_damage()` interface, knockback, death state, impact damage, and named bilateral anatomy: pelvis, torso, head, upper/lower arms, hands, legs, and feet.
- **Tool/content layer:** Added validated v0.16 catalogs for items, tools, recipes, and maps plus `ContentRegistry.gd`. Player tool execution consumes catalog action/range/damage/knockback. Field Hammer is the first damage tool and deals 25 HP per hit.
- **Map layer:** Runtime MAP selector exposes Luca's Field (6060), Red Pine Highlands (7719), and Quarry Basin (3184). Each profile controls seed, terrain scale, spawn, sky, and fog. Map seed propagates into Kimi generation and ENG-003's voxel generator.
- **Persistence isolation:** ENG-003 v0.16 saves use `user://v016_terrain_slice_<seed>.json`; saved seed is validated on load. The legacy v0.13 save path/schema is not mutated.
- **Authoring:** `engineering/CONTENT_AUTHORING_v016.md` documents item/tool/recipe/map schemas and the no-silent-schema-mutation rule.
- **Static verification:** 35/35 Python tests PASS.
- **Legacy runtime verification:** `runtime_playability.gd` PASS preserves continuous terrain, 24 eggs, mobile controls, cameras, spawning, ENG-003, under-world recovery, and prior gameplay contracts.
- **v0.16 runtime verification:** PASS proves valid content registry, hammer damage 100→75 HP, anatomical NPC body, no Luca orbit on camera rotation, Luca stationary settling, 4-wheel rest contact, traction drive, coast stop, vehicle-impact NPC damage, map-specific seed/persistence, and materially different alternate-map terrain.
- **Visual review:** GTX 1650 captures verify anatomical NPC silhouettes, map selector UI, Red Pine Highlands world profile, and physical buggy placement on terrain.
- **Known limitation:** v0.16 establishes data-driven content authoring and runtime map selection, not a full in-game visual item/tool/map editor. Physical Android v0.16 performance/touch playtest remains pending.
- **Status:** release candidate pending exact-commit dual-platform export.

---

## ENG-011 — Spiral Field v0.2 Android recording repair pass

- **Date:** 2026-10-08
- **Branch / base:** `newgame/spiral-field-v0.2-experience`, base HEAD `95f436101f129fdd5ffe7fd4ac0203b6b3259d70`, dirty candidate state.
- **Evidence:** Frame review of `20261008-1155-33.0674158.mp4` (160.6 s) and `20261008-1200-49.4056543.mp4` (143.0 s), both 1920×1032 at 30 FPS. Full timecoded assessment and reproduction steps are in `engineering/PLAYTEST_REVIEW_2026-10-08.md`.
- **Observed failures:** Android touch controls absent for both complete recordings; DRIVER camera rendered from inside the buggy cab and left a large blue obstruction; large Spiral torus geometry engulfed the first-person view at interaction distance; actor/terrain close-up occlusion remains observable but requires a separate collision/presentation design or device-state reproduction.
- **Invariant:** Preserve four vehicle cameras, encounter ray/verbs, save schema, deterministic terrain, map transitions, NPC collision policy, and desktop/debug HUD separation.
- **Falsifiers:** Static contracts require Android/iOS/mobile platform recognition and a 7.5 m Spiral stand-off; live runtime requires DRIVER camera position above/ahead of the cab envelope; non-headless capture must show an unobstructed DRIVER viewport.
- **Implementation:** `HUD.gd` recognizes authoritative Android/iOS export tags with the generic mobile tag as fallback. `Buggy.gd` moves the driver eye to `(-0.58, 2.42, -0.72)`. Spiral landmark collision radius increases from 5.5 m to 7.5 m while retaining the 9.5 m interaction ray. The release script validates the pinned JDK 17 directly and bypasses only `apkanalyzer.bat`'s broken `findstr` wrapper check.
- **Automated verification:** 46/46 Python contracts PASS; Godot 4.7.2 import PASS; Kimi deterministic acceptance PASS; `runtime_playability.gd` PASS including new cab-clearance gate; `v016_systems_acceptance.gd` PASS; `spiral_field_acceptance.gd` PASS; exported Windows TerrainSlice/VoxelTool probe PASS.
- **Visual verification:** Non-headless OpenGL 3.3 render on NVIDIA GTX 1650 saved `dist/verification/driver-camera.png`; inspected frame shows no buggy chassis/hood occluding the DRIVER view.
- **Release verification:** `BUILD_SPIRAL_FIELD.ps1` returned RC=0. Android APK signature schemes v2/v3 verify. Manifest is `com.onekawaii.spiralfield`, versionCode 2, versionName 0.2.0. APK contains Voxel Tools libraries for arm64-v8a and x86_64.
- **Artifacts:** Windows EXE `dist/windows/Spiral-Field-v0.2.0-windows.exe`, SHA-256 `e1aa04cdcfe8f2dd60420c9ccecba8beb52f43e3969ea8855219a2a46fabc836`; Android APK `dist/android/Spiral-Field-v0.2.0-android.apk`, SHA-256 `d30f5d74493ea5fa38c80825352cdc630aa4af4097abb41a42f51e1d8309892a`; receipt `dist/RELEASE_RECEIPT_Spiral-Field-v0.2.0.json`; build log `dist/full-build-latest.log`.
- **Demolition / blockers:** Android Debug Bridge sees only `emulator-5554 offline`; APK install, Android runtime input verification, physical-device performance, and repaired on-device screenshots are therefore not claimed. Recording audio was not transcribed because the local transcription API credential is absent. Close-up non-blocking actors and ambiguous steep-terrain occlusion remain documented, unchanged limitations.
- **Status:** PARTIAL — desktop/runtime/export/signature gates pass; physical Android acceptance remains blocked by the offline device.

## ENG-012 — full-map voxel terrain and equipped/damage presentation development pass

- **Date / exact base:** 2026-10-08, `feat/voxel-world-presentation`, base `1d564e1c57634f01fc2282e35e351307fbadcf04`; Godot 4.7.2 / Voxel Tools 1.7 lock unchanged. Development checkpoint, not main/release promotion.
- **Invariant / falsifiers:** ordinary launch uses editable voxel ground throughout 960m x 960m; mining changes collision/resources/save; equipped tool identity is visible; actual Player USE damages NPC/car rather than entering the car; remote actors retain collision support. Tests reject wrong material/icon/model, unchanged health/collision, lost save replay, traction/impact regressions and failed one-metre stepping.
- **Implementation:** world generator v2 with original quarry/caves preserved; immutable sampled height grid; visual-only far LOD; collision-only remote-actor viewers; one-metre player step; version-isolated old-save copy and coalesced writes; eight tool icons/hand models; bounded hit/wound/scuff feedback; car health/hood deformation/contact-impulse damage; indexed continuous Spirals and recognizable grounded cat. Six pinned CC0 object-specific PBR sources, eighteen maps imported at 512px/mipmapped/VRAM-compressed; provenance/hashes preserved.
- **DC receipt:** connected LAPTOP-AETIRLES `ae4b6eeb-1f82-492b-8c62-b2d8273a3762` confirmed real repo HEAD, created branch, acquired assets and ran real Godot render/physics checks. No project mirror reference files edited; old release EXE/APK untouched.
- **Tests:** 46 Python checks; world mining/removed collision/pickup/craft/place/step/distant support/disk+reconstructed replay; real hammer USE plus forced-mobile steering; v016 driving/braking/NPC impacts/map profiles; Spiral pressure/verbs/save reload; legacy fallback playability. Exact commands, paths, limitations and ownership are in `VOXEL_PRESENTATION_PASS_2026-10-08.md`. Physical wall impact measured car HP 200 -> 195.876771262213. Sampled static memory 118,586,750 bytes is not peak or Android evidence.
- **Demander-driven repairs:** corrected initially embedded car marks, floating cat, oversized held tool, opt-in terrain, remote-actor streaming, weak direct-write tests and post-solver impact velocity. Final qualification requires revised frame inspection and exported candidate gates.
- **Save safety incident:** the pre-existing Spiral test initially deleted/wrote normal Spiral save paths and left test progression. Subsequent tests use unique isolated override paths. Prior normal save not recoverable from this run; no silent reset. This is explicitly disclosed, not claimed preserved.
- **Status:** PARTIAL development checkpoint. Original videos were systematically sampled, not literally every-frame reviewed. Full-map voxel terrain does not make buildings/trees/entities voxel-destructible; road skins, stylized fur, unsaved actor injury, crash-safe saves and stress/performance limitations remain. Android lists only `emulator-5554 offline`. Export candidate hashes/receipts will be recorded separately after a clean checkpoint.
