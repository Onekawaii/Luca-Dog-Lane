# SPIRAL FIELD 🌀🐕‍🦺

**Open-world nightmare sandbox built from the verified Luca Dog World v0.26 substrate.**

Working title: **Spiral Field v0.2.2**.

This is a separate game branch. Luca Dog World is preserved as the donor baseline; this project does not replace it.

## What survives from Luca Dog World

- deterministic Kimi open-world generation
- continuous MacroTerrain
- Voxel Tools terrain mining/building
- first-person desktop controls
- Android joystick + right-side drag look
- Luca companion
- VehicleBody3D buggy and four-camera rig
- spawn sandbox and catalog-driven tools
- map profiles, items, recipes, persistence, and regression tests

## What Spiral Field adds

The new authoritative `SpiralWorldDirector` ports concepts from the supplied legacy projects without importing their old engines:

- **Tabbytulhu UndertalePlus** → ACT / MERCY, affection, corruption, TALK/PET/FEED/SPARE-style responses
- **Twin Spirals** → physical Witnessing and Wailing sites
- **Spiral Infection Generator** → deterministic runtime spiral-infection geometry
- **SCH / Spiral Cow** → nightmare-open-world framing and mutable world-state logic

The first loop is:

`ROAM → DISCOVER → ACT or MERCY → WORLD CHANGES → SAVE → CONTINUE`

## v0.2 world state

Persistent save schema: `user://spiral_field_state_v1.json`

Authoritative values:

- Affection
- Corruption
- Witnessing
- Wailing
- interaction count
- Spiral stage: DORMANT → AWAKE → INFECTED → VELVET BREACH

## Controls

Desktop keeps the Luca donor controls: WASD, mouse look, Space jump, Shift sprint, Q cycle tool, E use, V noclip.

Android keeps the left movement stick, right-side look, JUMP, TOOL, USE, NOCLIP, MAP and SPAWN controls.

ACT/MERCY are no longer tool-belt entries. Spiral encounters open contextual verbs such as TALK/PET/FEED/MERCY, BEHOLD/AVERT/TOUCH/MERCY, or ANSWER/LISTEN/HUSH/MERCY.

## Verification

Run:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
powershell -ExecutionPolicy Bypass -File .\BUILD_SPIRAL_FIELD.ps1
```

Release gates include Python contracts, Kimi determinism, live movement/mobile/vehicle playability, v0.26 system acceptance, Spiral ACT/MERCY + save/reload acceptance, exported Windows Voxel Tools probing, and Android signature/package/native-library validation.

> No receipt, no banana.

## Outputs

```text
dist/windows/Spiral-Field-v0.2.2-windows.exe
dist/android/Spiral-Field-v0.2.2-android.apk
dist/RELEASE_RECEIPT_Spiral-Field-v0.2.2.json
```
