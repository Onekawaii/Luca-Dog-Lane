# Spiral Field v0.2 — Consolidated Android / PC playtest audit
Recorded: 2026-10-08
Source baseline: repair/spiral-player-systems-20261008, commit 63e4060
Repair branch: repair/spiral-pc-terrain-and-feedback-20261008
Evidence: 20 supplied Android screenshots, user's explicit Android complaints and 132.8-second PC screen capture (20261008-1724-19.9936190.mp4). No undocumented device behavior is assumed.

## Observed, reproducible, and distinguished from inference
1. PC 01:34–01:38: inventory lists FIELD HAMMER x0 despite the hammer being a tool equipped through the tool cycle. A UI semantics defect, not proof that hammer gameplay is missing.
2. PC 01:55–01:58: selecting stone and placing it consumes the one stone item; the held first-person place tool remains a brick regardless of selected material. Functional accounting passes; item representation is incorrect.
3. PC 02:00–02:12 and several Android screenshots: giant repeated triangular/block stair steps on ridges, dark voidlike seams, harsh near-to-far terrain handoff. In source, WorldVoxelGenerator builds 1-metre blocky voxels; MacroTerrain's former shader discarded the continuous macro mesh inside 60m. This is a presentation architecture problem, not merely a corrupt texture.
4. Android footage/screenshots: the dog/cat/NPCs exhibit minimal responsive behavior and visible rigid limb motion. Existing NPC chooses random straight-line direction. Existing limb swing alone is not full rigged gait or goal-oriented AI. Behavior severity needs observed motion traces.
5. User reports three maps look alike. Data maps_v016.json varies seed, scale, spawn and sky/fog; Game.gd builds the same road, workshop, quarry, NPC, and starter props. This is a world-authoring gap, even though a previous acceptance test proves different terrain seeds.
6. Android screenshots show mining excavations and abrupt holes. Block removal and collection are verified by the existing end-to-end tests, but visual and collision consistency should still be checked on phone.
7. User asks for block-discovery progression, richer crafting, persistent map exploration, map teleportation, universal noclip, clean saves, operator commands, ragdolls. The prior preview handles only portions of those requirements. No missing feature is represented as complete.

## Current targeted repairs
- Classify innate tool_item separately from consumable materials in inventory; hide unobtainable placeholder utility stock.
- Make PLACE first-person mesh, icon selection label and voxel item selection agree; use a grass, stone or brick-specific block.
- Expose V noclip toggle on PC even outside F3 developer UI.
- Restore continuous smooth far mesh instead of throwing it away around camera. A small 960 x 960 one-channel texture records every world-edited x/z column, so only the edited columns uncover the voxel scene. This is a limited visual bridge, not a smooth voxel mesher.
- Runtime screenshot experiment: default 12m reveal reduced distant checkers but still showed jagged slope; 9.5m reveal created a grey gap before streaming completed and was rejected. Edit-only texture cutout avoided the camera-wide grey gap but stepped near-voxel surfaces remain. See dist/verification/pc-terrain-*.

## Verification and rollback law
Keep 63e4060 and its published Android + Windows preview immutable. Only release the new branch after PC OpenGL render, all Godot acceptance scripts, 46 Python tests and new selection + mask test pass, plus Windows runtime and Android packaging/signature receipts. No physical Android playtest yet. Document incomplete features candidly.

## Remaining work outside this repair slice
- Genuine smooth editable near terrain with no meshing seams, camera fallbacks, mobile performance regression checks.
- Independent authored maps rather than re-tinting identical structure.
- NPC state machines and pathfinding, actual articulated bone/joint animation, animal schedules and companion interactions.
- Discoverable inventory unlock ledger, deliberate persistence version upgrade, real crafting progression and better item UI on both resolutions.
- Typed operator console, time simulation, map-select teleport, streaming safe landing and recover.
- Full ragdoll system and deterministic cleanup of prefabs vs player-created instances.
