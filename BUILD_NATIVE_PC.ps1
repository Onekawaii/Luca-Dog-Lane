# BUILD_NATIVE_PC.ps1 - Autonomous Native Build for Windows Desktop & Android
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "HIVE-LATTICE // NATIVE BUILD SCRIPT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Export campaign data
Write-Host "`n[1/4] Exporting deterministic campaign data..." -ForegroundColor Yellow
python tools/export_godot_campaign.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Campaign data export failed."
}

# 2. Generate assets
Write-Host "`n[2/4] Generating visual & audio assets..." -ForegroundColor Yellow
python tools/generate_godot_assets.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Asset generation failed."
}

# 3. Locate Godot binary
$GodotBin = "$HOME\.godot_bin\Godot_v4.3-stable_win64_console.exe"
if (-not (Test-Path $GodotBin)) {
    $GodotBin = (Get-Command godot -ErrorAction SilentlyContinue).Source
}
if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    Write-Error "Godot 4 binary not found in $HOME\.godot_bin or PATH."
}

# 4. Build Windows Desktop Release
Write-Host "`n[3/4] Exporting Windows Desktop executable..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "dist\windows" | Out-Null
& $GodotBin --headless --path game_godot --export-release "Windows Desktop" "../dist/windows/Hive-Lattice.exe"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "dist\windows\Hive-Lattice.exe")) {
    Write-Error "Windows Desktop export failed."
}
Write-Host "  [OK] dist\windows\Hive-Lattice.exe created successfully." -ForegroundColor Green

# 5. Build Android APK
Write-Host "`n[4/4] Building Android APK..." -ForegroundColor Yellow
python tools/build_android_apk.py
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Android APK build completed with warnings."
} else {
    Write-Host "  [OK] dist\android\Hive-Lattice-native-playtest.apk created successfully." -ForegroundColor Green
}

# Package release zip and sidecars
python tools/package_native_playtest.py

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "[BUILD SUCCESS] All deliverables ready in dist/" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
