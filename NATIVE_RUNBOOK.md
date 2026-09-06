# HIVE-LATTICE // NATIVE CLIENT RUNBOOK
**Codename:** GET IT OUT OF THE FUCKING BROWSER  
**Platform:** Windows 10/11 x64, Android (API 24+)  

---

## 1. Quick Start (Windows)

### Double-Click Launch
Double-click `RUN_NATIVE_PC.bat` in the repository root.
- If `dist\windows\Hive-Lattice.exe` exists, the game starts immediately.
- If missing, it will invoke `BUILD_NATIVE_PC.ps1` to build and launch the game.

### Direct Executable
```powershell
.\dist\windows\Hive-Lattice.exe
```

---

## 2. Developer & Build Commands

### A. Run Verification Gates
Runs Python lints, unit tests, campaign exporter, and the 63-test Godot headless acceptance suite:
```powershell
.\VERIFY_NATIVE_PC.ps1
```
Or via Python:
```bash
python tools/verify_native_contract.py
```

### B. Build Executables & Release Packages
Builds the Windows Desktop standalone executable, native Android APK, and packages release zips with SHA-256 sidecars:
```powershell
.\BUILD_NATIVE_PC.ps1
```

### C. Open in Godot 4 Editor
Launches the Godot 4 editor directly into the `game_godot/` project:
```powershell
.\OPEN_GODOT.ps1
```

### D. Export Campaign Data from Source
Whenever files under `campaigns/strawberry_omen/game/` are modified:
```bash
python tools/export_godot_campaign.py
```

### E. Install on Android Device (via ADB)
With a USB-connected Android phone with Developer Options / USB Debugging enabled:
```powershell
.\INSTALL_ANDROID_APK.ps1
```

---

## 3. Keyboard & Mouse Controls (Desktop)

| Input | Action |
| :--- | :--- |
| **Left Click / Tap** | Walk to location / Select actor / Interact with prop / Pick dialogue choice |
| **Click Inventory Slot** | Arm / Disarm item for object-on-object interaction |
| **F1** | Toggle developer debug overlay (nav points, collision outlines, foot anchors) |
| **F5** | Quick Save state to Slot 1 (`user://saves/slot_1.json`) |
| **F9** | Quick Load state from Slot 1 |
| **S** | Open Personnel Record & Status Overlay |
| **J** | Open Incident Chronicle & Journal Overlay |
| **Escape** | Close active dialogue / Close overlays / Open Operations Menu |

---

## 4. Mobile Controls (Android)

| Input | Action |
| :--- | :--- |
| **Tap Floor** | Protagonist approaches point |
| **Tap Character** | Protagonist approaches character & opens dialogue |
| **Tap Prop** | Protagonist approaches prop & opens context actions |
| **Tap Inventory Item** | Arms item (crosshair mode) -> Tap target to use |
| **Back Button** | Closes dialogue or top overlay before exiting application |
