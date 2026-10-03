$ErrorActionPreference = "Stop"
$Repo = $PSScriptRoot
$Godot = "$env:USERPROFILE\.godot_bin\Godot_v4.3-stable_win64_console.exe"
$Dist = Join-Path $Repo "dist"
$WinDir = Join-Path $Dist "windows"
$AndroidDir = Join-Path $Dist "android"
$Win = Join-Path $WinDir "Luca-Dog-World-v0.12.0.exe"
$Apk = Join-Path $AndroidDir "Luca-Dog-World-v0.12.0-android.apk"

if (!(Test-Path $Godot)) { throw "Godot 4.3 console binary not found: $Godot" }
New-Item -ItemType Directory -Force -Path $WinDir, $AndroidDir | Out-Null

Write-Host "[1/5] Clean-room verification"
python (Join-Path $Repo "tools\verify.py")
if ($LASTEXITCODE -ne 0) { throw "Verification failed" }

Write-Host "[2/5] Import project"
& $Godot --headless --path $Repo --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "[3/5] Export Windows"
& $Godot --headless --path $Repo --export-debug "Windows Desktop" $Win
if ($LASTEXITCODE -ne 0) { throw "Windows export failed" }

Write-Host "[4/5] Export Android"
& $Godot --headless --path $Repo --export-debug "Android" $Apk
if ($LASTEXITCODE -ne 0) { throw "Android export failed" }

Write-Host "[5/5] Hash + receipt"
$WinHash = (Get-FileHash $Win -Algorithm SHA256).Hash.ToLower()
$ApkHash = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLower()
"$WinHash  $(Split-Path $Win -Leaf)" | Set-Content "$Win.sha256" -Encoding ascii
"$ApkHash  $(Split-Path $Apk -Leaf)" | Set-Content "$Apk.sha256" -Encoding ascii

$Head = (git -C $Repo rev-parse HEAD 2>$null)
$Receipt = [ordered]@{
    product = "Luca Dog World"
    version = "0.12.0"
    architecture = "clean-room-sandbox-v1"
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
        version_code = 12
    }
}
$Receipt | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Dist "RELEASE_RECEIPT_v0.12.0.json") -Encoding utf8
Write-Host "WINDOWS_SHA256=$WinHash"
Write-Host "ANDROID_SHA256=$ApkHash"
Write-Host "[DONE] Luca Dog World v0.12.0"
