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
