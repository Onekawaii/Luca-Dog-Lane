# INSTALL_ANDROID_APK.ps1 - Install Playtest APK on Connected Android Device
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$ApkPath = "dist\android\Hive-Lattice-native-playtest.apk"
if (-not (Test-Path $ApkPath)) {
    $ApkPath = "dist\Hive-Lattice-native-playtest.apk"
}

if (-not (Test-Path $ApkPath)) {
    Write-Error "APK file not found at $ApkPath. Run BUILD_NATIVE_PC.ps1 first."
}

$Adb = "$HOME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $Adb)) {
    $Adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
}

if (-not $Adb -or -not (Test-Path $Adb)) {
    Write-Error "ADB binary not found."
}

Write-Host "Checking connected Android devices..." -ForegroundColor Cyan
& $Adb devices

Write-Host "`nInstalling $ApkPath..." -ForegroundColor Yellow
& $Adb install -r $ApkPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Hive-Lattice installed on device." -ForegroundColor Green
} else {
    Write-Error "ADB install failed."
}
