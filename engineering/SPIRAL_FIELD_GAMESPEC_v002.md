# SPIRAL FIELD v0.2 — PLAYTEST-DRIVEN EXPERIENCE REPAIR

## Baseline
Donor substrate: Luca Dog World v0.16 world systems.
Rollback: Spiral Field v0.1 checkpoint f15ef7683ff54e7d3ff919c0335c45f2a5401c25.

This milestone is driven by the physical Windows playtest evidence from 2026-10-07. The v0.1 runtime was functional, but it still exposed the donor sandbox as the game and the verifier failed to cover a player-visible voxel failure.

## Player-facing requirements

### Identity
- Player-facing map names are Spiral Field names, not Luca donor names.
- Desktop does not display mobile touch controls.
- Developer SPAWN/NOCLIP are hidden by default and gated behind F3.
- Debug inventory telemetry is hidden during ordinary play.
- Windows release export must not present as a DEBUG build.

### Encounters
- ACT/MERCY are not tool-belt modes.
- Looking at a Spiral encounter and pressing USE/E opens contextual encounter choices.
- Tabby'tulhu: TALK / PET / FEED / MERCY.
- Witnessing: BEHOLD / AVERT / TOUCH / MERCY.
- Wailing: ANSWER / LISTEN / HUSH / MERCY.
- Choices mutate persistent authoritative state.

### World readability
- Both Twin Spirals have distant visible beacons.
- HUD gives distance guidance to Witnessing and Wailing.
- Tabby'tulhu has readable cat anatomy plus eldritch appendages rather than a two-sphere placeholder.
- Spiral pressure visibly changes sky, fog, ambient light, and sun.
- Corruption alone cannot report INFECTED while both Spiral resonance values are zero.

### Persistence
Save contract is versioned to schema v2 at:
user://spiral_field_state_v2.json

v1 state is migrated intentionally; the v1 path remains read-only compatibility input.

### Platform rendering
- Windows retains the GL Compatibility renderer used by the verified donor.
- Android uses Godot Mobile rendering on Vulkan.
- Android must emit `RENDERER_READY method=mobile driver=vulkan mobile=true` (or the exact runtime-equivalent driver name).
- Android verification rejects GLES3 `SceneShaderGLES3` / `CanvasShaderGLES3` link failures.

### Developer substrate
The Luca-derived Kimi terrain, MacroTerrain, Voxel Tools, companion behavior, vehicle physics, maps, crafting, spawning, and diagnostics remain available as donor systems. They are not all ordinary player UI.

## Verification requirements
1. 44 Python contracts pass.
2. Godot parses/imports cleanly.
3. Full donor playability regression passes.
4. v0.16 systems acceptance passes.
5. Spiral v0.2 runtime acceptance passes.
6. Player USE raycasts a Spiral and opens contextual encounter UI.
7. Actual TerrainSlice owns a live VoxelTool.
8. Exported Windows full game moves the real player/VoxelViewer into the voxel slice and completes a non-persistent voxel read/write/restore round-trip.
9. Windows release export succeeds.
10. Android APK exports, is signed, has the expected package/version, and packages Voxel Tools for arm64-v8a and x86_64.
11. SHA-256 receipts are generated.
12. Physical visual/phone approval remains pending until human playtest.

## Known limitation
The original Twin Spirals donor audio/model/glyph binaries from the uploaded archive are not present in the remote DC workspace. v0.2 continues to realize their motifs procedurally. This does not authorize fabricating those source assets.
