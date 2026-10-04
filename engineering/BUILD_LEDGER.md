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

## ENG-003 — Godot 4.7.2 export qualification

- **Date:** 2026-10-03
- **Branch / HEAD:** `feat/v0.13-world-foundation`
- **Goal:** Prove the 4.7.2 + Voxel Tools substrate exports and runs on Windows and Android before any main-world migration.
- **Observed evidence:** Editor/runtime and voxel mutation pass locally; Voxel Tools package contains Windows release x86_64 and Android release arm64/x86_64 binaries.
- **Invariant:** No v0.13 world code is promoted until exported native artifacts contain and load the extension.
- **Hypothesis:** Official Godot 4.7.2 export templates can package Voxel Tools 1.7 GDExtension for both targets without changing core game behavior.
- **Falsifier:** Missing export templates; missing extension library in package; Windows runtime load failure; Android package/signature failure; physical Android load failure.
- **Design decision:** Keep this as a separate qualification gate so local editor success cannot certify delivery success.
- **Files changed:** pending.
- **Commands executed:** pending.
- **Results:** pending.
- **Demolition:** pending.
- **Performance:** pending.
- **Artifacts:** pending.
- **Known limitations:** Godot 4.7.2 export templates have not yet been installed in this session.
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
