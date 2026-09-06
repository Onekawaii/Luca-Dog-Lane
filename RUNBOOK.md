# Hive-Lattice v0.6.0 Lattice Alive — Runbook

## Android / Termux

```bash
cd ~/storage/downloads
unzip -o Hive-Lattice-Next-v0.6.0-lattice-alive.zip
cd Hive-Lattice-Next-v0.6.0-lattice-alive
pkg install python -y
python -m pip install --break-system-packages -r requirements.txt
python -m hive_lattice.cli web strawberry_omen
```

Open `http://127.0.0.1:8000` in normal mobile Chrome. Desktop Site stays OFF.

## Windows

```powershell
cd $HOME\Downloads\Hive-Lattice-Next-v0.6.0-lattice-alive
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m hive_lattice.cli web strawberry_omen
```

Optional renderer:

```powershell
python -m pip install -r requirements-renderer.txt
```

## One-command gate

```bash
python tools/lattice_alive_gate.py
```

Expected source definition: **370 unittest cases**.

## Reactive playtest checklist

- [ ] Visit Keith, acquire the Evidence Bag, return to the central table.
- [ ] Confirm **Seal Wetberry in the Evidence Bag** appears only after the bag exists.
- [ ] Use the bag either as a revealed choice or from Gear & Archives.
- [ ] Confirm Wetberry becomes contained, moisture changes, and the bag becomes Bagged Wetberry Evidence.
- [ ] Open Status and confirm relationship/condition information appears after relevant actions.
- [ ] Save after creating reactive state, mutate the state, Load, and confirm room/NPC/condition state restores.
- [ ] Build Bureaucracy and look for Form 9-A at Vendrick, or build Ape Chaos and look for the seal-biting route.
- [ ] Reach Act V and compare an honest/evidence-heavy hearing against an insult/evasive route.
- [ ] Confirm the Verdict is derived from the record and appears in Lore/Chronicle.

## Save compatibility

New saves use `save_version: 2` and persist:

- room state;
- NPC memory;
- active conditions;
- deterministic event history/seed;
- turn count;
- last system outcome.

v1 Strawberry saves remain loadable; missing v2 fields default safely.

## Interaction contract

See `docs/REACTIVE_GAMEPLAY_CONTRACT.md`.

The campaign's original `encounters.json` remains valid. The new
`game/interactions.json` overlays reactive requirements/effects and adds
contextual choices/item actions without modifying frozen Bard schemas.
