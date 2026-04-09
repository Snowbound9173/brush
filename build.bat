@echo off
REM Simple wrapper to run the PowerShell build script
REM Double-click this file to build Brush on Windows

echo Starting Brush build process...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*

if errorlevel 1 (
    echo.
    echo Build failed! Check the output above for errors.
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
pause
