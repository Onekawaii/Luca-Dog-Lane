# PC playthrough review — 2026-10-08

Milestone: M-PC-03. Authoritative inspected source baseline:
`93b71e9d0c3db2db8cf3e79babb7bc5ed446a9de` (clean).
Recording EXE version is visually v0.2.1; EXE SHA cannot be identified from video.
Do not equate that version label to a specific artifact/source commit.

## Evidence coverage

Local original files, never modified:

| ID | Filename | Duration | Video frames / dimensions |
| --- | --- | ---: | --- |
| A | 20261008-1925-44.9496145.mp4 | 176.5333 s | 5,296 / 1920×1032 / 30 fps |
| B | 20261008-1931-17.8499941.mp4 | 107.6333 s | 3,229 / 1920×1032 / 30 fps |
| C | 20261008-1936-25.3872233.mp4 | 117.966633 s | 3,539 / 1920×1032 / 30 fps |

Root: `C:/Users/jmgar/AppData/Local/Packages/Microsoft.ScreenSketch_8wekyb3d8bbwe/TempState/Recordings/`.
Timecodes below are clip-relative, not wall-clock. Reviewed systematic 5-second
contact sheets across each clip and targeted 1-second B01:15–01:26 car sequence,
plus full-resolution A01:50 excavation frame. Sheets are evidence indices, not
proof of every intervening event. No claim of literal review of all 12,064 frames,
audio transcription, click/key telemetry, or video-derived FPS profiling.
Receipts: `dist/pc-review-20261008/clip*-*.jpg`, `car-detail.jpg`, `mining-detail.jpg`.

## Findings and reproduction paths

### PC03-01 — Left-click never uses the selected tool (P1, code-confirmed + user report)

Video context: A00:00–00:25 hammer/grab/mine changes; C00:00–00:15 NPC and mining.
Recording does not expose which mouse button/key was pressed. User reports LMB
failure; source conclusively confirms Player `_unhandled_input` handles LMB only
by capturing the pointer. Only E calls use_tool. Reproduce: equip hammer, aim
at NPC within reach, capture pointer, click LMB: no action. Expected: one hit.
Repair: single press action, E alternate, no key-echo repetition, no GUI leaks.

### PC03-02 — No discoverable PC car view option (P1, observed + code-confirmed)

B01:15–01:18 and 01:21–01:24 enter driving: hotbar/held item disappear and toast
reads `Driving // VIEW switches camera`; no VIEW control appears. At 01:25–01:26
player exits and car becomes visible again. HUD explicitly hides VIEW on PC;
R already cycles four actual cameras. Reproduce: grab tool → E near car → drive.
Expected: persistent VIEW mode/control and actual shortcut, not an invisible label.
Repair: PC VIEW/EXIT, R and F5, four camera identities tested including wrap.

### PC03-03 — Escape is not a real pause; menu/world input ownership is absent (P1, code-confirmed)

UI context A02:30–02:35 map, B00:45 inventory, C01:15 and 01:25–01:30 encounters.
Video alone cannot prove world pause because no input telemetry is present.
Source has no SceneTree pause: Escape only changes mouse mode, while Player
continues polling WASD/Space. Map/inventory flips visibility without cursor release.
Reproduce: move/drive, Escape; open I/M while captured; attempt button navigation.
Expected: Escape session pause, menus own cursor, world cannot attack/look/move
through them. Repair: explicit session menu and HUD modal gate; GUI resume tested.

### PC03-04 — Context choices collide with equipment shortcuts (P2, observed design ambiguity)

A00:50–01:00 cat panel sits directly above hotbar; C01:15 and 01:25–01:30 Spiral
panel shows 1–4 while bottom hotbar also shows 1–4. Source intentionally routes
choices first, so this is not evidence that hotbar routing is broken. Player sees
two conflicting meanings. Reproduce: open encounter, press 1–4. Repair: disable
hotbar while panel is active and clarify menu ownership; contextual priority retained.

### PC03-05 — Oversized indistinguishable mining drops obscure excavation (P2, observed + code-confirmed)

A00:15–00:55 and 01:40–02:15; B00:25–00:50. Many pale balls fill mined cavities;
A01:50 full frame shows several occupying the aiming region. ResourcePickup
renders every material as the same 0.44 m grey sphere; every mine creates a body,
with no active-body cap/coalescing. Reproduce: mine many adjacent cells without
collecting drops. Expected: compact identifiable drops, bounded physics count,
no resource loss. Repair: 0.20 m material-textured cubes, same-material merging,
64-body cap with exact overflow credit. Performance benefit is not measured FPS.

