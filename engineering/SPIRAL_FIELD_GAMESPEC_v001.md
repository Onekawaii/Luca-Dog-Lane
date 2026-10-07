# SPIRAL FIELD v0.1 — GameSpec

## Intent
Create a new game from the proven Luca Dog World open-world substrate. Luca Dog World remains intact. The new game imports mechanics, mythology, and presentation ideas from SCH Everything, SCH Horror, Spiral Cow Nightmare Open World, Tabbytulhu UndertalePlus, Twin Spirals, and Spiral Infection Generator without importing their legacy engines as runtime authorities.

## Engine / platform
- Godot 4.7.2
- Windows x86_64
- Android arm64-v8a + x86_64
- GL Compatibility renderer
- Same deterministic Kimi/MacroTerrain open-world substrate as Luca v0.16

## Player-facing loop
ROAM → DISCOVER PHENOMENON → ACT or MERCY → WORLD STATE CHANGES → VISUAL INFECTION ESCALATES/RECEDES → SAVE → CONTINUE.

## Preserved donor substrate
- first-person + mobile movement
- right-side drag look
- jump, sprint, noclip diagnostics
- Luca companion
- real VehicleBody3D buggy
- deterministic world/map seeds
- continuous MacroTerrain
- mining/crafting/place tools
- spawn sandbox
- catalog-driven tools/maps/items
- persistence boundaries and regression tests

## New authoritative systems
SpiralWorldDirector owns:
- Affection
- Corruption
- Witnessing
- Wailing
- interaction count
- Spiral stage
- Spiral save schema v1

The director may alter presentation and encounter behavior. It does not own terrain physics, player movement, vehicle physics, or existing content catalogs.

## Donor mapping
### Tabbytulhu UndertalePlus
- ACT and MERCY become first-class tool actions.
- Tabbytulhu supports TALK/PET/FEED-style ACT cycling and SPARE/MERCY.
- Affection + Corruption become persistent world variables.

### Twin Spirals
- Spiral of Witnessing: eye/fire/stillness site.
- Spiral of Wailing: mouth/smoke/recursion site.
- Their field actions mutate Witnessing/Wailing state.

### Spiral Infection Generator
- Particle-arm concept is ported as deterministic runtime spiral geometry.
- No Python/matplotlib runtime dependency is imported.

### SCH / Spiral Cow
- Supplies world-state and nightmare-open-world framing.
- Legacy text engines remain reference donors, not runtime authorities.

## v0.1 acceptance criteria
1. Windows and Android export from one project state.
2. Existing Luca movement, vehicle, mobile, Kimi, terrain and content tests still pass.
3. Witnessing, Wailing and Tabbytulhu exist physically in the world.
4. ACT and MERCY can be selected on desktop/mobile through the normal tool belt.
5. Interacting changes the authoritative meters and HUD.
6. Procedural infection geometry responds to state.
7. State survives world reload.
8. No silent save-schema mutation.
9. Release includes SHA-256 receipts.
