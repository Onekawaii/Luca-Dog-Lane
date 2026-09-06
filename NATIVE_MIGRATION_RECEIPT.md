# HIVE-LATTICE // NATIVE MIGRATION RECEIPT
**Codename:** GET IT OUT OF THE FUCKING BROWSER  
**Handoff Baseline SHA:** `2650ad3f654aee60f342014af6d15fa4f1ce70e9`  
**Engine:** Godot 4.3 Stable (`4.3.stable.official.77dcf97d8`)  
**Status:** **VERTICAL SLICE COMPLETE & VERIFIED**  

---

## 1. Acceptance Gates Verification

| Subsystem / Gate | Target | Status | Notes |
| :--- | :--- | :---: | :--- |
| **Python Unit Tests** | 406 Tests | **PASS** | `python -m unittest discover -s tests -p "test*.py"` (406 OK, 1 skipped) |
| **Campaign Lint & CLI** | Schema Validation | **PASS** | `tools/content_lint.py`, `validate_campaign_module`, `cli validate` |
| **Data Export Pipeline** | Manifest & Checksum | **PASS** | `tools/export_godot_campaign.py` (Combined SHA: `36815a9ca367fb8889df5e5beebb732bc489a03dc390a5937c840445cd36e922`) |
| **Godot Acceptance Suite** | 63 Headless Tests | **PASS** | `godot --headless --path game_godot --script res://tests/run_acceptance.gd` (63/63 PASS) |
| **Keith Interaction Vector** | Dialogue + Evidence Bag | **PASS** | Foot-grounded Keith grants Evidence Bag, increments trust flag & NPC memory |
| **Darla Interaction Vector** | Coffee Counter Dialogue | **PASS** | Unlocks fridge hints & relationship delta |
| **Tammy HR Spawn Vector** | Conditional Appearance | **PASS** | Spawns with clipboard only when HR is alerted |
| **Wetberry Containment** | Object-on-Object Loop | **PASS** | Evidence Bag arms -> clicks Wetberry -> resolves containment -> updates room state |
| **Save / Load Persistence** | User directory (`user://`) | **PASS** | State roundtrips with v3 schema parity across sessions |
| **Windows Export** | Standalone `.exe` | **PASS** | `dist/windows/Hive-Lattice.exe` (84.5 MB) |
| **Android Export** | Signed `.apk` | **PASS** | `dist/android/Hive-Lattice-native-playtest.apk` (97.3 MB) |

---

## 2. Playable Acceptance Loop (The Wetberry Loop)

1. Launch native client (`dist/windows/Hive-Lattice.exe` or `RUN_NATIVE_PC.bat`).
2. The Breakroom loads with grounded characters, depth YSort, and fluorescent ambience.
3. Player clicks Keith -> Protagonist walks to Keith's approach point.
4. Anchored dialogue bubble appears above Keith with emotion portrait and choices.
5. Select "Ask Keith for an evidence bag" -> `item.evidence_bag_not_my_business` added to bottom inventory dock.
6. Click Evidence Bag in bottom dock -> Item becomes armed (`USE: Evidence Bag (CLICK TARGET)`).
7. Click Wetberry on the Central Table.
8. `ActionResolver` executes `bag_wetberry_now` -> Wetberry carton is contained and disappears from table -> `item.bagged_wetberry_evidence` granted.
9. Press `F5` (or Menu -> Save) -> Game saved to `user://saves/slot_1.json`.
10. Quit game, relaunch, press `F9` (or Menu -> Load) -> Exact contained state, inventory, and flags restored.

---

## 3. Shipped Deliverables in `dist/`

- **Windows Desktop Executable:** `dist/windows/Hive-Lattice.exe`
- **Windows Playtest Package:** `dist/Hive-Lattice-native-windows-playtest.zip`
- **Android Playtest Package:** `dist/Hive-Lattice-native-android-playtest.apk`
- **Source Build Archive:** `dist/Hive-Lattice-native-playtest-source.zip`
- **SHA-256 Checksum Sidecars:** Generated for each package in `dist/`

---

## 4. Architectural Status

- **Web App Status:** Preserved under `hive_lattice/web_app/` as **LEGACY / REFERENCE / DEBUG CLIENT**.
- **Native Game Status:** Primary production client established under `game_godot/`.
