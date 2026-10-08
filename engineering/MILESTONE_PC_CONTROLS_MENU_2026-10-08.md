# M-PC-03 — PC input, vehicle views and session menu

Status: scoped PC candidate accepted by Demander; not a full release.
Android device, art/terrain stress and exhaustive recording review remain PARTIAL.
Base branch
`feat/spiral-lantern-hotbar-terrain-20261008`, clean HEAD
`93b71e9d0c3db2db8cf3e79babb7bc5ed446a9de`; working branch
`feat/pc-controls-menu-milestone`. Godot 4.7.2, existing pinned Voxel Tools 1.7;
no engine/plugin/dependency upgrade. Earlier candidates are immutable rollback artifacts.

## Player-facing requirements / acceptance

- Captured left mouse press invokes exactly one equipped/contextual action;
  release and keyboard echo do not repeat it. Uncaptured click only recaptures.
- E remains the alternate interaction/vehicle-exit key; driving LMB never ejects.
- R/F5 cycle DRIVER, CHASE, HOOD, OVERHEAD; PC and mobile show VIEW and EXIT.
- Original block-button title, pause and options screens follow familiar
  single-player sandbox navigation without copying Minecraft art/branding.
- Escape closes a gameplay panel first, otherwise pauses/resumes. Pause stops
  simulation and exposes the pointer. Resume-button click cannot become tool use.
- Inventory/map/encounter panels release pointer and block world controls; these
  panels do not pause the continuing encounter simulation. Numbered encounter
  choices retain precedence over hotbar selection. Wheel/1–9/0 select hotbar.
- Options control actual sensitivity, master volume and fullscreen; settings
  are session-only in this pass. No fictitious multiplayer/world-slot options.
- A persistent PC controls label identifies noclip/driving, and MENU gives
  touch users an entry point without requiring Escape.
- Save/return-to-title flushes existing terrain/inventory and Spiral schemas.
  It retains the loaded session; continuing does not reset/reload. Existing
  schemas do NOT persist player position, props, NPC/car damage or camera mode.
- Mining drops become compact object-textured cubes, merge like-material nearby
  drops, and cap at 64 physics bodies without resource loss (overflow credited).
  Drops escaping below -20 credit inventory rather than silently disappearing.

## Ownership / risk / rollback

Player owns gameplay input and the blocked gate. HUD owns contextual panel
visibility/cursor synchronization. SessionMenu owns tree pause/title/options;
Game delegates flush to existing persistence owners. No save-schema migration.
Pause/menu processing is bounded and remains live while world processing stops.
Tests use unique terrain and Spiral save namespaces, never normal saves.
Rollback is the clean base commit and unchanged prior candidate folders.

## Falsifiers

Actual input-event dispatch must change target HP on one LMB; GUI clicks and
paused input must not. Throttled car and moving NPC must freeze during pause.
All four camera identities must be current after wrap/pause/resume. Save failures
must prevent return/quit. Resource-count conservation must hold under >64 drops.
Rendered screenshots must show menu, inventory and PC vehicle controls on-screen.
Exact exported Windows artifact must exercise the same probe after commit.

## Recording review

See `PC_RECORDING_BUG_REVIEW_2026-10-08.md`. Observable vs code-confirmed vs
unproven hypotheses stay separate. Current review is systematic five-second
contact sheets plus targeted frames, not every encoded frame.

## Exact checkpoint and artifacts

Game source: `766ae884df7a5e499d3594d0d9a007d808e29568`, clean at export on
`feat/pc-controls-menu-milestone`. Implementation checkpoint `d0e75f2` preceded
the stronger sensitivity/contract qualification. Recommend only final `766ae88`
candidate below. No merge, push or main/release promotion.

Output: `C:/Users/jmgar/Downloads/SpiralFieldGame/dist/pc-controls-766ae88/`.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| SpiralField-PC-M03.exe | 107624784 | a2b6086a6ca84856625d65764d1d09b36cb71443b543dee46a5b08f620043456 |
| SpiralField-PC-M03-766ae88.zip | 43408205 | 03c75ff4b0af07b3c0247edb7659780a82c038ec0dc027a8d9da9241e7659330 |
| SpiralField-M03.apk | 79686678 | c0f44befa4258e3978060b7b7a8df10daf0b4baaca1e8a52652608c6d60cc806 |
| libvoxel.windows.editor.x86_64.dll | 11337216 | e7191869989607805660de8f54c3aa2ab2e3ab08902bdd6976ac8aa6b3fe07ad |

Extract ZIP completely; run EXE with its adjacent DLL. Console wrapper/README
included. APK is debug `com.onekawaii.spiralfield`, signature v2/v3 verified,
one signer. Existing package/file versions remain 0.2.0 while inherited HUD says
v0.2.1; M-PC-03 + hash identifies this candidate, not the display label alone.