### PC03-06 — Tool-use repeat is undocumented and can create rapid edits (P2, code-confirmed)

A/B rapidly expand cavities and resource counts; video cannot identify held E.
Baseline E handler does not reject keyboard echo. Reproduce: hold E with mine
equipped; OS repeat triggers action. Expected this pass: one action per press;
continuous hold mining is a separate deliberate mechanic, not keyboard-repeat timing.
Repair: reject E echo; LMB is press-driven, wheel quick access added.

### PC03-07 — Underground visibility is poor without lantern (P2, observed, partially mitigated)

A00:30–01:50 and B00:30–00:50 excavation faces become nearly black. A01:55–02:15
lantern turns on and visibly lights them; lamp already works. Reproduce: dig
below terrain, lantern off. Expected: discoverable lighting control, readable
terrain. New controls screen advertises L/slot8; no global brightness/art overhaul
or claim that all dark excavation is fixed. Darkness itself can be intended.

### PC03-08 — Noclip state insufficiently persistent; visual/collision symptoms ambiguous (P2)

B01:19 `NOCLIP ON`, 01:20 `NOCLIP OFF`; C01:10 `NOCLIP OFF`. Other portions show
view below terrain or suspended actors (A00:30+, C00:05–00:20). Without persistent
mode indication/input telemetry, those are not proof of collision failure. Source
noclip is toggled by V; HUD state button is hidden on standard PC. Repair: persistent
PC mode indicator and controls entry. Actor support and excavation stress remain
separate qualification; do not infer every apparent float as a physics bug.

### PC03-09 — Surface/voxel presentation changes abruptly around excavations (P2, observed; pending)

A00:25–00:50 and 01:35–01:50, B00:40–00:55, C00:10–00:20: hard flat boundaries,
dark interiors and disconnected-looking facets occur during excavation/noclip.
Source uses a smooth surface plus edited-column cutout and underground voxel
visibility switch. Reproduce under both grounded and explicit noclip camera paths.
Possible contributors: intended block cavities, camera inside geometry, view switch,
streaming. No unsupported claim of inverted normals or falling-through collision.
Needs targeted rendered grounded excavation/LOD stress qualification; not solved
by menu changes.

### PC03-10 — Objects/materials still do not meet realistic-world intent (P2, observed; pending)

A00:00–00:25 cat/Luca; B01:05–01:10 car; C00:00 NPC. Models remain stylized and
simple, roads/buildings/trees remain smooth non-voxel entities. New materials
improve surfaces, not topology or all-object voxelization. Ground drops addressed
this pass; full model/art/world conversion is a distinct unfinished milestone.

### PC03-11 — Damage not demonstrated in these PC clips (coverage gap)

C00:00 inspects NPC, then mines terrain nearby; C00:35–00:50 hammer view is away
from target. B car sequence drives/enters/exits. These do not establish a successful
attack with missing feedback or collision-damage failure. New LMB NPC health test
is required; prior feedback system must not be called broken solely from these clips.

### PC03-12 — Reset flow is easy to confuse with menu navigation (P2, usability)

A02:30 map displays `NEW WORLD (BACKUP)`, 02:35 `CONFIRM // RESET & BACKUP`, then
02:40 resources return to zero. Likely confirmed reset, not proof of spontaneous
inventory loss. Existing backup confirmation retained; title/pause contain no reset
action. Save/title preserves current session and explicitly documents persisted scope.

## Non-bugs / limits

A01:20 `Placement rejected // player overlap` is deliberate safety, not failed
placement proof. A02:45–02:50 grab and B00:00 release feedback show prop interaction
working. C01:25 purple sky/status change after Spiral choices is intended progression.
No measured stutter, memory leak or audio bug established. Separate code hypothesis:
car hardcoded recovery below -2.5 may conflict with legitimate mined negative terrain;
requires a reproducer before claiming fixed. No physical Android evidence from PC clips.

## Milestone disposition

Control/menu/drop repairs are undergoing exact-state runtime and Demander gates.
Final update: tested control/menu/drop scope accepted at game source `766ae884`;
exported Windows input, startup and regressions passed. Exact commands, artifact
hashes, failures retained and limits are in M-PC-03 milestone and BUILD_LEDGER.
Presentation/art/grounded-LOD stress findings remain named follow-ups, not silently
closed. Final gate receipts and artifact hashes belong in BUILD_LEDGER and M-PC-03.
