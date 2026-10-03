<div align="center">

<img src="assets/icon.svg" width="160" alt="Luca Dog World paw mark">

# LUCA DOG WORLD 🐕🌲

**A clean-room open-world sandbox built around roaming, spawning, physics toys, NPCs, vehicles, and one very good dog.**

`walk anywhere. spawn nonsense. keep Luca nearby.`

</div>

---

## This is a new game

Luca Dog World v0.12 is a ground-up standalone Godot project.

It does not boot through another campaign, room system, story engine, or inherited scene graph. The application starts directly in one open sandbox world.

There is no mandatory first room and no required mission chain. You spawn outside and play.

Current sandbox loop:

- roam a 960 m × 960 m world;
- follow Luca or let him follow you;
- open the spawn menu and create props;
- grab, remove, duplicate, or inspect spawned objects;
- toggle noclip and fly around the map;
- interact with wandering NPCs;
- drive the sandbox buggy;
- explore roads, woods, a workshop, physics/skate space, quarry terraces, and a round plaza.

---

## The boundary fix

The ground is no longer a decorative plane.

The world uses one continuous **rendered + collidable slab** whose visual top and collision top both resolve to y=0.

Four physical perimeter bodies close the map:

`NorthBoundary · SouthBoundary · WestBoundary · EastBoundary`

The player also has an independent recovery rule. Falling below the world or escaping past the collision perimeter returns the player to the safe spawn point.

That means world containment does not depend on one collider behaving perfectly.

---

## Sandbox controls

### Desktop

`WASD` move · mouse look · `SPACE` jump · `SHIFT` sprint

`E` use current tool · `Q` cycle tool · `V` noclip

### Android

The mobile HUD provides:

- left movement stick;
- drag-look on open screen space;
- SPAWN menu;
- TOOL cycle;
- NOCLIP;
- USE;
- ▲ / ▼ vertical controls.

The interface is built specifically for this game instead of inheriting an older HUD.

---

## Tool modes

| Tool | What it does |
|---|---|
| **GRAB** | Tethers a spawned rigid prop in front of the camera. |
| **REMOVE** | Deletes a sandbox prop. |
| **DUPLICATE** | Makes another copy of a spawned prop. |
| **INSPECT** | Shows the target node and its gameplay groups. |

Spawnable objects currently include crates, barrels, balls, cones, ramps, NPCs, and buggies.

---

## World layout

The current map is deliberately broad and readable rather than procedurally infinite:

- central crossed road network;
- standalone workshop / spawn yard;
- skate and physics-testing space;
- climbable quarry terraces with a real collision ramp;
- round plaza and bridge;
- seeded forest distribution;
- rocks and open fields;
- drivable road space;
- hard outer boundary.

This first clean-room map is the foundation. Future areas can be added without changing the boot architecture.

---

## Verification

This repository has a structural verifier because “it opened once” is not enough.

Run:

```powershell
python tools\verify.py
python -m unittest discover -s tests -p "test_*.py" -v
```

The verifier checks:

- direct standalone boot;
- no autoload inheritance;
- continuous ground and all four physical boundaries;
- independent out-of-bounds recovery;
- sandbox spawn/tool/noclip contracts;
- Godot parse and runtime smoke;
- absence of forbidden old-runtime identifiers from the active tree.

> **No receipt, no banana.**

---

## Build

Tested build engine: **Godot 4.3 stable**.

```powershell
powershell -ExecutionPolicy Bypass -File .\BUILD_RELEASE.ps1
```

Expected artifacts:

```text
dist/windows/Luca-Dog-World-v0.12.0.exe
dist/android/Luca-Dog-World-v0.12.0-android.apk
dist/RELEASE_RECEIPT_v0.12.0.json
```

Android package:

`com.onekawaii.lucadogworld`

---

## Architecture

The active game is intentionally small enough to understand:

```text
project.godot
scenes/Main.tscn
scripts/
  Game.gd
  Player.gd
  HUD.gd
  Luca.gd
  NPC.gd
  Buggy.gd
tools/verify.py
tests/test_clean_room.py
```

Most geometry is generated with native Godot primitives so collision and visible geometry can be reasoned about together.

---

## Operating principle

> **Make the world tangible. Keep the architecture legible. Let the player make a mess. Pet the dog.**

🐕🍌
