# HIVE-LATTICE // NATIVE GAME CLIENT ARCHITECTURE
**Codename:** GET IT OUT OF THE FUCKING BROWSER  
**Client:** Godot 4.3 Stable (Forward Plus / GL Compatibility)  
**Primary Directory:** `game_godot/`  
**Legacy Reference:** `hive_lattice/web_app/` (Preserved for debug/reference)  

---

## 1. Executive Summary & Paradigm Shift

Hive-Lattice has transitioned from an HTML/Flask web prototype into a **fully offline, standalone native 2D point-and-click adventure game** built on Godot 4.3.

```
OLD BROWSER MODEL:
Web Browser -> Flask Server -> Giant Choice List / Webpage Tabs -> Canvas pretending to be a game

NEW NATIVE MODEL:
Godot Native Application (Desktop / Mobile)
  ├── Illustrated World & YSort Depth
  ├── Grounded Characters (Foot Anchors)
  ├── Spatial Anchored Dialogue & Context Choices
  ├── Object-on-Object Inventory Interaction
  ├── Authoritative WorldState & ActionResolver
  └── Native Modals (Status, Journal, Pause/Save)
```

---

## 2. Core Architectural Subsystems

### A. Authoritative World State & Action Resolution
 Authoritative gameplay state is strictly held by `WorldState.gd` (`game_godot/scripts/runtime/WorldState.gd`), maintaining 1:1 schema parity with the Python `ModuleState` v3 specification:
- `campaign_id`, `current_scene`, `current_location`
- `flags`, `stats`, `inventory`, `log`
- `room_state` (spatial room memory)
- `npc_memory` (interpersonal relationship standings)
- `conditions` (turn-based status effects)
- `actor_dynamics` (character emotional/pressure state)

`ActionResolver.gd` (`game_godot/scripts/runtime/ActionResolver.gd`) processes player choices, declarative requirements (`all`, `any`, `not`, `flags`, `not_flags`, `item`, `items_all`, `stats`, `npc`, `room`), applies state deltas, resolves rule tables, and manages deterministic table rolls.

### B. Event Bus Decoupling (`EventBus.gd`)
All subsystems communicate through signals on the `EventBus` autoload:
- `action_requested(action_data)`
- `world_state_changed(delta_data)`
- `dialogue_started(actor_id, speaker_name, text, choices)`
- `dialogue_choice_selected(choice_id)`
- `dialogue_closed()`
- `inventory_changed()`
- `item_armed(item_id)` / `item_disarmed()`
- `notification_posted(message)`

### C. Grounded Actors & Foot Anchoring
Every character node (`Player`, `Keith`, `Darla`, `Tammy`) inherits from `ActorBase.gd` (`game_godot/scripts/actors/ActorBase.gd`):
- **Origin `(0, 0)` is strictly where the feet touch the floor.**
- Character sprite is offset upwards (`y = -88px`).
- YSort is active on the room container so actors move behind and in front of furniture naturally based on their foot position.
- Collision capsule sits at the feet anchor.
- Distinct approach positions guide protagonist pathing.

### D. Spatially Anchored Dialogue & Context Menus
Dialogue and choice buttons no longer scroll in a disconnected web feed:
- `DialogueBubble.gd` projects the speaking character's head position into screen coordinates.
- Bubbles appear above or adjacent to the active character, clamped to safe viewport margins.
- Choices appear directly beneath the dialogue bubble.
- Selecting actors/props produces subtle local feedback (reticle / outline), eliminating global redraw flashes.

### E. Object-on-Object Native Inventory
The bottom dock (`InventoryDock.gd`) provides interactive item slots:
- Tapping an item (e.g. *Evidence Bag of Not My Business*) arms the item into active use mode (`Input.CURSOR_CROSS`).
- Clicking a target (e.g. *Wetberry*) triggers `ActionResolver.use_item_on_target()`, resolving containment, updating room state, and updating inventory.

### F. Deterministic Campaign Data Pipeline
Campaign data is authored in `campaigns/strawberry_omen/game/` and deterministically synced to `game_godot/data/strawberry_omen/` via `tools/export_godot_campaign.py`.
- Source IDs (`npc.keith_janitor`, `scene.act1.first_sighting`, `item.evidence_bag_not_my_business`) are 100% preserved.
- `manifest.json` tracks sha256 checksums and provenance.

### G. Real Native Saves (`SaveSystem.gd`)
Saves are persisted to `user://saves/slot_1.json` in JSON v3 format. No browser `localStorage` or server cookies required.

---

## 3. Directory Layout

```
game_godot/
├── project.godot
├── export_presets.cfg
├── assets/
│   ├── rooms/        # Illustrated backgrounds (1280x720)
│   ├── actors/       # Grounded character sprites (Keith, Darla, Tammy, Player)
│   ├── portraits/    # Authored dialogue emotion portraits
│   ├── items/        # Retro inventory icons
│   ├── props/        # Central table, wetberry, appliances, mop bucket
│   ├── ui/           # 9-slice frames, buttons, slots, reticles
│   └── audio/        # Procedural offline WAV sounds (hum, click, pulse, footstep)
├── data/
│   └── strawberry_omen/  # Exported campaign JSON and manifest
├── scenes/
│   ├── bootstrap/    # Bootstrap.tscn (WorldRoot + UILayer)
│   ├── rooms/        # Breakroom.tscn
│   ├── actors/       # Player, Keith, Darla, Tammy
│   └── ui/           # DialogueBubble, InventoryDock, HUD, Overlays
├── scripts/
│   ├── runtime/      # GameRuntime, WorldState, ActionResolver, EventBus, InventorySystem
│   ├── campaign/     # CampaignLoader
│   ├── actors/       # ActorBase, KeithActor, DarlaActor, TammyActor, PlayerActor
│   ├── interaction/  # Hotspot
│   ├── rooms/        # BreakroomScene
│   ├── ui/           # DialogueBubble, InventoryDock, HUD, Overlays
│   ├── audio/        # AudioManager
│   └── save/         # SaveSystem
└── tests/
    ├── AcceptanceRunner.tscn  # Headless test runner scene
    └── run_acceptance.gd      # Acceptance test suite script
```
