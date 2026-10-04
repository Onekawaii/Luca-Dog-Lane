param(
    [switch] $AllowDirty
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$Godot = Join-Path $env:USERPROFILE ".luca_toolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$Dist = Join-Path $Repo "dist\v013-qualification"
$WinDir = Join-Path $Dist "windows"
$AndroidDir = Join-Path $Dist "android"
$Win = Join-Path $WinDir "Luca-Dog-World-v013-qual.exe"
$Apk = Join-Path $AndroidDir "Luca-Dog-World-v013-qual.apk"

if (!(Test-Path $Godot)) { throw "Locked Godot 4.7.2 binary missing: $Godot" }

Set-Location $Repo

Write-Host "[1/8] Engineering contract"
python tools\check_engineering_contract.py
if ($LASTEXITCODE -ne 0) { throw "Engineering contract failed" }

Write-Host "[2/8] Export templates"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\bootstrap_v013_export_templates.ps1
if ($LASTEXITCODE -ne 0) { throw "Export template bootstrap failed" }

Write-Host "[3/8] Android toolchain"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\configure_v013_android_toolchain.ps1
if ($LASTEXITCODE -ne 0) { throw "Android toolchain configuration failed" }

Write-Host "[4/8] Voxel substrate"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\stage_v013_voxel.ps1
if ($LASTEXITCODE -ne 0) { throw "Voxel staging failed" }
python tools\verify_v013_substrate.py
if ($LASTEXITCODE -ne 0) { throw "v0.13 substrate qualification failed" }

Write-Host "[5/8] Clean qualification output"
if (Test-Path $Dist) { Remove-Item $Dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WinDir,$AndroidDir | Out-Null

Write-Host "[6/8] Windows export"
& $Godot --headless --path $Repo --export-debug "Windows Desktop" $Win *> (Join-Path $Dist "windows_export.log")
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Win)) { throw "Godot 4.7.2 Windows export failed" }

Write-Host "[7/8] Android export"
$env:JAVA_HOME = Join-Path $env:USERPROFILE ".jdk17"
$env:ANDROID_HOME = Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PATH = "$(Join-Path $env:JAVA_HOME 'bin');$env:PATH"
& $Godot --headless --path $Repo --export-debug "Android" $Apk *> (Join-Path $Dist "android_export.log")
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Apk)) { throw "Godot 4.7.2 Android export failed" }

Write-Host "[8/8] Independent artifact verification"
$VerifyArgs = @("tools\verify_v013_exports.py")
if ($AllowDirty) { $VerifyArgs += "--allow-dirty" }
python @VerifyArgs
if ($LASTEXITCODE -ne 0) { throw "v0.13 native export qualification failed" }

Write-Host "[DONE] ENG-003 native export qualification"
