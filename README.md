# Hive-Lattice Next — v0.6.0 Lattice Alive

Hive-Lattice is a Python campaign/game engine with JSON-driven content, save/load,
a phone-first local Flask/PWA player, strict validators, and an optional image
renderer. **Strawberry Omen is playable through Act V — Department of
Adjudication.**

`v0.6.0-lattice-alive` freezes the accepted `v0.5.2-mobile-playtest` phone UX
and makes the campaign materially reactive. Choices can now be hidden or locked
by prior behavior, stats, items, conditions and relationships. Rooms remember,
NPCs remember, inventory contains contextual actions, temporary conditions
persist across turns, deterministic event tables can fire, and the Act V verdict
is derived from the player's record rather than from a cosmetic verdict menu.

## What actually became systemic

- **Conditional choices** — requirements can depend on flags, inventory, stats,
  conditions, current scene, NPC memory or persistent room state.
- **Hidden routes** — qualifying actions appear only when earned (for example
  Form 9-A or the feral seal-biting route at Vendrick).
- **Active inventory** — Gear & Archives exposes contextual Use actions. The
  Evidence Bag can actually contain Wetberry; the Damp Napkin can alter fridge
  state; the Evidence Ledger can be submitted at the hearing.
- **Persistent room memory** — visited rooms retain state such as contained
  Wetberry, sampled stains and altered fridge seams.
- **NPC memory** — Keith, Darla, Moldric, Vendrick, the Condiment Guardian,
  Pell, Gorrum, Orla and others can accumulate relationship values.
- **Conditions** — short-lived or persistent consequences survive scene changes
  and save/load.
- **Deterministic events** — seeded weighted tables produce reproducible reactive
  aftershocks rather than uncontrolled randomness.
- **Stat routes** — Bureaucracy and Ape Chaos now reveal alternate mechanical
  solutions instead of functioning only as colored meters.
- **Record-driven adjudication** — evidence, testimony quality, previous insults,
  NPC memory and stats feed the Department's verdict rules.
- **Save schema v2** — reactive state is persisted; existing v1 Strawberry saves
  remain loadable.

The frozen Bard `room_schema_v1` / character / item / consequence schemas were
**not changed**. Reactive mechanics live in the campaign-local
`strawberry_interactions_v1` layer at
`campaigns/strawberry_omen/game/interactions.json`.

## Frozen mobile UX baseline

The accepted `v0.5.2-mobile-playtest` behavior remains the UI contract:

- ordinary mobile Chrome; Desktop Site not required;
- one full-width choice per row in portrait;
- large touch targets;
- safe-area-aware bottom controls;
- vertical mobile scrolling and readable landscape reflow;
- canonical Act I–V header/protocol display;
- deterministic stage-layer visibility;
- accessible browser zoom.

v0.6.0 adds systems underneath that shell rather than redesigning it.

## Dependencies

Core gameplay + local web player:

```bash
python -m pip install -r requirements.txt
```

Optional hearing-arena tensor renderer:

```bash
python -m pip install -r requirements-renderer.txt
```

PyTorch remains optional. Core gameplay, saves and web play work without it.

## Termux / Android

```bash
cd ~/storage/downloads
unzip -o Hive-Lattice-Next-v0.6.0-lattice-alive.zip
cd Hive-Lattice-Next-v0.6.0-lattice-alive
pkg install python -y
python -m pip install --break-system-packages -r requirements.txt
python -m hive_lattice.cli web strawberry_omen
```

Open `http://127.0.0.1:8000` in normal mobile Chrome.

CLI play:

```bash
python play_strawberry.py
```

## Windows

```powershell
cd $HOME\Downloads\Hive-Lattice-Next-v0.6.0-lattice-alive
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m hive_lattice.cli web strawberry_omen
```

## Validation

```bash
python tools/lattice_alive_gate.py
```

Or individually:

```bash
python -m tools.content_lint
python -m tools.validate_campaign_module
python -m tools.validate_visual_assets
python -m hive_lattice.cli validate strawberry_omen
python tests/test_act3_smoke.py
python tests/test_act5_smoke.py
python -m unittest tests.test_lattice_alive_runtime tests.test_lattice_alive_contract
python -m unittest discover -s tests
```

This source defines **370 unittest cases**: 305 non-Flask cases executable in the
artifact-build sandbox and 65 Flask-dependent web cases. The build sandbox has
no Flask package and cannot reach a package index, so the 305 non-Flask cases
are the independently executed automated receipt here. The web/PWA path is
included for real-device acceptance in the same Android environment that
accepted v0.5.2.

## Project layout

```text
engine/module_runtime.py                 Reactive campaign runtime
engine/module_save_system.py             Save v2 + v1 compatibility
campaigns/strawberry_omen/game/
  encounters.json                        Existing authored scenes
  interactions.json                      v0.6 reactive overlay (authoritative)
  items.json / npcs.json / quests.json   Campaign content
hive_lattice/web_app/                    Phone-first local web player
tools/lattice_alive_gate.py              Complete v0.6 release gate
tests/test_lattice_alive_*.py            Reactive-system acceptance
```

## Scope

Acts I–V remain the authored campaign. v0.6.0 deepens their behavior; it does
not add Act VI. Placeholder-tier generated art also remains deliberately out of
scope for this systems release.
