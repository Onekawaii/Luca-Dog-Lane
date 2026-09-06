# OPEN_GODOT.ps1 - Open Godot Editor for game_godot project
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$GodotBin = "$HOME\.godot_bin\Godot_v4.3-stable_win64.exe"
if (-not (Test-Path $GodotBin)) {
    $GodotBin = "$HOME\.godot_bin\Godot_v4.3-stable_win64_console.exe"
}
if (-not (Test-Path $GodotBin)) {
    $GodotBin = (Get-Command godot -ErrorAction SilentlyContinue).Source
}

if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    Write-Error "Godot 4 binary not found in $HOME\.godot_bin or PATH."
}

Write-Host "Opening Godot editor on game_godot/project.godot..." -ForegroundColor Cyan
Start-Process -FilePath $GodotBin -ArgumentList "--path", "game_godot", "-e"
