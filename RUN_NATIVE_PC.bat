@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo HIVE-LATTICE // NATIVE CLIENT LAUNCHER
echo ============================================================

if exist "dist\windows\Hive-Lattice.exe" (
    echo Launching native client: dist\windows\Hive-Lattice.exe...
    start "" "dist\windows\Hive-Lattice.exe"
    exit /b 0
)

echo Windows executable not found in dist\windows\Hive-Lattice.exe.
echo Attempting to build native client now...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD_NATIVE_PC.ps1"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed. Cannot launch game.
    pause
    exit /b 1
)

if exist "dist\windows\Hive-Lattice.exe" (
    echo Launching native client...
    start "" "dist\windows\Hive-Lattice.exe"
) else (
    echo [ERROR] Executable still missing after build.
    pause
    exit /b 1
)
