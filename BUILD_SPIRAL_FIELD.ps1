$ErrorActionPreference = "Stop"

$Repo = $PSScriptRoot
$Godot = "$env:USERPROFILE\.luca_toolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$Sdk = "$env:USERPROFILE\AppData\Local\Android\Sdk"
$JavaHome = "$env:USERPROFILE\.jdk17"
$Keystore = "$env:USERPROFILE\.android\debug.keystore"
$Dist = Join-Path $Repo "dist"
$WinDir = Join-Path $Dist "windows"
$AndroidDir = Join-Path $Dist "android"
$Win = Join-Path $WinDir "Spiral-Field-v0.2.0-windows.exe"
$Apk = Join-Path $AndroidDir "Spiral-Field-v0.2.0-android.apk"

if (!(Test-Path $Godot)) { throw "Godot 4.7.2 missing: $Godot" }
if (!(Test-Path $Sdk)) { throw "Android SDK missing: $Sdk" }
if (!(Test-Path $JavaHome)) { throw "JDK17 missing: $JavaHome" }
if (!(Test-Path $Keystore)) { throw "Debug keystore missing: $Keystore" }

$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"

New-Item -ItemType Directory -Force -Path $WinDir, $AndroidDir | Out-Null
Remove-Item $Win, $Apk, "$Win.sha256", "$Apk.sha256" -ErrorAction SilentlyContinue

Write-Host "[1/10] Stage verified Voxel Tools"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "tools\stage_v013_voxel.ps1")
if ($LASTEXITCODE -ne 0) { throw "Voxel Tools staging failed" }

Write-Host "[2/10] Python contracts"
python -m unittest discover -s (Join-Path $Repo "tests") -p "test_*.py" -v
if ($LASTEXITCODE -ne 0) { throw "Python tests failed" }

Write-Host "[3/10] Godot import"
& $Godot --headless --path $Repo --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "[4/10] Kimi deterministic acceptance"
& $Godot --headless --path $Repo --script res://tests/kimi_world_acceptance.gd
if ($LASTEXITCODE -ne 0) { throw "Kimi acceptance failed" }

Write-Host "[5/10] Full donor playability + systems"
& $Godot --headless --path $Repo --script res://tests/runtime_playability.gd
if ($LASTEXITCODE -ne 0) { throw "Playability acceptance failed" }
& $Godot --headless --path $Repo --script res://tests/v016_systems_acceptance.gd
if ($LASTEXITCODE -ne 0) { throw "v0.16 systems acceptance failed" }

Write-Host "[6/10] Spiral Field acceptance"
& $Godot --headless --path $Repo --script res://tests/spiral_field_acceptance.gd
if ($LASTEXITCODE -ne 0) { throw "Spiral Field acceptance failed" }

Write-Host "[7/10] Export Windows release"
& $Godot --headless --path $Repo --export-release "Windows Desktop" $Win
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Win)) { throw "Windows export failed" }

Write-Host "[8/10] Probe Windows exported player terrain path"
$ProbeLog = Join-Path $Dist "windows-player-terrain-probe.log"
Remove-Item $ProbeLog -ErrorAction SilentlyContinue
$env:SPIRAL_PLAYER_TERRAIN_PROBE = "1"
& $Win --headless *> $ProbeLog
$ProbeRc = $LASTEXITCODE
Remove-Item Env:SPIRAL_PLAYER_TERRAIN_PROBE -ErrorAction SilentlyContinue
$ProbeText = Get-Content $ProbeLog -Raw
if ($ProbeRc -ne 0 -or $ProbeText -notmatch "\[ALL PLAYER TERRAIN TOOL GATES PASSED\]") {
    $ProbeText | Write-Host
    throw "Exported Windows player terrain-path probe failed rc=$ProbeRc"
}
Write-Host "[PASS] exported Windows TerrainSlice -> VoxelTool -> player path"

Write-Host "[9/10] Export + verify Android"
& $Godot --headless --path $Repo --export-debug "Android" $Apk
if ($LASTEXITCODE -ne 0 -or !(Test-Path $Apk)) { throw "Android export failed" }

$BuildTools = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory |
    Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending
$Signer = $null
$Aapt = $null
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
if (!$Signer) { throw "No working apksigner found" }

