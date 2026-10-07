$ErrorActionPreference = "Stop"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "BUILD_SPIRAL_FIELD.ps1")
exit $LASTEXITCODE
