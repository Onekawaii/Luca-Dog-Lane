# Spiral Field — Android Terrain, Lantern & Quickbar Repair
Date: 2026-10-08
Input: Ten user-supplied Android screenshots from the previous build and reported gameplay feedback.
Parent: 6cbb664 (PC/Android playtest repair preview)
Branch: feat/spiral-lantern-hotbar-terrain-20261008

## Verified player-facing defects
- Overlapping macro terrain and voxel top surfaces caused severe stippled green/beige z-fighting on phone, including large abrupt patches along road borders. The previous per-edit mask only removed the macro face near user edits; all the other voxel faces still rendered on top of it.
- Digging underground gave no dedicated controllable portable light.
- Inventory forced players to press PLACE/SELECTED to equip terrain materials. This mixed crafting/storage with active equipment and cluttered playtime. No numbered equipment display was available.
- Some notifications could occupy the same screen region as future equipment UI.

## Repair
1. WorldVoxelGenerator remains unchanged and still owns voxel data/collision. Voxel material fragment visibility now obeys a shared edit-column texture: unedited blocks are hidden from the outdoor view; edited terrain and the authored quarry remain visible. If the active camera is below the macro terrain surface, all block faces render for underground navigation. No persistence-schema or generator-version change. Visual preview on PC no longer shows the repeating external ground stencil artifacts.
2. First-person lantern is a new catalog-driven starter tool, with an actual camera-carried OmniLight3D. Warm color 1.0/0.73/0.40; energy 4.8; range 20 m; attenuation 0.85. PC renders shadows; mobile disables light shadow maps for performance. The lamp stays on while mining until toggled. Slot 8 or L operates it.
3. Fixed ten-position bottom quickbar for keyboard 1..9 and 0 plus touch. Slots 1 GRAB, 2 LOOK, 3 MINE, 4 STONE, 5 GRASS, 6 BRICK, 7 HAMMER, 8 LANTERN, 9 CRAFT, 0 REMOVE. Counts read only from authoritative terrain inventory; highlighted slot reflects selected equipment. Q tool cycling is preserved. Tapping slot 8 again toggles lantern; selecting another tool keeps lantern enabled.
4. Inventory becomes FIELD SATCHEL: actual material count cards, enabled/disabled crafting recipes, return button; no PLACE buttons. HUD toasts moved to avoid hotbar overlap.

## Verification
- 46 Python tests (no new schema).
- tests/hotbar_lantern_acceptance.gd tests true 10 slots, PC keyboard, live button taps, material counts, persistent lamp state while mining, toggle, actual dynamic light object, inventory UI contracts and terrain shading mask.
- Existing tests updated to expect selection in the actual hotbar, not removed inventory control.
- tests/lantern_visual_capture.gd compares two **rendered** PC OpenGL frames in the authored quarry with light off/on. Off normalized central-region brightness 0.161775, on 0.206527, delta +0.044752 > 0.012 gate.
- PC visual review: dist/verification/pc-terrain-edits-only.png, field-satchel-pc.png, lantern-quarry-off.png, lantern-quarry-on.png.

## Limitations
- PC render acceptance does not establish Android hardware shader compatibility or speed; physical Android check required.
- Authoring of terrain voxel mesher remains blocky and will have steps underground. Smooth cave sculpting is separate.
- Macro visual ground and voxel collision can differ by fractions of a meter. Fully matching continuous collision/visual terrain is deferred.
- Lantern is a session light, not a persistent item in the save inventory. No new save schema was silently created.
- Moving to more authored regions or NPC upgrades is outside this repair pass.
