$ErrorActionPreference = "Stop"

$Repo = $PSScriptRoot
$Godot = "$env:USERPROFILE\.luca_toolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$Sdk = "$env:USERPROFILE\AppData\Local\Android\Sdk"
$JavaHome = "$env:USERPROFILE\.jdk17"
$Dist = Join-Path $Repo "dist"
$WinDir = Join-Path $Dist "windows"
$AndroidDir = Join-Path $Dist "android"
$Win = Join-Path $WinDir "Luca-Dog-World-v0.16.1-KIMI-PLAYTEST-REPAIR.exe"
$Apk = Join-Path $AndroidDir "Luca-Dog-World-v0.16.1-KIMI-PLAYTEST-REPAIR-android.apk"

if (!(Test-Path $Godot)) { throw "Godot 4.7.2 console binary not found: $Godot" }
if (!(Test-Path $Sdk)) { throw "Android SDK not found: $Sdk" }
if (!(Test-Path $JavaHome)) { throw "JDK not found: $JavaHome" }

$env:JAVA_HOME = $JavaHome
$env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

New-Item -ItemType Directory -Force -Path $WinDir, $AndroidDir | Out-Null
Remove-Item $Win, $Apk, "$Win.sha256", "$Apk.sha256" -ErrorAction SilentlyContinue

Write-Host "[1/8] Clean-room verification"
python (Join-Path $Repo "tools\verify.py")
if ($LASTEXITCODE -ne 0) { throw "Verification failed" }

Write-Host "[2/8] Unit tests"
$Tests = Join-Path $Repo "tests"
python -m unittest discover -s $Tests -p "test_*.py" -v
if ($LASTEXITCODE -ne 0) { throw "Unit tests failed" }

Write-Host "[3/8] Import project"
& $Godot --headless --path $Repo --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "[4/8] Kimi deterministic world acceptance"
& $Godot --headless --path $Repo --script res://tests/kimi_world_acceptance.gd
if ($LASTEXITCODE -ne 0) { throw "Kimi deterministic world acceptance failed" }

Write-Host "[5/8] Export Windows"
& $Godot --headless --path $Repo --export-debug "Windows Desktop" $Win
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Win)) { throw "Windows export failed" }

Write-Host "[6/8] Export Android release"
& (Join-Path $Repo "tools\export_android_release.ps1") -Repo $Repo
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Apk)) { throw "Android release export failed" }

Write-Host "[7/8] Verify Android release"
$Signer = $null
$Aapt = $null
$BuildTools = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory |
    Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending

foreach ($Dir in $BuildTools) {
    $Candidate = Join-Path $Dir.FullName "apksigner.bat"
    if (Test-Path $Candidate) {
        & $Candidate version *> $null
        if ($LASTEXITCODE -eq 0) {
            $Signer = $Candidate
            $MaybeAapt = Join-Path $Dir.FullName "aapt.exe"
            if (Test-Path $MaybeAapt) { $Aapt = $MaybeAapt }
            break
        }
    }
}
if (!$Signer) { throw "No working apksigner.bat found" }

& $Signer verify --verbose $Apk *> $null
if ($LASTEXITCODE -ne 0) { throw "Release APK signature verification failed" }

$VerifyOutput = & $Signer verify --verbose --print-certs $Apk 2>&1
if ($LASTEXITCODE -ne 0) {
    $VerifyOutput | Write-Host
    throw "APK signature verification failed"
}
$VerifyOutput | Select-Object -First 12 | ForEach-Object { Write-Host $_ }

if ($Aapt) {
    $Badging = & $Aapt dump badging $Apk 2>&1
    if ($LASTEXITCODE -ne 0) { throw "aapt badging verification failed" }
    $PackageLine = $Badging | Where-Object { $_ -like "package:*" } | Select-Object -First 1
    Write-Host $PackageLine
    if ($PackageLine -notmatch "name='com\.onekawaii\.lucadogworld'") {
        throw "Unexpected Android package ID"
    }
    if ($PackageLine -notmatch "versionCode='19'") {
        throw "Unexpected Android versionCode"
    }
    if ($PackageLine -notmatch "versionName='0\.16\.1-kimi'") {
        throw "Unexpected Android versionName"
    }
}

Write-Host "[8/8] Hash + receipt"
$WinHash = (Get-FileHash $Win -Algorithm SHA256).Hash.ToLower()
$ApkHash = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLower()
"$WinHash  $(Split-Path $Win -Leaf)" | Set-Content "$Win.sha256" -Encoding ascii
"$ApkHash  $(Split-Path $Apk -Leaf)" | Set-Content "$Apk.sha256" -Encoding ascii

$Head = (git -C $Repo rev-parse HEAD 2>$null)
$Receipt = [ordered]@{
    product = "Luca Dog World"
    version = "0.16.1-kimi"
    architecture = "clean-room-sandbox-v1+kimi-core+continuous-terrain+rendered-surface-lock+local-underworld-recovery+vehiclebody3d+companion-formation+damageable-npcs+content-registry-v1+map-profiles-v1"
    git_head = $Head
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    windows = [ordered]@{
        path = $Win
        bytes = (Get-Item $Win).Length
        sha256 = $WinHash
    }
    android = [ordered]@{
        path = $Apk
        bytes = (Get-Item $Apk).Length
        sha256 = $ApkHash
        package = "com.onekawaii.lucadogworld"
        version_code = 19
        signed = $true
    }
}

$ReceiptPath = Join-Path $Dist "RELEASE_RECEIPT_v0.16.1-KIMI-PLAYTEST-REPAIR.json"
$Receipt | ConvertTo-Json -Depth 5 | Set-Content $ReceiptPath -Encoding utf8

Write-Host "WINDOWS_SHA256=$WinHash"
Write-Host "ANDROID_SHA256=$ApkHash"
Write-Host "RECEIPT=$ReceiptPath"
Write-Host "[DONE] Luca Dog World v0.16.1-KIMI-PLAYTEST-REPAIR"