& $Signer verify --verbose $Apk *> $null
if ($LASTEXITCODE -ne 0) {
    & $Signer sign --ks $Keystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android $Apk
    if ($LASTEXITCODE -ne 0) { throw "APK signing failed" }
}
$VerifyOutput = & $Signer verify --verbose --print-certs $Apk 2>&1
if ($LASTEXITCODE -ne 0) { $VerifyOutput | Write-Host; throw "APK signature verify failed" }
$VerifyOutput | Select-Object -First 10 | ForEach-Object { Write-Host $_ }

if ($Aapt) {
    $Badging = & $Aapt dump badging $Apk 2>&1
    if ($LASTEXITCODE -ne 0) { throw "aapt badging failed" }
    $PackageLine = $Badging | Where-Object { $_ -like "package:*" } | Select-Object -First 1
    Write-Host $PackageLine
    if ($PackageLine -notmatch "name='com\.onekawaii\.spiralfield'") { throw "Wrong package ID" }
    if ($PackageLine -notmatch "versionCode='2'") { throw "Wrong versionCode" }
    if ($PackageLine -notmatch "versionName='0\.2\.0'") { throw "Wrong versionName" }
}

Write-Host "[10/10] Hash + release receipt"
$WinHash = (Get-FileHash $Win -Algorithm SHA256).Hash.ToLower()
$ApkHash = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLower()
"$WinHash  $(Split-Path $Win -Leaf)" | Set-Content "$Win.sha256" -Encoding ascii
"$ApkHash  $(Split-Path $Apk -Leaf)" | Set-Content "$Apk.sha256" -Encoding ascii

$ApkEntries = & python -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); print('\n'.join(n for n in z.namelist() if 'libvoxel' in n))" $Apk
if ($LASTEXITCODE -ne 0) { throw "APK archive inspection failed" }
$HasArm64Voxel = @($ApkEntries | Where-Object { $_ -match "^lib/arm64-v8a/.*libvoxel" }).Count -gt 0
$HasX64Voxel = @($ApkEntries | Where-Object { $_ -match "^lib/x86_64/.*libvoxel" }).Count -gt 0
if (!$HasArm64Voxel -or !$HasX64Voxel) {
    $ApkEntries | Write-Host
    throw "APK missing packaged Voxel Tools native libraries"
}
Write-Host "[PASS] APK contains Voxel Tools for arm64-v8a + x86_64"

$Head = (git -C $Repo rev-parse HEAD 2>$null)
$Status = (git -C $Repo status --short)
$Receipt = [ordered]@{
    product = "Spiral Field"
    version = "0.2.0"
    donor = "Luca Dog World v0.16 world systems"
    architecture = "luca-v016-donor+kimi+macroterrain+voxeltools+vehiclebody3d+companion+spiral-world-director-v2+contextual-encounters+world-pressure+persistence-v2"
    git_head = $Head
    git_status = @($Status)
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    gates = @(
        "43 Python tests",
        "Kimi deterministic acceptance",
        "runtime playability acceptance",
        "v0.16 systems acceptance",
        "Spiral Field ACT/MERCY persistence acceptance",
        "Windows exported player TerrainSlice/VoxelTool probe",
        "Android signature/package/native-lib verification"
    )
    windows = [ordered]@{
        path = $Win
        bytes = (Get-Item $Win).Length
        sha256 = $WinHash
    }
    android = [ordered]@{
        path = $Apk
        bytes = (Get-Item $Apk).Length
        sha256 = $ApkHash
        package = "com.onekawaii.spiralfield"
        version_code = 2
        version_name = "0.2.0"
        signed = $true
    }
}
$ReceiptPath = Join-Path $Dist "RELEASE_RECEIPT_Spiral-Field-v0.2.0.json"
$Receipt | ConvertTo-Json -Depth 6 | Set-Content $ReceiptPath -Encoding utf8

Write-Host "WINDOWS=$Win"
Write-Host "WINDOWS_SHA256=$WinHash"
Write-Host "ANDROID=$Apk"
Write-Host "ANDROID_SHA256=$ApkHash"
Write-Host "RECEIPT=$ReceiptPath"
Write-Host "[DONE] Spiral Field v0.2.0"
