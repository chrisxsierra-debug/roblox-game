@echo off
title Funnel Runners Studio Launcher
cd /d "%~dp0"

echo ========================================================
echo   FUNNEL RUNNERS: ROBLOX STUDIO + GITHUB COLLAB SYNC
echo ========================================================
echo.
echo 1. Starting Rojo Live Server...
start "Rojo Live Server" cmd /k "cd /d %~dp0 && rojo serve"

echo 2. Starting GitHub Auto-Sync Watcher...
start "GitHub Auto-Sync" cmd /k "cd /d %~dp0 && powershell -NoProfile -ExecutionPolicy Bypass -File auto-sync.ps1"

echo 3. Opening game.rbxl in Roblox Studio...
start "" "%~dp0game.rbxl"

echo.
echo ========================================================
echo All services started!
echo In Roblox Studio:
echo   - Click Plugins tab in the top ribbon
echo   - Click 'Rojo' and click 'Connect'
echo.
echo Whenever your friend pushes to GitHub, your Studio
echo will update automatically within 10 seconds!
echo ========================================================
timeout /t 5

