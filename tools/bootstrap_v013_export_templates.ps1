$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$LockPath = Join-Path $Repo "engineering\TOOLCHAIN_LOCK.json"
$Lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$Spec = $Lock.export_templates

$ToolRoot = Join-Path $env:USERPROFILE ".luca_toolchain"
$Cache = Join-Path $ToolRoot "cache"
$Archive = Join-Path $Cache $Spec.asset
$InstallDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
$TempRoot = Join-Path $ToolRoot "export_templates_4.7.2_extract"
$ReceiptPath = Join-Path $ToolRoot "EXPORT_TEMPLATE_RECEIPT_v013.json"
$Required = @(
    "windows_debug_x86_64.exe",
    "windows_release_x86_64.exe",
    "android_debug.apk",
    "android_release.apk",
    "version.txt"
)

New-Item -ItemType Directory -Force -Path $ToolRoot,$Cache | Out-Null

function Assert-Archive {
    param([string] $Path)

    if (!(Test-Path $Path)) { return $false }
    $File = Get-Item $Path
    if ($File.Length -ne [int64]$Spec.size_bytes) { return $false }
    $Actual = (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()
    return $Actual -eq [string]$Spec.sha256
}

function Test-InstalledTemplates {
    if (!(Test-Path $InstallDir) -or !(Test-Path $ReceiptPath)) { return $false }
    foreach ($Name in $Required) {
        if (!(Test-Path (Join-Path $InstallDir $Name))) { return $false }
    }
    $VersionText = (Get-Content (Join-Path $InstallDir "version.txt") -Raw).Trim()
    if ($VersionText -ne "4.7.2.stable") { return $false }
    try {
        $ExistingReceipt = Get-Content $ReceiptPath -Raw | ConvertFrom-Json
    } catch {
        return $false
    }
    return (
        [string]$ExistingReceipt.version -eq [string]$Spec.version -and
        [string]$ExistingReceipt.archive_sha256 -eq [string]$Spec.sha256
    )
}

if (!(Assert-Archive $Archive)) {
    Remove-Item $Archive,"$Archive.part" -Force -ErrorAction SilentlyContinue
    Write-Host "[DOWNLOAD] $($Spec.url)"
    & curl.exe -L --fail --retry 4 --retry-delay 3 --output "$Archive.part" $Spec.url
    if ($LASTEXITCODE -ne 0) { throw "curl failed downloading export templates" }
    Move-Item "$Archive.part" $Archive -Force
}

if (!(Assert-Archive $Archive)) {
    $ActualSize = (Get-Item $Archive -ErrorAction SilentlyContinue).Length
    $ActualHash = if (Test-Path $Archive) { (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLower() } else { "missing" }
    throw "Export template archive verification failed size=$ActualSize sha256=$ActualHash"
}

Write-Host "[PASS] export template archive size + SHA-256"

if (Test-InstalledTemplates) {
    Write-Host "[PASS] installed Godot 4.7.2 export templates (verified cache hit)"
    Write-Host "[RECEIPT] $ReceiptPath"
    exit 0
}

if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($Archive, $TempRoot)

$ExtractedTemplates = Join-Path $TempRoot "templates"
if (!(Test-Path $ExtractedTemplates)) {
    throw "Archive did not contain templates/ root"
}

foreach ($Name in $Required) {
    if (!(Test-Path (Join-Path $ExtractedTemplates $Name))) {
        throw "Required Godot export template missing: $Name"
    }
}

if (Test-Path $InstallDir) {
    $Backup = "$InstallDir.pre-v013"
    if (Test-Path $Backup) { Remove-Item $Backup -Recurse -Force }
    Move-Item $InstallDir $Backup
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item (Join-Path $ExtractedTemplates "*") $InstallDir -Recurse -Force

$VersionText = (Get-Content (Join-Path $InstallDir "version.txt") -Raw).Trim()
if ($VersionText -notmatch "^4\.7\.2") {
    throw "Installed export template version mismatch: $VersionText"
}

$Receipt = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    version = $Spec.version
    archive = $Archive
    archive_bytes = (Get-Item $Archive).Length
    archive_sha256 = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLower()
    install_dir = $InstallDir
    version_txt = $VersionText
    windows_debug = (Join-Path $InstallDir "windows_debug_x86_64.exe")
    windows_release = (Join-Path $InstallDir "windows_release_x86_64.exe")
    android_debug = (Join-Path $InstallDir "android_debug.apk")
    android_release = (Join-Path $InstallDir "android_release.apk")
}
$Receipt | ConvertTo-Json -Depth 4 | Set-Content $ReceiptPath -Encoding utf8

Remove-Item $TempRoot -Recurse -Force

Write-Host "[PASS] installed Godot 4.7.2 export templates"
Write-Host "[RECEIPT] $ReceiptPath"
