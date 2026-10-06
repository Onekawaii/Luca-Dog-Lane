param(
    [string]$Repo = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$Godot = "$env:USERPROFILE\.luca_toolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$Sdk = "$env:USERPROFILE\AppData\Local\Android\Sdk"
$JavaHome = "$env:USERPROFILE\.jdk17"
$SigningDir = "$env:USERPROFILE\.luca_signing"
$Keystore = Join-Path $SigningDir "luca-dog-world-release.keystore"
$CredsPath = Join-Path $SigningDir "luca-dog-world-signing.json"
$Alias = "lucadogworld"
$PresetPath = Join-Path $Repo "export_presets.cfg"
$OutDir = Join-Path $Repo "dist\android"
$Apk = Join-Path $OutDir "Luca-Dog-World-v0.15.3-KIMI-ENVIRONMENT-android.apk"
$DownloadDir = "$env:USERPROFILE\Downloads\Luca-Dog-World-v0.15.3-KIMI-ENVIRONMENT"

if (!(Test-Path $Godot)) { throw "Godot 4.7.2 not found: $Godot" }
if (!(Test-Path $Sdk)) { throw "Android SDK not found: $Sdk" }
if (!(Test-Path $JavaHome)) { throw "JDK not found: $JavaHome" }

New-Item -ItemType Directory -Force -Path $SigningDir, $OutDir, $DownloadDir | Out-Null

if (!(Test-Path $CredsPath) -or !(Test-Path $Keystore)) {
    $Password = ([guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")).Substring(0, 48)
    $Keytool = Join-Path $JavaHome "bin\keytool.exe"
    & $Keytool -genkeypair -v -keystore $Keystore -alias $Alias -keyalg RSA -keysize 4096 -validity 10000 -storepass $Password -keypass $Password -dname "CN=Luca Dog World, O=Onekawaii, C=US"
    if ($LASTEXITCODE -ne 0) { throw "Release keystore generation failed" }
    @{ alias = $Alias; password = $Password } | ConvertTo-Json | Set-Content $CredsPath -Encoding utf8
    & icacls $CredsPath /inheritance:r /grant:r "$env:USERNAME:(R,W)" *> $null
    & icacls $Keystore /inheritance:r /grant:r "$env:USERNAME:(R,W)" *> $null
}

$Creds = Get-Content $CredsPath -Raw | ConvertFrom-Json
$Password = [string]$Creds.password
$Alias = [string]$Creds.alias
if ([string]::IsNullOrWhiteSpace($Password)) { throw "Signing password missing" }

$OriginalPreset = Get-Content $PresetPath -Raw
$EscapedKeystore = $Keystore.Replace("\", "/")
$Patched = $OriginalPreset
$Patched = $Patched -replace 'keystore/release="[^"]*"', ('keystore/release="' + $EscapedKeystore + '"')
$Patched = $Patched -replace 'keystore/release_user="[^"]*"', ('keystore/release_user="' + $Alias + '"')
$Patched = $Patched -replace 'keystore/release_password="[^"]*"', ('keystore/release_password="' + $Password + '"')

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
    [System.IO.File]::WriteAllText($PresetPath, $Patched, $Utf8NoBom)
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_HOME = $Sdk
    $env:ANDROID_SDK_ROOT = $Sdk
    Remove-Item $Apk -ErrorAction SilentlyContinue

    & $Godot --headless --path $Repo --export-release "Android" $Apk
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $Apk)) { throw "Android release export failed" }
}
finally {
    [System.IO.File]::WriteAllText($PresetPath, $OriginalPreset, $Utf8NoBom)
}

$BuildTools = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory | Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending
$Signer = $null
$Aapt = $null
foreach ($Dir in $BuildTools) {
    $MaybeSigner = Join-Path $Dir.FullName "apksigner.bat"
    $MaybeAapt = Join-Path $Dir.FullName "aapt.exe"
    if ((Test-Path $MaybeSigner) -and (Test-Path $MaybeAapt)) {
        $Signer = $MaybeSigner
        $Aapt = $MaybeAapt
        break
    }
}
if (!$Signer -or !$Aapt) { throw "Android verification tools not found" }

$Verify = & $Signer verify --verbose --print-certs $Apk 2>&1
if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed" }

$Badging = & $Aapt dump badging $Apk 2>&1
if ($LASTEXITCODE -ne 0) { throw "APK badging inspection failed" }
$BadgingText = $Badging -join "`n"
if ($BadgingText -match 'application-debuggable') { throw "Release APK is still debuggable" }
if ($BadgingText -notmatch "targetSdkVersion:'36'") { throw "Unexpected target SDK" }

$Permissions = & $Aapt dump permissions $Apk 2>&1
$PermissionLines = @($Permissions | Where-Object { $_ -match '^uses-permission' })
if ($PermissionLines.Count -ne 0) { throw "Unexpected Android permissions: $($PermissionLines -join ', ')" }

$Hash = (Get-FileHash $Apk -Algorithm SHA256).Hash.ToLower()
$Dest = Join-Path $DownloadDir (Split-Path $Apk -Leaf)
Copy-Item $Apk $Dest -Force
"$Hash  $(Split-Path $Dest -Leaf)" | Set-Content "$Dest.sha256" -Encoding ascii

Write-Host "ANDROID_RELEASE_DEBUGGABLE=false"
Write-Host "ANDROID_RELEASE_PERMISSIONS=0"
Write-Host "ANDROID_RELEASE_SHA256=$Hash"
Write-Host "ANDROID_RELEASE_PATH=$Dest"
