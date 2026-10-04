$ErrorActionPreference = "Stop"

$Settings = Join-Path $env:APPDATA "Godot\editor_settings-4.7.tres"
$JavaHome = Join-Path $env:USERPROFILE ".jdk17"
$AndroidSdk = Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk"
$Keystore = Join-Path $env:USERPROFILE ".android\debug.keystore"

foreach ($Required in @($Settings, $JavaHome, $AndroidSdk, $Keystore)) {
    if (!(Test-Path $Required)) { throw "Required Android toolchain path missing: $Required" }
}

$JavaExe = Join-Path $JavaHome "bin\java.exe"
$JavaRelease = Join-Path $JavaHome "release"
if (!(Test-Path $JavaExe)) { throw "java.exe missing: $JavaExe" }
if (!(Test-Path $JavaRelease)) { throw "JDK release metadata missing: $JavaRelease" }

$JavaVersionLine = Get-Content $JavaRelease | Where-Object { $_ -like 'JAVA_VERSION=*' } | Select-Object -First 1
if (!$JavaVersionLine) { throw "JAVA_VERSION missing from JDK release metadata" }
$JavaVersion = $JavaVersionLine

function To-GodotPath([string] $Path) {
    return $Path.Replace("\", "/")
}

$SettingsText = [IO.File]::ReadAllText($Settings)
$Backup = "$Settings.pre-luca-v013"
if (!(Test-Path $Backup)) {
    Copy-Item $Settings $Backup
}

$JavaValue = To-GodotPath $JavaHome
$SdkValue = To-GodotPath $AndroidSdk
$KeyValue = To-GodotPath $Keystore

$JavaLine = 'export/android/java_sdk_path = "{0}"' -f $JavaValue
$SdkLine = 'export/android/android_sdk_path = "{0}"' -f $SdkValue
$KeyLine = 'export/android/debug_keystore = "{0}"' -f $KeyValue

$SettingsText = [Regex]::Replace(
    $SettingsText,
    '(?m)^export/android/java_sdk_path = ".*"$',
    $JavaLine
)
$SettingsText = [Regex]::Replace(
    $SettingsText,
    '(?m)^export/android/android_sdk_path = ".*"$',
    $SdkLine
)
$SettingsText = [Regex]::Replace(
    $SettingsText,
    '(?m)^export/android/debug_keystore = ".*"$',
    $KeyLine
)

[IO.File]::WriteAllText($Settings, $SettingsText, (New-Object Text.UTF8Encoding($false)))

$Verify = [IO.File]::ReadAllText($Settings)
foreach ($Expected in @($JavaLine, $SdkLine, $KeyLine)) {
    if (!$Verify.Contains($Expected)) { throw "Editor setting not applied: $Expected" }
}

$Receipt = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    godot_settings = $Settings
    java_home = $JavaHome
    java_version = [string]$JavaVersion
    android_sdk = $AndroidSdk
    debug_keystore = $Keystore
    debug_keystore_sha256 = (Get-FileHash $Keystore -Algorithm SHA256).Hash.ToLower()
}
$ReceiptPath = Join-Path $env:USERPROFILE ".luca_toolchain\ANDROID_TOOLCHAIN_RECEIPT_v013.json"
$Receipt | ConvertTo-Json -Depth 3 | Set-Content $ReceiptPath -Encoding utf8

Write-Host "[PASS] Godot 4.7 Android JDK/SDK/keystore configured"
Write-Host "[PASS] $JavaVersion"
Write-Host "[RECEIPT] $ReceiptPath"
