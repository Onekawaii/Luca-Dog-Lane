# Dungeon Crawler Core Contract v0.1

Defines the required anatomy for each playable dungeon/act in the Hive Lattice
campaign module system. Derived from the proven Act IV "Fridge Labyrinth"
implementation.

---

## 1. Dungeon Identity

Every act must declare a unique dungeon identity.

| Field                | Act IV Value                                  |
|----------------------|-----------------------------------------------|
| act id               | `4`                                           |
| dungeon id           | `location.fridge_labyrinth`                   |
| display name         | The Fridge Labyrinth of Forgotten Leftovers   |
| entry scene          | `scene.act4.labyrinth_entry`                  |
| completion scene     | `scene.act4.labyrinth_completion`             |
| completion flag      | `act4_complete`                               |

**Rules:**
- The entry scene must exist in `encounters.json`.
- The completion scene must exist in `encounters.json`.
- The completion flag must be declared in `campaign.json` `starting_flags`.
- The dungeon id must match a top-level location in `locations.json`.

---

## 2. Room Graph

Each dungeon must define a location namespace with a linear or branching node
graph. Every node is a sublocation within the dungeon.

| Node                                         | Locked By                    |
|----------------------------------------------|------------------------------|
| `location.fridge_labyrinth.entry`            | `act3_complete`              |
| `location.fridge_labyrinth.condiment_gate`   | `moldric_guiding`            |
| `location.fridge_labyrinth.leftover_catacombs` | `condiment_gate_opened`    |
| `location.fridge_labyrinth.freezer_shrine`   | `leftover_catacombs_crossed` |
| `location.fridge_labyrinth.casserole_throne` | `freezer_blessing_obtained`  |

**Rules:**
- Every node id must be globally unique.
- `locked_by_flag` must reference a valid flag from `campaign.json` or a flag
  set by a prior scene in the same act.
- Every node's `scene` reference (if present) must resolve to an encounter.
- No dangling location references: every node reachable from an encounter's
  `location` field must exist.

---

## 3. Scene Graph

Every act must define a closed scene graph with explicit resolution paths.

**Required Act IV scenes (7):**

| Scene                                | Type                | Role               |
|--------------------------------------|---------------------|--------------------|
| `scene.act4.labyrinth_entry`        | `npc_scene`         | Entry / orientation |
| `scene.act4.condiment_gate`         | `social_encounter`  | Gate puzzle         |
| `scene.act4.leftover_catacombs`     | `social_encounter`  | Progression room    |
| `scene.act4.freezer_shrine`         | `npc_scene`         | Item acquisition    |
| `scene.act4.casserole_throne`       | `boss_social_encounter` | Boss fight      |
| `scene.act4.casserole_throne_recovery` | `social_encounter` | Failure recovery  |
| `scene.act4.labyrinth_completion`   | `completion_encounter` | Act end          |

**Rules:**
- Every `next_scene` in a choice must resolve to an existing encounter id.
- Every scene's `location` must resolve to an existing location node.
- Blocked/failure/recovery scenes must be explicit (not just dead ends).
- The completion scene must set `act4_complete: true` via `on_enter_flags`.
- No scene may reference a next_scene outside its own act unless it is the
  act-transition scene (e.g., `proceed_to_act4` in Act III).

---

## 4. Items

Each act must define a key item, optional support items, and a completion
artifact.

| Item ID                          | Role                    | Act IV Source        |
|----------------------------------|-------------------------|----------------------|
| `item.condiment_sigil`          | Key item (gate pass)    | Condiment Guardian   |
| `item.freezer_blessing`         | Key item (boss shield)  | Freezer Shrine       |
| `item.casserole_lid_fragment`   | Completion artifact     | Casserole resolution |

**Rules:**
- Every item granted by a choice (`grants_items`) must exist in `items.json`.
- The completion artifact must be granted by the boss resolution scene.
- Inventory persistence: all items granted during the act must survive
  save/load (verified by existing save/load tests).
- Items may have `effects` referencing conditions that exist in
  `conditions.json`.

---

## 5. NPCs

Each act may define guide, gatekeeper, and boss NPCs.

| NPC ID                    | Role             | Act IV Location                              |
|---------------------------|------------------|----------------------------------------------|
| `npc.moldric_guide`      | Guide/companion  | `location.fridge_labyrinth.entry`            |
| `npc.condiment_guardian` | Gatekeeper       | `location.fridge_labyrinth.condiment_gate`   |
| `npc.sentient_casserole` | Boss/resolution  | `location.fridge_labyrinth.casserole_throne` |

**Rules:**
- Every NPC spawned by a choice (`spawns_npc`) must exist in `npcs.json`.
- Every NPC's `location` must reference a valid location node.
- NPCs may share placeholder assets (e.g., `assets/characters/moldric.placeholder.md`).

---

## 6. Route Model

Every act must support at least two resolution paths, with a failure/recovery
path for the boss encounter.

**Act IV routes:**