## Commands / results

Working directory: `C:/Users/jmgar/Downloads/SpiralFieldGame`.
`G` denotes pinned executable
`C:/Users/jmgar/.luca_toolchain/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.
All tests/export probes use unique terrain/story QA save paths; normal saves and
synced project sources were not reset or edited.

- `python -m unittest discover -s tests -p 'test_*.py'`: 46/46 PASS.
- `python -c "from tools import verify; verify.check_clean_tree(); verify.check_project_contract(); verify.check_boundary_contract(); verify.check_sandbox_contract(); verify.run_godot()"`: static contracts/import/parse PASS. First concurrent editor attempt failed native DLL hot-copy; isolated retry PASS. No library deletion/toolchain changes.
- `G --path . --script tests/pc_controls_menu_acceptance.gd --log-file dist/pc-controls-766ae88/source-menu-runtime.log`: DC39024 RC0, 20.91s, ALL PC INPUT MENU GATES PASSED; `source-captures/`.
- `G --headless --path . --export-debug 'Windows Desktop' dist/pc-controls-766ae88/SpiralField-PC-M03.exe --log-file dist/pc-controls-766ae88/windows-export.log`; then Android preset/output `SpiralField-M03.apk`, `android-export.log`: DC21520 combined RC0, 39.79s; no error markers in final export logs. JDK17/SDK36 existing pins unchanged.
- Exported `SpiralField-PC-M03.console.exe --log-file <output>/windows-runtime.log`, `SPIRAL_SKIP_TITLE=1`, `SPIRAL_PC_MENU_PROBE=1`, unique QA saves, `SPIRAL_PC_CAPTURE_DIR=<output>/export-captures`: DC18388 RC0, 19.93s, 39 PASS checks including actual LMB hit, GUI isolation, four current cameras/chase sensitivity, pause, failed-save refusal/current JSON payload, 80-resource conservation/64-body cap, escaped-drop credit and desktop-emulated touch GUI/joystick.
- Same EXE with `SPIRAL_TITLE_STARTUP_PROBE=1`, no script/title skip/menu probe, unique saves, `SPIRAL_PC_CAPTURE_DIR=<output>/startup-captures`, `--quit-after 600 --log-file <output>/windows-title-startup.log`: DC5572 RC0, 13.86s, ORDINARY TITLE STARTUP PASSED.
- `G --headless --path . --script tests/world_voxel_acceptance.gd`, then `tests/v016_systems_acceptance.gd`, then `tests/spiral_field_acceptance.gd`, logs under final output: DC22816 sequential RC0, 108.04s. Mined air/placed blocks/collision/inventory reconstructed; wheel contact/traction/braking/NPC impact/map isolation; Spiral pressure/context/save reload all passed.
- Headless `tests/hotbar_lantern_acceptance.gd`: RC0, ALL LANTERN + HOTBAR + TERRAIN VISIBILITY GATES PASSED on implementation pass; affected lighting/terrain implementation unchanged afterward.
- JDK17 `java -jar <SDK>/build-tools/36.0.0/lib/apksigner.jar verify --verbose <output>/SpiralField-M03.apk`: v2/v3, one signer PASS. ApkAnalyzer application-id: `com.onekawaii.spiralfield`.
- SDK `adb devices`: only `emulator-5554 offline`. No Android install/input/frame-time/memory/thermal acceptance.

Expected save-write ERROR in menu logs is explicitly enclosed by EXPECTED SAVE
FAILURE PROBE markers and proves refusal to leave. Headless input experiment
`dist/pc-controls-d0e75f2/headless-menu.log` returned RC1; NOT claimed passed.
Separate headless pointer diagnostic reports requested captured=2, actual=0.
Rendered source and exported game qualify mouse/touch routing instead.

Earlier parse inference and GUI-layout probe races were repaired; no behavior
assertions removed. Static signature now requires sensitivity routing; stale
baseline FIELD TRANSITIONS marker now checks actual WORLD MAP & TRANSITIONS and
real map methods. Final changes/checkpoints and failed attempts are retained.

## Independent disposition / remaining work

Demander independently inspected clean final source, exported hashes/logs and
pause/car/inventory/startup images: scoped M-PC-03 controls/menu/drop candidate
accepted, contingent on regression receipts now satisfied. No scoped blocker
established. Held tool can appear behind dark title overlay (cosmetic).

PC03-07/09/10 lighting/art/grounded excavation/LOD concerns, negative-terrain car
recovery qualification, physical Android and every-frame review remain open.
No whole-world object voxelization or realistic animal remodel claimed. Settings
are session-only. Existing non-atomic save schemas exclude player/entities.
Prior save incident remains disclosed in VOXEL_PRESENTATION_PASS report.
Old release EXE/APK hashes reconfirmed unchanged; no synced sources edited.
