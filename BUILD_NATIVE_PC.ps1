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

function Invoke-GodotSafe {
    param([string[]]$Arguments)
    $escapedArguments = @($Arguments | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f ($_ -replace '"', '\"') } else { $_ }
    })
    $proc = Start-Process -FilePath $GodotBin -ArgumentList $escapedArguments -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

# 4. Import once so a fresh extracted bundle has class metadata and imported assets.
Write-Host "`n[PRECHECK] Importing Godot project and rebuilding class cache..." -ForegroundColor Yellow
$GodotExit = Invoke-GodotSafe @("--headless", "--path", (Join-Path $PSScriptRoot "game_godot"), "--import")
if ($GodotExit -ne 0) {
    Write-Error "Godot project import failed."
}

# 5. Parse-check all production GDScript before export.
Write-Host "`n[PRECHECK] Parsing all production GDScript..." -ForegroundColor Yellow
$GodotExit = Invoke-GodotSafe @("--headless", "--path", (Join-Path $PSScriptRoot "game_godot"), "--script", "res://tests/ValidateScripts.gd")
if ($GodotExit -ne 0) {
    Write-Error "GDScript parse gate failed. Fix parser errors before packaging."
}

# 6. Build Windows Desktop Release. Clean stale Godot safe-save files first.
Write-Host "`n[3/4] Exporting Windows Desktop executable..." -ForegroundColor Yellow
$WindowsDir = Join-Path $PSScriptRoot "dist\windows"
$WindowsExe = Join-Path $WindowsDir "Hive-Lattice.exe"
New-Item -ItemType Directory -Force -Path $WindowsDir | Out-Null
Get-ChildItem $WindowsDir -Filter "*.tmp" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$GodotExit = Invoke-GodotSafe @("--headless", "--path", (Join-Path $PSScriptRoot "game_godot"), "--export-release", "Windows Desktop", $WindowsExe)
if ($GodotExit -ne 0 -or -not (Test-Path $WindowsExe)) {
    Write-Warning "Initial Windows export failed. Clearing stale safe-save files and retrying once."
    Get-ChildItem $WindowsDir -Filter "*.tmp" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $GodotExit = Invoke-GodotSafe @("--headless", "--path", (Join-Path $PSScriptRoot "game_godot"), "--export-release", "Windows Desktop", $WindowsExe)
}
if ($GodotExit -ne 0 -or -not (Test-Path $WindowsExe)) {
    Write-Error "Windows Desktop export failed after clean retry."
}
Write-Host "  [OK] $WindowsExe created successfully." -ForegroundColor Green

# 7. Build Android APK
Write-Host "`n[4/4] Building Android APK..." -ForegroundColor Yellow
python tools/build_android_apk.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Android APK build failed. Native suite is not complete."
}
Write-Host "  [OK] dist\Hive-Lattice-native-android-playtest.apk created successfully." -ForegroundColor Green

# Package release zip and sidecars. Missing deliverables are fatal.
python tools/package_native_playtest.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Native playtest packaging failed."
}

# Deterministic export rewrites tracked JSON with normalized line endings on Windows.
# Restore the committed source copies before exact-state provenance is measured.
git restore -- game_godot/data/strawberry_omen
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not restore deterministic exported campaign data before receipt generation."
}

# Generate the exact-state release receipt only after both platform artifacts exist.
python tools/write_release_receipt.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Release receipt generation failed."
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "[BUILD SUCCESS] All deliverables ready in dist/" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