| Route          | Boss Choice ID            | Outcome Flag                        |
|----------------|---------------------------|-------------------------------------|
| Compassion     | `compassion_path`         | `casserole_resolved_compassion`     |
| Bureaucracy    | `bureaucracy_path`        | `casserole_resolved_bureaucracy`    |
| Ape            | `ape_path`                | `casserole_resolved_ape`            |
| Failure/recovery | `insult_casserole_path` | Recovery via `casserole_throne_recovery` |

**Rules:**
- Each route must grant the same completion artifact.
- Route flags must be declared in `campaign.json` `starting_flags`.
- Failure/recovery scenes must exist and offer a path back to completion.
- Future consequence hooks: route-specific flags (e.g., `casserole_resolved_ape`)
  should be declared even if not yet consumed by downstream content.

---

## 7. Assets

Each act must have visual assets declared in `visual_manifest.json` and
`generated_manifest.json`.

| Asset Type     | Act IV Count | Examples                                       |
|----------------|--------------|-------------------------------------------------|
| Room images    | 5            | `room.fridge_labyrinth.entry`, `.casserole_throne`, etc. |
| Item images    | 2            | `item.condiment_sigil`, `item.freezer_blessing` |
| NPC/token images | 3         | `token.moldric_guide`, `token.condiment_guardian`, `token.sentient_casserole` |
| Texture        | 1            | `texture.labyrinth_frost`                       |
| Map            | 1 (shared)   | `map.breakroom`                                 |

**Rules:**
- Every room node must have a corresponding `room.<node_suffix>` asset in
  `visual_manifest.json`.
- Every item granted by the act must have an `item.<item_suffix>` entry.
- Every NPC in the act must have a `token.<npc_suffix>` entry.
- `visual_manifest.json` entries must resolve to either a generated PNG
  (`generated_manifest.json`) or a valid placeholder file on disk.
- `generated_manifest.json` paths must exist on disk.

---

## 8. Save/Load Requirements

Every act's state must survive save/load round trips.

| Field                | Persistence Expectation                         |
|----------------------|--------------------------------------------------|
| current scene        | Must persist as `scene.act4.*` after Act IV      |
| current location     | Must persist as `location.fridge_labyrinth.*`    |
| flags                | All act flags must persist (11 Act IV flags)     |
| inventory            | All granted items must persist in inventory list  |
| visual metadata      | `get_visual_metadata()` must resolve after load   |

**Rules:**
- Save/load is tested by `test_act4_freeze_verification.py` (existing).
- A non-duplicative contract test may reference or re-verify a subset.

---

## 9. PWA Requirements

The web app must expose current dungeon state and all visual assets.

| Requirement                                   | Endpoint / Mechanism              |
|-----------------------------------------------|------------------------------------|
| State endpoint exposes current dungeon state   | `GET /api/state`                  |
| Room/map images resolve                        | `GET /api/assets/maps/...`, `/api/assets/rooms/...` |
| Help surface remains available                 | `showHelp()` in `strawberry.js`   |
| Mobile UI does not block choices               | Bottom bar buttons + choice cards |

**Rules:**
- `/api/state` must return `scene`, `choices`, `location`, `flags`, `stats`,
  `inventory`, `images.map`, and `images.room`.
- Room and map asset URLs must be reachable from the generated assets directory.
- The help button (❓) must be present in the bottom bar.
- No UI element may block the player from making a choice.

---

## 10. Required Tests for Every New Dungeon/Act

| Test Category                         | Tool / File                                  |
|---------------------------------------|----------------------------------------------|
| Content validation                    | `tools/content_lint.py`                      |
| Scene reference validation            | `tools/validate_campaign_module.py`          |
| Location reference validation         | `tools/validate_campaign_module.py`          |
| Item/NPC/quest reference validation   | `tools/validate_campaign_module.py`          |
| Asset manifest validation             | `tools/validate_visual_assets.py`            |
| Smoke path (act I through target act) | `tests/test_act3_smoke.py` (extend)          |
| Save/load round trip                  | `tests/test_act4_freeze_verification.py`     |
| PWA/API smoke                         | `tests/test_pwa_smoke.py`                    |
| Help surface non-regression           | `tests/test_help_surfaces.py`                |

**Rules:**
- All validation tools must pass with zero errors.
- The smoke path must complete without assertion failures.
- Save/load must preserve all act flags and inventory.
- A contract test (`tests/test_dungeon_crawler_contract.py`) provides a
  reusable checklist for verifying any act against this contract.

---

## Appendix: Act IV Verification Checklist

This checklist is the concrete instantiation of sections 1-10 for Act IV.
It is implemented in `tests/test_dungeon_crawler_contract.py`.

- [x] 5 Act IV locations exist
- [x] 7 Act IV scenes exist
- [x] All Act IV choice targets resolve
- [x] All Act IV scene locations resolve
- [x] 3 core Act IV items exist (sigil, blessing, lid fragment)
- [x] 3 Act IV NPCs exist (moldric_guide, condiment_guardian, sentient_casserole)
- [x] `quest.navigate_fridge_labyrinth` exists
- [x] Completion flag `act4_complete` exists in starting_flags
- [x] Completion artifact `item.casserole_lid_fragment` is granted
- [x] Generated visual assets resolve
- [x] Save/load round trip preserves Act IV state
- [x] PWA state endpoint exposes dungeon state
- [x] Help surface remains available
