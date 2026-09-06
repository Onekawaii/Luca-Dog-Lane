# VERIFY_NATIVE_PC.ps1 - Run Full Stack Native & Python Test Gates
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "HIVE-LATTICE // VERIFY NATIVE CONTRACT & GATES" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

python tools/verify_native_contract.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Verification gates failed!"
}

Write-Host "`n[ALL GATES PASS] Native contract verified." -ForegroundColor Green
