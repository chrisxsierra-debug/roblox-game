@echo off
title Push Changes to GitHub
echo ========================================================
echo Rebuilding game.rbxl and pushing all changes to GitHub...
echo ========================================================
echo.
rojo build -o game.rbxl
git add .
set /p msg="Enter a brief note about what you changed (or press Enter for default): "
if "%msg%"=="" set msg=Update game scripts and place file
git commit -m "%msg%"
git push origin main
echo.
echo ========================================================
echo Successfully pushed your changes to GitHub!
echo Your friend can now run pull-latest.bat to get your work!
echo ========================================================
pause
