$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$LockPath = Join-Path $Repo "engineering\TOOLCHAIN_LOCK.json"
if (!(Test-Path $LockPath)) { throw "Toolchain lock missing: $LockPath" }

$Lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$ToolRoot = Join-Path $env:USERPROFILE ".luca_toolchain"
$Cache = Join-Path $ToolRoot "cache"
$GodotDir = Join-Path $ToolRoot "Godot-4.7.2"
$VoxelDir = Join-Path $ToolRoot "VoxelTools-1.7x"
New-Item -ItemType Directory -Force -Path $ToolRoot,$Cache | Out-Null

function Get-LockedArchive {
    param(
        [Parameter(Mandatory=$true)] $Spec,
        [Parameter(Mandatory=$true)] [string] $Destination
    )

    $NeedsDownload = $true
    if (Test-Path $Destination) {
        if ((Get-Item $Destination).Length -gt 0) {
            $NeedsDownload = $false
            Write-Host "[CACHE] $Destination"
        } else {
            Remove-Item $Destination -Force
        }
    }

    if ($NeedsDownload) {
        $Part = "$Destination.part"
        Remove-Item $Part -Force -ErrorAction SilentlyContinue
        Write-Host "[DOWNLOAD] $($Spec.url)"
        & curl.exe -L --fail --retry 3 --retry-delay 2 --output $Part $Spec.url
        if ($LASTEXITCODE -ne 0) { throw "curl download failed: $($Spec.url)" }
        Move-Item $Part $Destination -Force
    }

    $Actual = (Get-FileHash $Destination -Algorithm SHA256).Hash.ToLower()
    $Expected = [string]$Spec.sha256
    if ($Actual -ne $Expected) {
        throw "SHA-256 mismatch for $Destination expected=$Expected actual=$Actual"
    }

    if ((Get-Item $Destination).Length -ne [int64]$Spec.size_bytes) {
        throw "Size mismatch for $Destination"
    }

    Write-Host "[PASS] $($Spec.asset) sha256=$Actual"
}

$GodotZip = Join-Path $Cache $Lock.engine.asset
$VoxelZip = Join-Path $Cache $Lock.voxel_tools.asset

Get-LockedArchive -Spec $Lock.engine -Destination $GodotZip
Get-LockedArchive -Spec $Lock.voxel_tools -Destination $VoxelZip

if (Test-Path $GodotDir) { Remove-Item $GodotDir -Recurse -Force }
if (Test-Path $VoxelDir) { Remove-Item $VoxelDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $GodotDir,$VoxelDir | Out-Null

Expand-Archive -Path $GodotZip -DestinationPath $GodotDir -Force
Expand-Archive -Path $VoxelZip -DestinationPath $VoxelDir -Force

$Console = Get-ChildItem $GodotDir -Recurse -Filter "*console.exe" | Select-Object -First 1
$Editor = Get-ChildItem $GodotDir -Recurse -Filter "Godot_v4.7.2-stable_win64.exe" | Select-Object -First 1
$Extension = Get-ChildItem $VoxelDir -Recurse -Filter "*.gdextension" | Select-Object -First 1

if (!$Console) { throw "Godot 4.7.2 console executable missing after extraction" }
if (!$Editor) { throw "Godot 4.7.2 editor executable missing after extraction" }
if (!$Extension) { throw "Voxel Tools .gdextension descriptor missing after extraction" }

$Version = & $Console.FullName --version
if ($LASTEXITCODE -ne 0 -or $Version -notmatch "^4\.7\.2") {
    throw "Unexpected Godot version: $Version"
}

$Receipt = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    engine_version = $Version.Trim()
    engine_console = $Console.FullName
    engine_editor = $Editor.FullName
    voxel_extension_descriptor = $Extension.FullName
    engine_archive_sha256 = $Lock.engine.sha256
    voxel_archive_sha256 = $Lock.voxel_tools.sha256
}
$ReceiptPath = Join-Path $ToolRoot "BOOTSTRAP_RECEIPT_v013.json"
$Receipt | ConvertTo-Json -Depth 4 | Set-Content $ReceiptPath -Encoding utf8

Write-Host "[PASS] Godot=$($Console.FullName)"
Write-Host "[PASS] VoxelExtension=$($Extension.FullName)"
Write-Host "[RECEIPT] $ReceiptPath"
