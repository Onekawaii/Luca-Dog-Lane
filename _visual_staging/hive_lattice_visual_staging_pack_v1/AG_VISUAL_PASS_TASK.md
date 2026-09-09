# HIVE-LATTICE // FIRST REAL VISUAL PASS

## Baseline
The mobile control baseline is commit `3d01b4b`.
The corresponding Native Build and Android emulator boot both passed.

Do not modify:
- TouchLookZone.gd
- VirtualStick.gd
- FirstPersonPlayer movement/physics
- mobile control layout/ownership

unless a newly reproduced phone bug explicitly requires it.

## Mission
Use the staged visual assets in this pack to make the Breakroom read like an intentional game space without destabilizing the now-good controls.

## Phase 1 — Asset staging
Create:
`game_godot/assets/staging/borrowed_visuals/`

Preserve:
- source filenames
- provenance
- originals separately from derived/mobile-friendly variants

Do not replace campaign/save schemas.

## Phase 2 — First four visual targets
Prioritize exactly:
1. Wetberry
2. Keith
3. Breakroom fridge
4. Coffee maker

### Wetberry
- Keep existing physical interaction target/collision.
- Replace the plain white carton read with a visibly authored strawberry carton.
- Narration already says it is a white carton bearing red strawberry glyphs.
- Preserve containment behavior and progression.

### Keith
- Preserve actor root, collision, and interaction behavior.
- Replace capsule-only presentation with a readable janitor silhouette/material treatment.
- Keep phone visibility strong at medium distance.

### Fridge
- Preserve collision and interaction.
- Give it recognizable door/material hierarchy.
- Blood-scene material may only appear as a small maintenance/hazard decal, never whole-object gore texture.

### Coffee maker
- Preserve entanglement/interaction behavior.
- Make it visually legible as a coffee maker at first-person distance.
- Do not change quantum mechanics.

## Phase 3 — PDA/quantum visual language
Use Arkheo network/glyph assets conservatively for:
- PDA background watermark
- quantum diagnostic motif
- optional small anomaly indicator

Do not reduce text contrast or mobile readability.
Do not replace the green HUD system wholesale.

## Rare anomaly visual
The Frog of Endless Eons sigil may be used once as a hidden/rare environmental anomaly mark.
Do not repeat it as generic decoration.

## Small texture/icon assets
- `single_ape`: tiny icon/easter egg candidate
- `mash_core`: microtexture candidate
- `grains_arkheo_final`: strip/noise detail
- `test_flock`: tile/pattern candidate

## Hard exclusions
- No control refactor.
- No movement retuning.
- No schema changes.
- No story rewrites.
- No wholesale Corniverse theme transplant.
- No blood wallpaper.
- Prefer derived 512px assets over giant raw 1024px textures on Android where practical.

## Acceptance
1. Full native verifier passes.
2. Android APK builds.
3. Android emulator boot passes.
4. Movement/control behavior unchanged.
5. Wetberry, Keith, fridge, and coffee maker become visually distinguishable at phone resolution.
6. PDA remains readable.
7. Report exact files changed and provenance.

## Deliverable
Produce the next signed Android playtest APK and checksum.
