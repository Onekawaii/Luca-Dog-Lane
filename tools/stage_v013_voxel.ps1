$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$Lock = Get-Content (Join-Path $Repo "engineering\TOOLCHAIN_LOCK.json") -Raw | ConvertFrom-Json
$Source = Join-Path $env:USERPROFILE ".luca_toolchain\VoxelTools-1.7x\addons\zylann.voxel"
$Destination = Join-Path $Repo "addons\zylann.voxel"

if (!(Test-Path $Source)) {
    throw "Verified Voxel Tools cache missing. Run tools/bootstrap_v013_toolchain.ps1 first."
}

$Required = @(
    "voxel.gdextension",
    "bin\libvoxel.windows.editor.x86_64.dll",
    "bin\libvoxel.windows.template_release.x86_64.dll",
    "bin\libvoxel.android.editor.arm64.so",
    "bin\libvoxel.android.template_release.arm64.so",
    "bin\libvoxel.android.editor.x86_64.so",
    "bin\libvoxel.android.template_release.x86_64.so"
)

foreach ($Relative in $Required) {
    if (!(Test-Path (Join-Path $Source $Relative))) {
        throw "Required voxel binary missing from verified cache: $Relative"
    }
}

if (Test-Path $Destination) {
    Remove-Item $Destination -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
Copy-Item $Source $Destination -Recurse -Force

$Descriptor = Join-Path $Destination "voxel.gdextension"
$DescriptorText = Get-Content $Descriptor -Raw
if ($DescriptorText -notmatch 'compatibility_minimum = "4\.4\.1"') {
    throw "Unexpected Voxel Tools compatibility floor"
}
if ($DescriptorText -notmatch 'android\.release\.arm64') {
    throw "Android arm64 release binary mapping missing"
}
if ($DescriptorText -notmatch 'windows\.release\.x86_64') {
    throw "Windows release binary mapping missing"
}

Write-Host "[PASS] staged Voxel Tools $($Lock.voxel_tools.version)"
Write-Host "[PASS] Windows + Android extension mappings present"
Write-Host "[PATH] $Destination"
