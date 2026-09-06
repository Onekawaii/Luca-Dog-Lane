# Next Upgrade Report — Strawberry Omen Module Layer

## Build Result

Integrated The Strawberry Omen as a clean campaign-module extension while preserving the existing Hive-Lattice Bard entrypoint and Chapter 1 content.

`Hive-Lattice-Next-upgrade.zip` was not present in the workspace during this pass. The already-present Strawberry Omen proposal files were treated as the reference implementation and adapted in place rather than copied wholesale.

## Major Changes

- Removed generated `__pycache__` folders and temporary bundle clutter from the packaged repo.
- Restored the advanced engine files from the backup engine into `engine/`.
- Set `main.py` to the enhanced console runner.
- Added `engine/module_runtime.py`, a generic JSON campaign module runtime.
- Added `play_strawberry.py`, a playable Act I vertical-slice runner.
- Added `campaigns/strawberry_omen/` with book source, manifest, runtime JSON, placeholder assets, and a v0 battlemap.
- Added `tools/validate_campaign_module.py`.
- Added module regression tests.
- **EXPANDED**: Added Act II: The Fridge of Forgotten Things with Moldric mini-boss, Ancient Mayonnaise relic, and the Lunch Thief Goblins side quest.

## Integration Fixes Applied

- Added explicit Wetberry disposition flags for seen, touched, ignored, and reported states.
- Made the First Memo / Fridge of Forgotten Things unlock hook reachable from the starting scene.
- Fixed `CampaignModule.choose()` so `next_scene` transitions update the active location and apply scene entry flags.
- Tightened `tools/validate_campaign_module.py` to validate required files, manifest file references, node scene references, NPC locations, item assets, and random-table item references.
- Fixed the Strawberry runner's Windows console output by replacing the emoji title with ASCII text.

## Act II: The Fridge of Forgotten Things

**Implementation Summary:**

Added complete Act II expansion with 5 fridge locations (door_shelf, leftover_marshes, yogurt_catacombs, back_corner), 4 Act II encounters, 1 mini-boss (Moldric), 1 relic (Ancient Mayonnaise), 1 quest (Help Moldric reclaim stolen leftovers), and 5 state flags.

**New Content:**
- 4 fridge locations: door_shelf, leftover_marshes, yogurt_catacombs, back_corner
- 4 Act II encounters: fridge_intro, back_corner_boss, leftover_marshes, yogurt_catacombs
- 1 mini-boss: Moldric, Duke of the Back Shelf
- 1 new relic: Ancient Mayonnaise
- 1 quest: Help Moldric Reclaim Stolen Leftovers
- 5 state flags: entered_fridge, met_moldric, lunch_thief_confronted, ancient_mayonnaise_obtained, act2_complete
- 2 new random tables: act2.fridge_weird_events, act2.moldric_quotes

**Quest Path:**
Players must first complete Act I to unlock the Fridge, then navigate to Moldric's Back Corner. They can choose between: (1) help Moldric reclaim stolen leftovers, (2) confront Lunch Thief Goblins, or (3) walk away. The peaceful path involves helping Moldric, while the direct path involves defeating the goblins or Yogurt Cultist.

**Combatless Resolution:**
The "Help Moldric Reclaim Leftovers" path provides a non-combat resolution where players work with Moldric to recover stolen food, avoiding combat entirely while still achieving the quest objective.

## Validation

```text
python tools/content_lint.py
python tools/validate_campaign_module.py
python -m unittest discover -s tests
```

All pass.

## Design Decision

The PDF is intentionally not the source of truth. The campaign book is Markdown. The active game is JSON. The PDF should be generated later from the book/data layer after the module stabilizes.

## Next Sprint

1. Add map-node navigation to `play_strawberry.py`.
2. Add save/load for `ModuleState`.
3. Expand Act II with the Yogurt Catacombs and other side quests.
4. Add a simple GUI or local web UI for map + scene + choices.
5. Generate final character/item art into the existing asset slots.

---

## Upgrade: Act V — Department of Adjudication (v0.5.0-act5 -> v0.5.1-act5-complete)

**Status: COMPLETE, not planned.** Acts I-IV are untouched; Act V is reached via an additive-only choice on the Act IV completion scene.

### What shipped
- 5 rooms, 3 NPCs, 3 items, 6 branching scenes under `campaigns/strawberry_omen/`, all schema-validated.
- New quest `quest.act5.face_the_department` in `game/quests.json`, 5 objectives, validated `starts_at`/item references.
- Renderer Milestone C: `engine/render_bridge.py` maps live `ModuleState` stats into the frozen `ArenaState`/`RenderParams` contract for the hearing-arena scene. This is the first time the ring renderer contract (previously a standalone harness) has been wired into actual gameplay.
- Full packaged visual coverage: generated PNG art (matching the repo's existing `assets/generated/` placeholder-card convention) for every Act V room, NPC, and item — no bare `.placeholder.md`-only coverage remains for Act V.
- Web UI: HUD progression tracker, sidebar lore fragments, and NPC sprite mapping all extended for Act V; new `/api/arena/render` route.
- Renderer dependency (`torch`) made genuinely optional: split into `requirements.txt` (core, Termux-safe) and `requirements-renderer.txt` (optional). Missing-torch path returns HTTP 503, verified by simulating a torch-free import.
- Two real `.gitignore` bugs found and fixed via cold-archive verification (not assumed): one had left the entire Bard content track and ~27 pre-existing assets untracked; the other had left 13 required generated PNGs untracked. Both backfilled.
- `BUILD_PROVENANCE.json` added, tracked, regenerated per release.

### Test count
- Before this upgrade: 264 (original baseline)
- After v0.5.0-act5: 281
- After v0.5.1-act5-complete: see `BUILD_PROVENANCE.json` / `STATUS.md` for the exact current count, verified from a cold `git archive` extraction, not just the working tree.
